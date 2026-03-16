import { Inject, Injectable } from '@nestjs/common';
import { DeleteResult, Repository } from 'typeorm';

import { CreateSessionDto } from './dto/create-session.dto';
import { UpdateSessionDto } from './dto/update-session.dto';
import { Session } from './entities/session.entity';

@Injectable()
export class SessionService {
  constructor(
    @Inject('SESSIONS_REPOSITORY')
    private readonly sessionsRepository: Repository<Session>,
  ) {}

  findAll(): Promise<Session[]> {
    return this.sessionsRepository.createQueryBuilder('session').getMany();
  }

  findOne(playerId: string): Promise<Session | null> {
    return this.sessionsRepository.findOne({ where: { playerId } });
  }

  async create(payload: CreateSessionDto): Promise<Session> {
    const session = this.sessionsRepository.create(payload);
    return this.sessionsRepository.save(session);
  }

  async update(playerId: string, payload: UpdateSessionDto): Promise<Session | null> {
    await this.sessionsRepository.update(playerId, payload);
    return this.sessionsRepository.findOne({ where: { playerId } });
  }

  delete(playerId: string): Promise<DeleteResult> {
    return this.sessionsRepository.delete(playerId);
  }
}
