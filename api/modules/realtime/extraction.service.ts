import { Injectable } from '@nestjs/common';

const COUNTDOWN_PARTIAL = 30;
const COUNTDOWN_ALL = 3;
const TICK_MS = 1000;

interface ExtractionState {
  playersInZone: Set<string>;
  countdown: number;
  interval: ReturnType<typeof setInterval> | null;
}

@Injectable()
export class ExtractionService {
  private readonly stateByGame = new Map<string, ExtractionState>();

  enter(
    gameId: string,
    playerId: string,
    totalPlayers: number,
    broadcast: (countdown: number, inZone: number, total: number) => void,
    launch: () => void,
  ): void {
    const state = this._getOrCreate(gameId);
    state.playersInZone.add(playerId);
    this._recalculate(state, totalPlayers, broadcast, launch, gameId);
  }

  exit(
    gameId: string,
    playerId: string,
    totalPlayers: number,
    broadcast: (countdown: number, inZone: number, total: number) => void,
  ): void {
    const state = this.stateByGame.get(gameId);
    if (!state) return;
    state.playersInZone.delete(playerId);

    if (state.playersInZone.size === 0) {
      this._stopTimer(state);
      this.stateByGame.delete(gameId);
      broadcast(0, 0, totalPlayers);
      return;
    }

    this._recalculate(state, totalPlayers, broadcast, () => {}, gameId);
  }

  clear(gameId: string): void {
    const state = this.stateByGame.get(gameId);
    if (state) this._stopTimer(state);
    this.stateByGame.delete(gameId);
  }

  private _getOrCreate(gameId: string): ExtractionState {
    if (!this.stateByGame.has(gameId)) {
      this.stateByGame.set(gameId, { playersInZone: new Set(), countdown: COUNTDOWN_PARTIAL, interval: null });
    }
    return this.stateByGame.get(gameId)!;
  }

  private _recalculate(
    state: ExtractionState,
    totalPlayers: number,
    broadcast: (countdown: number, inZone: number, total: number) => void,
    launch: () => void,
    gameId: string,
  ): void {
    const inZone = state.playersInZone.size;
    const allIn = inZone >= totalPlayers;

    if (state.interval === null) {
      state.countdown = allIn ? COUNTDOWN_ALL : COUNTDOWN_PARTIAL;
      broadcast(state.countdown, inZone, totalPlayers);
      state.interval = setInterval(() => {
        const current = this.stateByGame.get(gameId);
        if (!current) return;

        const currentInZone = current.playersInZone.size;
        const currentAllIn = currentInZone >= totalPlayers;

        if (currentAllIn && current.countdown > COUNTDOWN_ALL) {
          current.countdown = COUNTDOWN_ALL;
        }

        current.countdown -= 1;
        broadcast(current.countdown, currentInZone, totalPlayers);

        if (current.countdown <= 0) {
          this._stopTimer(current);
          this.stateByGame.delete(gameId);
          launch();
        }
      }, TICK_MS);
    } else if (allIn && state.countdown > COUNTDOWN_ALL) {
      state.countdown = COUNTDOWN_ALL;
      broadcast(state.countdown, inZone, totalPlayers);
    } else {
      broadcast(state.countdown, inZone, totalPlayers);
    }
  }

  private _stopTimer(state: ExtractionState): void {
    if (state.interval !== null) {
      clearInterval(state.interval);
      state.interval = null;
    }
  }
}
