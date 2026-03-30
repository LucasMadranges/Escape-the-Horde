import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const gameIdParamSchema = z.object({
  id: z.string().uuid(),
});

export class GameIdParamDto extends createZodDto(gameIdParamSchema) {}
