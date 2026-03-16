import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { GameService } from '../game/game.service';
import { SessionService } from '../session/session.service';
import {
  CreateGamePayload,
  GamePlayerState,
  GameState,
  JoinGamePayload,
  PlayPayload,
} from './interface/game.interface';

@Injectable()
export class RealtimeService {
  private readonly presenceByPlayer = new Map<string, { connected: boolean; socketId?: string }>();
  private readonly usernameByPlayer = new Map<string, string>();
  private readonly stateCacheByGameId = new Map<string, GameState>();

  constructor(
    private readonly gameService: GameService,
    private readonly sessionService: SessionService,
  ) {}

  async createGame(payload: CreateGamePayload = {}): Promise<GameState> {
    const game = await this.gameService.create({
      status: payload.status ?? 'waiting',
    });

    const state: GameState = {
      gameId: game.id,
      status: game.status,
      players: [],
      createdAt: game.createdAt.toISOString(),
      updatedAt: game.updatedAt.toISOString(),
    };

    this.stateCacheByGameId.set(state.gameId, state);
    return state;
  }

  async play(payload: PlayPayload): Promise<GameState> {
    const state = await this.createGame({ status: 'waiting' });

    return this.joinGame({
      gameId: state.gameId,
      playerId: payload.playerId,
      username: payload.username,
      socketId: payload.socketId,
    });
  }

  async joinGame(payload: JoinGamePayload): Promise<GameState> {
    const state = await this.getGame(payload.gameId);

    if (state.status !== 'waiting') {
      throw new BadRequestException('La game est deja lancee');
    }

    await this.sessionService.assignPlayerToGame(payload.playerId, payload.gameId);
    this.presenceByPlayer.set(payload.playerId, {
      connected: true,
      socketId: payload.socketId,
    });
    this.usernameByPlayer.set(payload.playerId, payload.username);

    const existingIndex = state.players.findIndex((player) => player.playerId === payload.playerId);

    const joinedPlayer: GamePlayerState = {
      playerId: payload.playerId,
      username: payload.username,
      connected: true,
      socketId: payload.socketId,
    };

    if (existingIndex >= 0) {
      state.players[existingIndex] = joinedPlayer;
    } else {
      state.players.push(joinedPlayer);
    }

    const updated = {
      ...state,
      updatedAt: new Date().toISOString(),
    };

    this.stateCacheByGameId.set(updated.gameId, updated);
    return updated;
  }

  async getGame(gameId: string): Promise<GameState> {
    const cached = this.stateCacheByGameId.get(gameId);
    if (cached) {
      return cached;
    }

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

    const state: GameState = {
      gameId: game.id,
      status: game.status,
      players,
      createdAt: game.createdAt.toISOString(),
      updatedAt: game.updatedAt.toISOString(),
    };

    this.stateCacheByGameId.set(gameId, state);
    return state;
  }

  async launchGame(gameId: string): Promise<GameState> {
    const state = await this.getGame(gameId);

    if (state.players.length < 1) {
      throw new BadRequestException('Aucun joueur dans la game');
    }

    const updatedGame = await this.gameService.update(gameId, { status: 'started' });
    if (!updatedGame) {
      throw new NotFoundException('Game introuvable');
    }

    const updatedState: GameState = {
      ...state,
      status: 'started',
      updatedAt: updatedGame.updatedAt.toISOString(),
    };

    this.stateCacheByGameId.set(gameId, updatedState);
    return updatedState;
  }

  async finishGame(gameId: string): Promise<GameState> {
    const state = await this.getGame(gameId);
    const updatedGame = await this.gameService.update(gameId, { status: 'finished' });
    if (!updatedGame) {
      throw new NotFoundException('Game introuvable');
    }

    const updatedState: GameState = {
      ...state,
      status: 'finished',
      updatedAt: updatedGame.updatedAt.toISOString(),
    };

    this.stateCacheByGameId.set(gameId, updatedState);
    return updatedState;
  }

  async markDisconnected(gameId: string, playerId: string): Promise<GameState | null> {
    const state = this.stateCacheByGameId.get(gameId);
    if (!state) {
      return null;
    }

    this.presenceByPlayer.set(playerId, {
      connected: false,
    });

    const updatedPlayers = state.players.map((player) => {
      if (player.playerId !== playerId) {
        return player;
      }

      return {
        ...player,
        connected: false,
        socketId: undefined,
      };
    });

    const updatedState: GameState = {
      ...state,
      players: updatedPlayers,
      updatedAt: new Date().toISOString(),
    };

    this.stateCacheByGameId.set(gameId, updatedState);
    return updatedState;
  }
}
