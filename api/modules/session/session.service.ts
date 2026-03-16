import { BadRequestException, Inject, Injectable } from '@nestjs/common';
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

  findByGameId(gameId: string): Promise<Session[]> {
    return this.sessionsRepository.find({ where: { gameId } });
  }

  async create(payload: CreateSessionDto): Promise<Session> {
    const session = this.sessionsRepository.create(payload);
    return this.sessionsRepository.save(session);
  }

  async update(playerId: string, payload: UpdateSessionDto): Promise<Session | null> {
    await this.sessionsRepository.update(playerId, payload);
    return this.sessionsRepository.findOne({ where: { playerId } });
  }

  async assignPlayerToGame(playerId: string, gameId: string): Promise<Session> {
    const existing = await this.sessionsRepository.findOne({ where: { playerId } });

    if (existing && existing.gameId !== gameId) {
      throw new BadRequestException('Ce joueur est deja dans une autre game');
    }

    if (existing) {
      return existing;
    }

    const session = this.sessionsRepository.create({ playerId, gameId });
    return this.sessionsRepository.save(session);
  }

  delete(playerId: string): Promise<DeleteResult> {
    return this.sessionsRepository.delete(playerId);
  }
}
