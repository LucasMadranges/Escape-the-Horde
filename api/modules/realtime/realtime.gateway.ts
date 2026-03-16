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
import { CreateGamePayload, JoinGamePayload, PlayPayload } from './interface/game.interface';

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

  private broadcastToGame(gameId: string, event: string, data: unknown) {
    const sockets = this.socketsByGame.get(gameId);
    if (!sockets) {
      return;
    }

    for (const socket of sockets) {
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
