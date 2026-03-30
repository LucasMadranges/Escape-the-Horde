import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_FILTER, APP_INTERCEPTOR, APP_PIPE } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { WinstonModule } from 'nest-winston';
import { ZodSerializerInterceptor, ZodValidationPipe } from 'nestjs-zod';
import { format, transports } from 'winston';

import { HttpExceptionFilter } from '../common/http-exception.filter';
import { DatabaseModule } from '../database/database.module';
import { GameModule } from '../modules/game/game.module';
import { PlayersModule } from '../modules/players/players.module';
import { RealtimeModule } from '../modules/realtime/realtime.module';
import { SessionModule } from '../modules/session/session.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
    }),
    WinstonModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const isProd = config.get<string>('NODE_ENV') === 'production';
        return {
          transports: [
            new transports.Console({
              format: isProd
                ? format.combine(format.timestamp(), format.json())
                : format.combine(
                    format.timestamp({ format: 'HH:mm:ss' }),
                    format.colorize({ all: true }),
                    format.printf((info) => {
                      const timestamp =
                        typeof info.timestamp === 'string'
                          ? info.timestamp
                          : new Date().toISOString();
                      const context = typeof info.context === 'string' ? info.context : 'App';
                      const message =
                        typeof info.message === 'string'
                          ? info.message
                          : JSON.stringify(info.message);

                      return `[${timestamp}] ${info.level} [${context}] ${message}`;
                    }),
                  ),
            }),
            ...(isProd
              ? [
                  new transports.File({
                    filename: 'logs/error.log',
                    level: 'error',
                    format: format.combine(format.timestamp(), format.json()),
                  }),
                  new transports.File({
                    filename: 'logs/combined.log',
                    format: format.combine(format.timestamp(), format.json()),
                  }),
                ]
              : []),
          ],
        };
      },
    }),
    ThrottlerModule.forRoot({
      throttlers: [
        {
          ttl: 60000,
          limit: 10,
        },
      ],
    }),
    DatabaseModule,
    GameModule,
    PlayersModule,
    RealtimeModule,
    SessionModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_PIPE,
      useClass: ZodValidationPipe,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: ZodSerializerInterceptor,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
  ],
})
export class AppModule {}
