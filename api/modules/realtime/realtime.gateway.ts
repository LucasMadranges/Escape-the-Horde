import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';

import { RealtimeService } from './realtime.service';
import { SocketPresence } from './interface/socket.interface';
import { JoinGamePayload } from './interface/game.interface';

@WebSocketGateway({
  namespace: '/game',
  cors: {
    origin: ['http://localhost:3000', 'http://localhost:5173'],
    credentials: true,
  },
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  private server!: Server;

  private readonly logger = new Logger(RealtimeGateway.name);
  private readonly socketPresence = new Map<string, SocketPresence>();

  constructor(private readonly realtimeService: RealtimeService) {}

  handleConnection(client: Socket) {
    this.logger.log(`Socket connected: ${client.id}`);
    client.emit('game:connected', { socketId: client.id });
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Socket disconnected: ${client.id}`);
    const presence = this.socketPresence.get(client.id);
    if (!presence) {
      return;
    }

    const game = this.realtimeService.markDisconnected(presence.gameId, presence.playerId);
    this.socketPresence.delete(client.id);

    if (game) {
      this.server.to(this.toRoom(presence.gameId)).emit('game:state', game);
    }
  }

  @SubscribeMessage('game:join')
  handleJoin(@MessageBody() rawBody: unknown, @ConnectedSocket() client: Socket) {
    const body = this.normalizePayload<Omit<JoinGamePayload, 'socketId'>>(rawBody);

    this.logger.log(`Received game:join from ${client.id}`);

    if (!body?.gameId || !body?.playerId || !body?.username) {
      this.logger.warn(
        `Invalid game:join payload from ${client.id}: ${this.safeStringify(rawBody)}`,
      );
      client.emit('game:error', {
        message: 'Payload invalide: gameId, playerId et username sont obligatoires',
      });
      return;
    }

    client.join(this.toRoom(body.gameId));

    const game = this.realtimeService.joinGame({
      ...body,
      socketId: client.id,
    });

    this.socketPresence.set(client.id, {
      gameId: body.gameId,
      playerId: body.playerId,
    });

    this.server.to(this.toRoom(body.gameId)).emit('game:state', game);

    return {
      event: 'game:joined',
      data: game,
    };
  }

  @SubscribeMessage('game:get')
  handleGetGame(@MessageBody() rawBody: unknown) {
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

    return {
      event: 'game:state',
      data: this.realtimeService.getGame(body.gameId),
    };
  }

  @SubscribeMessage('game:launch')
  handleLaunch(@MessageBody() rawBody: unknown) {
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

    const game = this.realtimeService.launchGame(body.gameId);
    this.server.to(this.toRoom(body.gameId)).emit('game:state', game);

    return {
      event: 'game:launched',
      data: game,
    };
  }

  private toRoom(gameId: string): string {
    return `game:${gameId}`;
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
}
