import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CreateGameDto } from './dto/create-game.dto';
import { GameIdParamDto } from './dto/game-id-param.dto';
import { UpdateGameDto } from './dto/update-game.dto';
import { GameService } from './game.service';

@Controller('games')
@ApiTags('Games')
export class GameController {
  constructor(private readonly gameService: GameService) {}

  @Get()
  @ApiOperation({ summary: 'Récupérer toutes les games' })
  findAll() {
    return this.gameService.findAll();
  }

  @Get(':id')
  findOne(@Param() params: GameIdParamDto) {
    return this.gameService.findOne(params.id);
  }

  @Post()
  @ApiBody({
    type: CreateGameDto,
    examples: {
      createGame: {
        summary: 'Exemple de creation de game',
        value: {
          status: 'waiting',
        },
      },
    },
  })
  create(@Body() payload: CreateGameDto) {
    return this.gameService.create(payload);
  }

  @Put(':id')
  @ApiBody({
    type: UpdateGameDto,
    examples: {
      updateGame: {
        summary: 'Exemple de mise a jour de game',
        value: {
          status: 'started',
        },
      },
    },
  })
  update(@Param() params: GameIdParamDto, @Body() payload: UpdateGameDto) {
    return this.gameService.update(params.id, payload);
  }

  @Delete(':id')
  delete(@Param() params: GameIdParamDto) {
    return this.gameService.delete(params.id);
  }
}
