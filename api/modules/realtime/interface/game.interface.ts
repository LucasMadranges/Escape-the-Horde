export type GameStatus = 'waiting' | 'started' | 'finished';

export interface PlayPayload {
  playerId: string;
  username: string;
  socketId: string;
}

export interface JoinGamePayload {
  gameId: string;
  playerId: string;
  username: string;
  socketId: string;
}

export interface GamePlayerState {
  playerId: string;
  username: string;
  connected: boolean;
  socketId?: string;
}

export interface GameZombieState {
  zombieId: string;
  x: number;
  y: number;
  vx?: number;
  vy?: number;
  targetPlayerId?: string;
}

export interface GameState {
  gameId: string;
  status: GameStatus;
  hostPlayerId?: string;
  players: GamePlayerState[];
  zombies: GameZombieState[];
  createdAt: string;
  updatedAt: string;
}

export interface CreateGamePayload {
  status?: GameStatus;
}
