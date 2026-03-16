export type GameStatus = 'waiting' | 'started' | 'finished';

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

export interface GameState {
  gameId: string;
  status: GameStatus;
  players: GamePlayerState[];
  createdAt: string;
  updatedAt: string;
}

export interface CreateGamePayload {
  status?: GameStatus;
}
