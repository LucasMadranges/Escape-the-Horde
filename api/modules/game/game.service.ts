import { Inject, Injectable } from '@nestjs/common';
import { DeleteResult, Repository } from 'typeorm';

import { CreateGameDto } from './dto/create-game.dto';
import { UpdateGameDto } from './dto/update-game.dto';
import { Game } from './entities/game.entity';

@Injectable()
export class GameService {
  constructor(
    @Inject('GAMES_REPOSITORY')
    private readonly gamesRepository: Repository<Game>,
  ) {}

  findAll(): Promise<Game[]> {
    return this.gamesRepository.createQueryBuilder('game').getMany();
  }

  findOne(id: string): Promise<Game | null> {
    return this.gamesRepository.findOne({ where: { id } });
  }

  async create(payload: CreateGameDto): Promise<Game> {
    const game = this.gamesRepository.create(payload);
    return this.gamesRepository.save(game);
  }

  async update(id: string, payload: UpdateGameDto): Promise<Game | null> {
    await this.gamesRepository.update(id, payload);
    return this.gamesRepository.findOne({ where: { id } });
  }

  delete(id: string): Promise<DeleteResult> {
    return this.gamesRepository.delete(id);
  }
}
