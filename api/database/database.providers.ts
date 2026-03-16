import { ConfigService } from '@nestjs/config';
import { DataSource } from 'typeorm';

export const databaseProviders = [
  {
    provide: 'DATA_SOURCE',
    inject: [ConfigService],
    useFactory: async (configService: ConfigService) => {
      const isProd = configService.get<string>('NODE_ENV') === 'production';

      const dataSource = new DataSource({
        type: 'postgres',
        host: configService.getOrThrow<string>('POSTGRES_HOST'),
        port: configService.getOrThrow<number>('POSTGRES_PORT'),
        username: configService.getOrThrow<string>('POSTGRES_USER'),
        password: configService.getOrThrow<string>('POSTGRES_PASSWORD'),
        database: configService.getOrThrow<string>('POSTGRES_DB'),
        entities: [__dirname + '/../**/*.entity{.ts,.js}'],
        // En prod : jamais de synchronize automatique (risque de perte de données)
        synchronize: !isProd,
        // En dev : logs SQL complets ; en prod : uniquement les erreurs
        logging: isProd ? ['error', 'warn'] : true,
        ...(isProd && {
          ssl: {
            rejectUnauthorized: true,
            ca: configService.get<string>('POSTGRES_SSL_CA'),
          },
        }),
        migrations: [__dirname + '/../migrations/*{.ts,.js}'],
        migrationsRun: isProd, // En prod : exécuter les migrations automatiquement au démarrage
      });

      return dataSource.initialize();
    },
  },
];
