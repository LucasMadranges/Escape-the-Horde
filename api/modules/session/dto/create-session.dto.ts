import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const createSessionSchema = z.object({
  playerId: z.string().uuid(),
  gameId: z.string().uuid(),
});

export class CreateSessionDto extends createZodDto(createSessionSchema) {}
