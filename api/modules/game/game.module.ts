import { Module } from '@nestjs/common';

import { DatabaseModule } from '../../database/database.module';
import { GameController } from './game.controller';
import { gamesProviders } from './game.providers';
import { GameService } from './game.service';

@Module({
  imports: [DatabaseModule],
  controllers: [GameController],
  providers: [GameService, ...gamesProviders],
})
export class GameModule {}
