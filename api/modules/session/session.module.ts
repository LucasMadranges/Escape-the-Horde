import { Module } from '@nestjs/common';

import { DatabaseModule } from '../../database/database.module';
import { SessionController } from './session.controller';
import { sessionsProviders } from './session.providers';
import { SessionService } from './session.service';

@Module({
  imports: [DatabaseModule],
  controllers: [SessionController],
  providers: [SessionService, ...sessionsProviders],
})
export class SessionModule {}
