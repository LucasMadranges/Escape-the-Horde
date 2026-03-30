import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CreatePlayerDto } from './dto/create-player.dto';
import { PlayerIdParamDto } from './dto/player-id-param.dto';
import { UpdatePlayerDto } from './dto/update-player.dto';
import { PlayersService } from './players.service';

@Controller('players')
@ApiTags('Players')
export class PlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Get()
  @ApiOperation({ summary: 'Récupérer tous les joueurs' })
  findAll() {
    return this.playersService.findAll();
  }

  @Get(':id')
  findOne(@Param() params: PlayerIdParamDto) {
    return this.playersService.findOne(params.id);
  }

  @Post()
  @ApiBody({
    type: CreatePlayerDto,
    examples: {
      createPlayer: {
        summary: 'Exemple de creation de joueur',
        value: {
          username: 'DoeJohn',
          gold: 100,
          experience: 200,
        },
      },
    },
  })
  create(@Body() payload: CreatePlayerDto) {
    return this.playersService.create(payload);
  }

  @Put(':id')
  @ApiBody({
    type: UpdatePlayerDto,
    examples: {
      updatePlayer: {
        summary: 'Exemple de mise à jour de joueur',
        value: {
          username: 'DoeJohn',
          gold: 150,
          experience: 250,
        },
      },
    },
  })
  update(@Param() params: PlayerIdParamDto, @Body() payload: UpdatePlayerDto) {
    return this.playersService.update(params.id, payload);
  }

  @Put('multiple')
  @ApiBody({
    type: [UpdatePlayerDto],
    examples: {
      updateMultiplePlayers: {
        summary: 'Exemple de mise à jour de plusieurs joueurs',
        value: [
          {
            id: 'uuid-player-1',
            data: {
              username: 'DoeJohn',
              gold: 150,
              experience: 250,
            },
          },
          {
            id: 'uuid-player-2',
            data: {
              username: 'SmithJane',
              gold: 200,
              experience: 300,
            },
          },
        ],
      },
    },
  })
  updateMultiple(@Body() players: { id: string; data: UpdatePlayerDto }[]) {
    return this.playersService.updateMultiple(players);
  }

  @Put(':id/gold-experience')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        gold: { type: 'integer', example: 150 },
        experience: { type: 'integer', example: 250 },
      },
    },
  })
  updateGoldAndExperience(
    @Param() params: PlayerIdParamDto,
    @Body() body: { gold: number; experience: number },
  ) {
    return this.playersService.updateGoldandExperience(params.id, body.gold, body.experience);
  }

  @Delete(':id')
  delete(@Param() params: PlayerIdParamDto) {
    return this.playersService.delete(params.id);
  }
}
