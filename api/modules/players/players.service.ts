import { Inject, Injectable } from '@nestjs/common';
import { DeleteResult, Repository } from 'typeorm';

import { CreatePlayerDto } from './dto/create-player.dto';
import { UpdatePlayerDto } from './dto/update-player.dto';
import { Player } from './entities/players.entity';

@Injectable()
export class PlayersService {
  constructor(
    @Inject('PLAYERS_REPOSITORY')
    private readonly playersRepository: Repository<Player>,
  ) {}

  findAll(): Promise<Player[]> {
    return this.playersRepository.createQueryBuilder('player').getMany();
  }

  findOne(id: string): Promise<Player | null> {
    return this.playersRepository
      .createQueryBuilder('player')
      .where('player.id = :id', { id })
      .getOne();
  }

  async create(payload: CreatePlayerDto): Promise<Player> {
    const player = this.playersRepository.create(payload);
    return this.playersRepository.save(player);
  }

  async update(id: string, payload: UpdatePlayerDto): Promise<Player | null> {
    await this.playersRepository.update(id, payload);
    return this.playersRepository.findOne({ where: { id } });
  }

  async updateMultiple(players: { id: string; data: UpdatePlayerDto }[]): Promise<Player[]> {
    const updatedPlayers: Player[] = [];
    for (const { id, data } of players) {
      await this.playersRepository.update(id, data);
      const updatedPlayer = await this.playersRepository.findOne({ where: { id } });
      if (updatedPlayer) {
        updatedPlayers.push(updatedPlayer);
      }
    }
    return updatedPlayers;
  }

  async updateGoldandExperience(
    id: string,
    gold: number,
    experience: number,
  ): Promise<Player | null> {
    const player = await this.playersRepository.findOne({ where: { id } });
    if (!player) {
      return null;
    }

    const newGold = player.gold + gold;
    const newExperience = player.experience + experience;
    return this.playersRepository
      .createQueryBuilder('player')
      .update(Player)
      .set({ gold: newGold, experience: newExperience })
      .where('id = :id', { id })
      .returning('*')
      .execute()
      .then((result) => result.raw[0] as Player);
  }

  delete(id: string): Promise<DeleteResult> {
    return this.playersRepository
      .createQueryBuilder('player')
      .delete()
      .where('id = :id', { id })
      .execute();
  }
}
