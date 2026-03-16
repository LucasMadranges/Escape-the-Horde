import { DataSource } from 'typeorm';

import { Session } from './entities/session.entity';

export const sessionsProviders = [
  {
    provide: 'SESSIONS_REPOSITORY',
    inject: ['DATA_SOURCE'],
    useFactory: (dataSource: DataSource) => dataSource.getRepository(Session),
  },
];
