import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsResponse,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Server, WebSocket } from 'ws';

import { RealtimeService } from './realtime.service';
import { SocketPresence } from './interface/socket.interface';
import {
  CreateGamePayload,
  GameZombieState,
  JoinGamePayload,
  PlayPayload,
} from './interface/game.interface';

@WebSocketGateway({
  path: '/ws/game',
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  private server!: Server;

  private readonly logger = new Logger(RealtimeGateway.name);
  private readonly clientIdBySocket = new Map<WebSocket, string>();
  private readonly socketPresence = new Map<string, SocketPresence>();
  private readonly socketsByGame = new Map<string, Set<WebSocket>>();

  constructor(private readonly realtimeService: RealtimeService) {}

  handleConnection(client: WebSocket) {
    const socketId = randomUUID();
    this.clientIdBySocket.set(client, socketId);

    this.logger.log(`Socket connected: ${socketId}`);
    this.send(client, 'game:connected', { socketId });
  }

  handleDisconnect(client: WebSocket) {
    const socketId = this.clientIdBySocket.get(client) ?? 'unknown';

    this.logger.log(`Socket disconnected: ${socketId}`);
    const presence = this.socketPresence.get(socketId);
    if (!presence) {
      this.clientIdBySocket.delete(client);
      return;
    }

    void this.realtimeService
      .markDisconnected(presence.gameId, presence.playerId)
      .then((game) => {
        this.socketPresence.delete(socketId);
        this.clientIdBySocket.delete(client);
        this.removeSocketFromGame(presence.gameId, client);

        if (game) {
          this.broadcastToGame(presence.gameId, 'game:state', game);
        }
      })
      .catch((error: unknown) => {
        this.logger.error(`Failed to handle disconnect: ${this.toErrorMessage(error)}`);
      });
  }

  @SubscribeMessage('game:play')
  async handlePlay(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<Omit<PlayPayload, 'socketId'>>(rawBody);
    const socketId = this.requireSocketId(client);

    this.logger.log(`Received game:play from ${socketId}`);

    if (!body?.playerId || !body?.username) {
      return this.errorResponse(rawBody, 'playerId et username sont obligatoires');
    }

    try {
      const game = await this.realtimeService.play({
        playerId: body.playerId,
        username: body.username,
        socketId,
      });

      this.socketPresence.set(socketId, {
        gameId: game.gameId,
        playerId: body.playerId,
      });
      this.addSocketToGame(game.gameId, client);
      this.broadcastToGame(game.gameId, 'game:state', game);

      return {
        event: 'game:played',
        data: game,
      };
    } catch (error: unknown) {
      return {
        event: 'game:error',
        data: {
          message: this.toErrorMessage(error),
        },
      };
    }
  }

  @SubscribeMessage('game:create')
  async handleCreateGame(@MessageBody() rawBody: unknown): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<CreateGamePayload>(rawBody);

    this.logger.log('Received game:create');

    try {
      const game = await this.realtimeService.createGame(body ?? {});
      return {
        event: 'game:created',
        data: game,
      };
    } catch (error: unknown) {
      return {
        event: 'game:error',
        data: {
          message: this.toErrorMessage(error),
        },
      };
    }
  }

  @SubscribeMessage('game:join')
  async handleJoin(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<Omit<JoinGamePayload, 'socketId'>>(rawBody);
    const socketId = this.requireSocketId(client);

    this.logger.log(`Received game:join from ${socketId}`);

    if (!body?.gameId || !body?.playerId || !body?.username) {
      return this.errorResponse(rawBody, 'gameId, playerId et username sont obligatoires');
    }

    try {
      const game = await this.realtimeService.joinGame({
        ...body,
        socketId,
      });

      this.socketPresence.set(socketId, {
        gameId: body.gameId,
        playerId: body.playerId,
      });
      this.addSocketToGame(body.gameId, client);

      this.broadcastToGame(body.gameId, 'game:state', game);

      return {
        event: 'game:joined',
        data: game,
      };
    } catch (error: unknown) {
      return {
        event: 'game:error',
        data: {
          message: this.toErrorMessage(error),
        },
      };
    }
  }

  @SubscribeMessage('game:get')
  async handleGetGame(@MessageBody() rawBody: unknown): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ gameId: string }>(rawBody);

    this.logger.log(`Received game:get for gameId=${body?.gameId ?? 'undefined'}`);

    if (!body?.gameId) {
      return {
        event: 'game:error',
        data: {
          message: `Payload invalide: gameId est obligatoire. Recu=${this.safeStringify(rawBody)}`,
        },
      };
    }

    try {
      return {
        event: 'game:state',
        data: await this.realtimeService.getGame(body.gameId),
      };
    } catch (error: unknown) {
      return {
        event: 'game:error',
        data: {
          message: this.toErrorMessage(error),
        },
      };
    }
  }

  @SubscribeMessage('game:launch')
  async handleLaunch(@MessageBody() rawBody: unknown): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ gameId: string }>(rawBody);

    this.logger.log(`Received game:launch for gameId=${body?.gameId ?? 'undefined'}`);

    if (!body?.gameId) {
      return {
        event: 'game:error',
        data: {
          message: `Payload invalide: gameId est obligatoire. Recu=${this.safeStringify(rawBody)}`,
        },
      };
    }

    try {
      const game = await this.realtimeService.launchGame(body.gameId);
      this.broadcastToGame(body.gameId, 'game:state', game);

      return {
        event: 'game:launched',
        data: game,
      };
    } catch (error: unknown) {
      return {
        event: 'game:error',
        data: {
          message: this.toErrorMessage(error),
        },
      };
    }
  }

  @SubscribeMessage('game:finish')
  async handleFinish(@MessageBody() rawBody: unknown): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ gameId: string }>(rawBody);

    this.logger.log(`Received game:finish for gameId=${body?.gameId ?? 'undefined'}`);

    if (!body?.gameId) {
      return {
        event: 'game:error',
        data: {
          message: `Payload invalide: gameId est obligatoire. Recu=${this.safeStringify(rawBody)}`,
        },
      };
    }

    try {
      const game = await this.realtimeService.finishGame(body.gameId);
      this.broadcastToGame(body.gameId, 'game:state', game);

      return {
        event: 'game:finished',
        data: game,
      };
    } catch (error: unknown) {
      return {
        event: 'game:error',
        data: {
          message: this.toErrorMessage(error),
        },
      };
    }
  }

  @SubscribeMessage('game:sync_player')
  async handleSyncPlayer(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ x: number; y: number; vx?: number; vy?: number }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    if (typeof body?.x !== 'number' || typeof body?.y !== 'number') {
      return this.errorResponse(rawBody, 'x et y sont obligatoires');
    }

    const payload = {
      playerId: presence.playerId,
      username: this.realtimeService.getUsername(presence.playerId),
      x: body.x,
      y: body.y,
      vx: typeof body.vx === 'number' ? body.vx : 0.0,
      vy: typeof body.vy === 'number' ? body.vy : 0.0,
    };

    this.broadcastToGame(presence.gameId, 'game:player_sync', payload, client);

    return {
      event: 'game:sync_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:zombie_spawn')
  async handleZombieSpawn(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ x: number; y: number; zombieId: string }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    if (typeof body?.x !== 'number' || typeof body?.y !== 'number' || !body?.zombieId) {
      return this.errorResponse(rawBody, 'x, y et zombieId sont obligatoires');
    }

    const isHost = await this.realtimeService.isHost(presence.gameId, presence.playerId);
    if (!isHost) {
      return {
        event: 'game:error',
        data: { message: 'Seul le host peut spawner des zombies' },
      };
    }

    const payload = {
      x: body.x,
      y: body.y,
      zombieId: body.zombieId,
    };

    const game = await this.realtimeService.registerZombieSpawn(presence.gameId, payload);

    this.broadcastToGame(presence.gameId, 'game:zombie_spawn', payload, client);
    this.broadcastToGame(presence.gameId, 'game:state', game);

    return {
      event: 'game:zombie_spawn_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:zombie_kill')
  async handleZombieKill(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ zombieId: string }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    if (!body?.zombieId) {
      return this.errorResponse(rawBody, 'zombieId est obligatoire');
    }

    const game = await this.realtimeService.registerZombieKill(presence.gameId, body.zombieId);

    this.broadcastToGame(presence.gameId, 'game:zombie_kill', { zombieId: body.zombieId }, client);
    this.broadcastToGame(presence.gameId, 'game:state', game);

    return {
      event: 'game:zombie_kill_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:zombie_sync')
  async handleZombieSync(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ zombies: GameZombieState[] }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    const isHost = await this.realtimeService.isHost(presence.gameId, presence.playerId);
    if (!isHost) {
      return {
        event: 'game:error',
        data: { message: 'Seul le host peut synchroniser les zombies' },
      };
    }

    const zombies = Array.isArray(body?.zombies)
      ? body.zombies
          .filter(
            (zombie) =>
              !!zombie &&
              typeof zombie.zombieId === 'string' &&
              zombie.zombieId.length > 0 &&
              typeof zombie.x === 'number' &&
              typeof zombie.y === 'number',
          )
          .map((zombie) => ({
            zombieId: zombie.zombieId,
            x: zombie.x,
            y: zombie.y,
            vx: typeof zombie.vx === 'number' ? zombie.vx : 0,
            vy: typeof zombie.vy === 'number' ? zombie.vy : 0,
            targetPlayerId:
              typeof zombie.targetPlayerId === 'string' ? zombie.targetPlayerId : undefined,
          }))
      : [];

    await this.realtimeService.syncZombieStates(presence.gameId, zombies);
    this.broadcastToGame(presence.gameId, 'game:zombie_sync', { zombies }, client);

    return {
      event: 'game:zombie_sync_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:player_damage')
  async handlePlayerDamage(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ playerId: string; amount: number }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    const isHost = await this.realtimeService.isHost(presence.gameId, presence.playerId);
    if (!isHost) {
      return {
        event: 'game:error',
        data: { message: 'Seul le host peut appliquer des degats' },
      };
    }

    if (!body?.playerId || typeof body?.amount !== 'number' || body.amount <= 0) {
      return this.errorResponse(rawBody, 'playerId et amount sont obligatoires');
    }

    this.broadcastToGame(presence.gameId, 'game:player_damage', {
      playerId: body.playerId,
      amount: body.amount,
    });

    return {
      event: 'game:player_damage_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:player_down')
  async handlePlayerDown(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ bleedoutDurationMs?: number }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    const downedAtMs = Date.now();
    const bleedoutDurationMs =
      typeof body?.bleedoutDurationMs === 'number'
        ? Math.max(1000, Math.floor(body.bleedoutDurationMs))
        : 30000;

    this.broadcastToGame(presence.gameId, 'game:player_downed', {
      playerId: presence.playerId,
      downedAtMs,
      bleedoutDurationMs,
    });

    return {
      event: 'game:player_downed_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:player_revive_start')
  async handlePlayerReviveStart(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ targetPlayerId: string; durationMs?: number }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    if (!body?.targetPlayerId) {
      return this.errorResponse(rawBody, 'targetPlayerId est obligatoire');
    }

    const startedAtMs = Date.now();
    const durationMs =
      typeof body.durationMs === 'number' ? Math.max(500, Math.floor(body.durationMs)) : 3000;

    this.broadcastToGame(presence.gameId, 'game:player_revive_started', {
      targetPlayerId: body.targetPlayerId,
      reviverPlayerId: presence.playerId,
      startedAtMs,
      durationMs,
    });

    return {
      event: 'game:player_revive_started_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:player_revive_cancel')
  async handlePlayerReviveCancel(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ targetPlayerId: string }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    if (!body?.targetPlayerId) {
      return this.errorResponse(rawBody, 'targetPlayerId est obligatoire');
    }

    this.broadcastToGame(presence.gameId, 'game:player_revive_canceled', {
      targetPlayerId: body.targetPlayerId,
      reviverPlayerId: presence.playerId,
      canceledAtMs: Date.now(),
    });

    return {
      event: 'game:player_revive_canceled_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:player_revived')
  async handlePlayerRevived(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const body = this.normalizePayload<{ targetPlayerId: string }>(rawBody);
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    if (!body?.targetPlayerId) {
      return this.errorResponse(rawBody, 'targetPlayerId est obligatoire');
    }

    this.broadcastToGame(presence.gameId, 'game:player_revived', {
      playerId: body.targetPlayerId,
      revivedByPlayerId: presence.playerId,
      revivedAtMs: Date.now(),
    });

    return {
      event: 'game:player_revived_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:player_dead')
  async handlePlayerDead(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): Promise<WsResponse<unknown>> {
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);

    if (!presence) {
      return {
        event: 'game:error',
        data: { message: 'Socket non associee a une game' },
      };
    }

    this.broadcastToGame(presence.gameId, 'game:player_dead', {
      playerId: presence.playerId,
      deadAtMs: Date.now(),
    });

    return {
      event: 'game:player_dead_ack',
      data: { ok: true },
    };
  }

  @SubscribeMessage('game:extraction_sync')
  handleExtractionSync(
    @MessageBody() rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): void {
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);
    if (!presence) return;
    const body = this.normalizePayload<{ countdown: number; inZone: number; total: number }>(rawBody);
    this.broadcastToGame(presence.gameId, 'game:extraction_sync', {
      countdown: body?.countdown ?? 0,
      inZone: body?.inZone ?? 0,
      total: body?.total ?? 1,
    }, client);
  }

  @SubscribeMessage('game:extraction_launch')
  handleExtractionLaunch(
    @MessageBody() _rawBody: unknown,
    @ConnectedSocket() client: WebSocket,
  ): void {
    const socketId = this.requireSocketId(client);
    const presence = this.socketPresence.get(socketId);
    if (!presence) return;
    this.broadcastToGame(presence.gameId, 'game:extraction_launch', {}, client);
  }

  private addSocketToGame(gameId: string, socket: WebSocket) {
    const set = this.socketsByGame.get(gameId) ?? new Set<WebSocket>();
    set.add(socket);
    this.socketsByGame.set(gameId, set);
  }

  private removeSocketFromGame(gameId: string, socket: WebSocket) {
    const set = this.socketsByGame.get(gameId);
    if (!set) {
      return;
    }

    set.delete(socket);
    if (set.size === 0) {
      this.socketsByGame.delete(gameId);
    }
  }

  private broadcastToGame(gameId: string, event: string, data: unknown, except?: WebSocket) {
    const sockets = this.socketsByGame.get(gameId);
    if (!sockets) {
      return;
    }

    for (const socket of sockets) {
      if (except && socket === except) {
        continue;
      }

      this.send(socket, event, data);
    }
  }

  private send(socket: WebSocket, event: string, data: unknown) {
    if (socket.readyState !== WebSocket.OPEN) {
      return;
    }

    socket.send(JSON.stringify({ event, data }));
  }

  private requireSocketId(client: WebSocket): string {
    const socketId = this.clientIdBySocket.get(client);
    if (socketId) {
      return socketId;
    }

    const fallback = randomUUID();
    this.clientIdBySocket.set(client, fallback);
    return fallback;
  }

  private normalizePayload<T>(payload: unknown): T {
    if (Array.isArray(payload) && payload.length > 0) {
      return this.normalizePayload<T>(payload[0]);
    }

    if (typeof payload === 'string') {
      try {
        const parsed = JSON.parse(payload) as unknown;
        return this.normalizePayload<T>(parsed);
      } catch {
        return payload as T;
      }
    }

    if (payload && typeof payload === 'object' && 'data' in payload) {
      const wrapped = (payload as { data: unknown }).data;
      return this.normalizePayload<T>(wrapped);
    }

    return payload as T;
  }

  private safeStringify(value: unknown): string {
    try {
      return JSON.stringify(value);
    } catch {
      return '[unserializable]';
    }
  }

  private toErrorMessage(error: unknown): string {
    if (error instanceof Error) {
      return error.message;
    }

    return 'Erreur inconnue';
  }

  private errorResponse(rawBody: unknown, message: string): WsResponse<unknown> {
    return {
      event: 'game:error',
      data: {
        message: `Payload invalide: ${message}. Recu=${this.safeStringify(rawBody)}`,
      },
    };
  }
}
