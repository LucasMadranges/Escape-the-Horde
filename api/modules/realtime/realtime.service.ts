import { Injectable } from '@nestjs/common';
import { GamePlayerState, GameRoom, GameState, JoinGamePayload } from './interface/game.interface';

@Injectable()
export class RealtimeService {
  private readonly rooms = new Map<string, GameRoom>();

  joinGame(payload: JoinGamePayload): GameState {
    const room = this.getOrCreateRoom(payload.gameId);

    room.players.set(payload.playerId, {
      playerId: payload.playerId,
      username: payload.username,
      connected: true,
      socketId: payload.socketId,
    });

    return this.toGameState(room);
  }

  getGame(gameId: string): GameState {
    const room = this.getOrCreateRoom(gameId);
    return this.toGameState(room);
  }

  launchGame(gameId: string): GameState {
    const room = this.getOrCreateRoom(gameId);
    room.status = 'started';
    return this.toGameState(room);
  }

  markDisconnected(gameId: string, playerId: string): GameState | null {
    const room = this.rooms.get(gameId);
    if (!room) {
      return null;
    }

    const player = room.players.get(playerId);
    if (!player) {
      return this.toGameState(room);
    }

    player.connected = false;
    room.players.set(playerId, player);

    return this.toGameState(room);
  }

  private getOrCreateRoom(gameId: string): GameRoom {
    const existing = this.rooms.get(gameId);
    if (existing) {
      return existing;
    }

    const room: GameRoom = {
      gameId,
      status: 'waiting',
      players: new Map<string, GamePlayerState>(),
      createdAt: new Date(),
    };

    this.rooms.set(gameId, room);
    return room;
  }

  private toGameState(room: GameRoom): GameState {
    return {
      gameId: room.gameId,
      status: room.status,
      players: Array.from(room.players.values()),
      createdAt: room.createdAt.toISOString(),
    };
  }
}
