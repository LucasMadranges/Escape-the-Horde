import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { PlayersController } from './players.controller';
import { playersProviders } from './players.providers';
import { PlayersService } from './players.service';

@Module({
  imports: [DatabaseModule],
  controllers: [PlayersController],
  providers: [PlayersService, ...playersProviders],
})
export class PlayersModule {}
