import { Module } from '@nestjs/common';

import { GameModule } from '../game/game.module';
import { SessionModule } from '../session/session.module';

import { RealtimeGateway } from './realtime.gateway';
import { RealtimeService } from './realtime.service';

@Module({
  imports: [GameModule, SessionModule],
  providers: [RealtimeGateway, RealtimeService],
})
export class RealtimeModule {}
