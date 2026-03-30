import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';

import { GameService } from '../game/game.service';
import { SessionService } from '../session/session.service';
import {
  CreateGamePayload,
  GamePlayerState,
  GameState,
  GameZombieState,
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
      hostPlayerId: undefined,
      players: [],
      zombies: [],
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
      hostPlayerId: state.hostPlayerId ?? state.players[0]?.playerId ?? payload.playerId,
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
    const orderedSessions = [...sessions].sort(
      (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
    );
    const players: GamePlayerState[] = orderedSessions.map((session) => {
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
      hostPlayerId: players[0]?.playerId,
      players,
      zombies: [],
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
    const game = await this.gameService.findOne(gameId);
    if (!game) {
      return null;
    }

    this.presenceByPlayer.delete(playerId);
    this.usernameByPlayer.delete(playerId);
    await this.sessionService.delete(playerId);

    const remainingSessions = await this.sessionService.findByGameId(gameId);
    if (remainingSessions.length == 0) {
      await this.gameService.delete(gameId);
      this.stateCacheByGameId.delete(gameId);
      return null;
    }

    const orderedRemainingSessions = [...remainingSessions].sort(
      (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
    );
    const updatedPlayers: GamePlayerState[] = orderedRemainingSessions.map((session) => {
      const presence = this.presenceByPlayer.get(session.playerId);
      return {
        playerId: session.playerId,
        username:
          this.usernameByPlayer.get(session.playerId) ?? `Player-${session.playerId.slice(0, 8)}`,
        connected: presence?.connected ?? false,
        socketId: presence?.socketId,
      };
    });

    const cached = this.stateCacheByGameId.get(gameId);
    const nextHostPlayerId =
      cached?.hostPlayerId &&
      updatedPlayers.some((player) => player.playerId === cached.hostPlayerId)
        ? cached.hostPlayerId
        : updatedPlayers[0]?.playerId;
    const updatedState: GameState = {
      gameId,
      status: game.status,
      hostPlayerId: nextHostPlayerId,
      players: updatedPlayers,
      zombies: cached?.zombies ?? [],
      createdAt: cached?.createdAt ?? game.createdAt.toISOString(),
      updatedAt: new Date().toISOString(),
    };

    this.stateCacheByGameId.set(gameId, updatedState);
    return updatedState;
  }

  async isHost(gameId: string, playerId: string): Promise<boolean> {
    const state = await this.getGame(gameId);
    return state.hostPlayerId === playerId;
  }

  async registerZombieSpawn(gameId: string, zombie: GameZombieState): Promise<GameState> {
    const state = await this.getGame(gameId);
    if (state.zombies.some((existingZombie) => existingZombie.zombieId === zombie.zombieId)) {
      return state;
    }

    const zombieState: GameZombieState = {
      zombieId: zombie.zombieId,
      x: zombie.x,
      y: zombie.y,
      vx: zombie.vx ?? 0,
      vy: zombie.vy ?? 0,
      targetPlayerId: zombie.targetPlayerId,
    };

    const updatedState: GameState = {
      ...state,
      zombies: [...state.zombies, zombieState],
      updatedAt: new Date().toISOString(),
    };
    this.stateCacheByGameId.set(gameId, updatedState);
    return updatedState;
  }

  async registerZombieKill(gameId: string, zombieId: string): Promise<GameState> {
    const state = await this.getGame(gameId);
    const updatedZombies = state.zombies.filter((zombie) => zombie.zombieId !== zombieId);
    if (updatedZombies.length === state.zombies.length) {
      return state;
    }

    const updatedState: GameState = {
      ...state,
      zombies: updatedZombies,
      updatedAt: new Date().toISOString(),
    };
    this.stateCacheByGameId.set(gameId, updatedState);
    return updatedState;
  }

  async syncZombieStates(gameId: string, zombies: GameZombieState[]): Promise<GameState> {
    const state = await this.getGame(gameId);
    const normalizedZombies = zombies.map((zombie) => ({
      zombieId: zombie.zombieId,
      x: zombie.x,
      y: zombie.y,
      vx: zombie.vx ?? 0,
      vy: zombie.vy ?? 0,
      targetPlayerId: zombie.targetPlayerId,
    }));

    const updatedState: GameState = {
      ...state,
      zombies: normalizedZombies,
      updatedAt: new Date().toISOString(),
    };
    this.stateCacheByGameId.set(gameId, updatedState);
    return updatedState;
  }
}
