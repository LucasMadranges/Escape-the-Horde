import { createZodDto } from 'nestjs-zod';

import { createGameSchema } from './create-game.dto';

export const updateGameSchema = createGameSchema;

export class UpdateGameDto extends createZodDto(updateGameSchema) {}
