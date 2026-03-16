import { Injectable, NotFoundException } from '@nestjs/common';

import { GameService } from '../game/game.service';
import { SessionService } from '../session/session.service';
import {
  CreateGamePayload,
  GamePlayerState,
  GameState,
  JoinGamePayload,
} from './interface/game.interface';

@Injectable()
export class RealtimeService {
  private readonly presenceByPlayer = new Map<string, { connected: boolean; socketId?: string }>();
  private readonly usernameByPlayer = new Map<string, string>();

  constructor(
    private readonly gameService: GameService,
    private readonly sessionService: SessionService,
  ) {}

  async createGame(payload: CreateGamePayload = {}): Promise<GameState> {
    const game = await this.gameService.create({
      status: payload.status ?? 'waiting',
    });

    return {
      gameId: game.id,
      status: game.status,
      players: [],
      createdAt: game.createdAt.toISOString(),
      updatedAt: game.updatedAt.toISOString(),
    };
  }

  async joinGame(payload: JoinGamePayload): Promise<GameState> {
    const game = await this.gameService.findOne(payload.gameId);
    if (!game) {
      throw new NotFoundException('Game introuvable');
    }

    await this.sessionService.assignPlayerToGame(payload.playerId, payload.gameId);
    this.presenceByPlayer.set(payload.playerId, {
      connected: true,
      socketId: payload.socketId,
    });
    this.usernameByPlayer.set(payload.playerId, payload.username);

    return this.getGame(payload.gameId);
  }

  async getGame(gameId: string): Promise<GameState> {
    const game = await this.gameService.findOne(gameId);
    if (!game) {
      throw new NotFoundException('Game introuvable');
    }

    const sessions = await this.sessionService.findByGameId(gameId);
    const players: GamePlayerState[] = sessions.map((session) => {
      const presence = this.presenceByPlayer.get(session.playerId);
      return {
        playerId: session.playerId,
        username:
          this.usernameByPlayer.get(session.playerId) ?? `Player-${session.playerId.slice(0, 8)}`,
        connected: presence?.connected ?? false,
        socketId: presence?.socketId,
      };
    });

    return {
      gameId: game.id,
      status: game.status,
      players,
      createdAt: game.createdAt.toISOString(),
      updatedAt: game.updatedAt.toISOString(),
    };
  }

  async launchGame(gameId: string): Promise<GameState> {
    await this.gameService.update(gameId, { status: 'started' });
    return this.getGame(gameId);
  }

  async finishGame(gameId: string): Promise<GameState> {
    await this.gameService.update(gameId, { status: 'finished' });
    return this.getGame(gameId);
  }

  async markDisconnected(gameId: string, playerId: string): Promise<GameState | null> {
    const game = await this.gameService.findOne(gameId);
    if (!game) {
      return null;
    }

    this.presenceByPlayer.set(playerId, {
      connected: false,
    });

    return this.getGame(gameId);
  }
}
