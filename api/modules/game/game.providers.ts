import { DataSource } from 'typeorm';

import { Game } from './entities/game.entity';

export const gamesProviders = [
  {
    provide: 'GAMES_REPOSITORY',
    inject: ['DATA_SOURCE'],
    useFactory: (dataSource: DataSource) => dataSource.getRepository(Game),
  },
];
