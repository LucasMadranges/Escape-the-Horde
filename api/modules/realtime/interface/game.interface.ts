export type GameStatus = 'waiting' | 'started';

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
  socketId: string;
}

export interface GameState {
  gameId: string;
  status: GameStatus;
  players: GamePlayerState[];
  createdAt: string;
}

export interface GameRoom {
  gameId: string;
  status: GameStatus;
  players: Map<string, GamePlayerState>;
  createdAt: Date;
}
