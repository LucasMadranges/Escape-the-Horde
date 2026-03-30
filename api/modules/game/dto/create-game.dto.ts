import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const gameStatusSchema = z.enum(['waiting', 'started', 'finished']);

export const createGameSchema = z.object({
  status: gameStatusSchema.optional(),
});

export class CreateGameDto extends createZodDto(createGameSchema) {}
