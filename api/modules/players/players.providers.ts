import { DataSource } from 'typeorm';

import { Player } from './entities/players.entity';

export const playersProviders = [
  {
    provide: 'PLAYERS_REPOSITORY',
    inject: ['DATA_SOURCE'],
    useFactory: (dataSource: DataSource) => dataSource.getRepository(Player),
  },
];
