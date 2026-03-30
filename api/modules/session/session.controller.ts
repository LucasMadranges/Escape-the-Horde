import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';

import { CreateSessionDto } from './dto/create-session.dto';
import { SessionPlayerIdParamDto } from './dto/session-player-id-param.dto';
import { UpdateSessionDto } from './dto/update-session.dto';
import { SessionService } from './session.service';

@Controller('sessions')
@ApiTags('Sessions')
export class SessionController {
  constructor(private readonly sessionService: SessionService) {}

  @Get()
  @ApiOperation({ summary: 'Récupérer toutes les sessions' })
  findAll() {
    return this.sessionService.findAll();
  }

  @Get(':playerId')
  findOne(@Param() params: SessionPlayerIdParamDto) {
    return this.sessionService.findOne(params.playerId);
  }

  @Post()
  @ApiBody({
    type: CreateSessionDto,
    examples: {
      createSession: {
        summary: 'Exemple de creation de session',
        value: {
          playerId: '123e4567-e89b-12d3-a456-426614174000',
          gameId: '123e4567-e89b-12d3-a456-426614174001',
        },
      },
    },
  })
  create(@Body() payload: CreateSessionDto) {
    return this.sessionService.create(payload);
  }

  @Put(':playerId')
  @ApiBody({
    type: UpdateSessionDto,
    examples: {
      updateSession: {
        summary: 'Exemple de mise a jour de session',
        value: {
          gameId: '123e4567-e89b-12d3-a456-426614174002',
        },
      },
    },
  })
  update(@Param() params: SessionPlayerIdParamDto, @Body() payload: UpdateSessionDto) {
    return this.sessionService.update(params.playerId, payload);
  }

  @Delete(':playerId')
  delete(@Param() params: SessionPlayerIdParamDto) {
    return this.sessionService.delete(params.playerId);
  }
}
