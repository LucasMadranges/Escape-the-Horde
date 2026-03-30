import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const playerIdParamSchema = z.object({
  id: z.string().uuid(),
});

export class PlayerIdParamDto extends createZodDto(playerIdParamSchema) {}
