import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const createPlayerSchema = z.object({
  username: z.string().min(3).max(25),
  gold: z.number().int().min(0).optional(),
  experience: z.number().int().min(0).optional(),
});

export class CreatePlayerDto extends createZodDto(createPlayerSchema) {}
