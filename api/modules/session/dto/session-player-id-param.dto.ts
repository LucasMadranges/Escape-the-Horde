import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const sessionPlayerIdParamSchema = z.object({
  playerId: z.string().uuid(),
});

export class SessionPlayerIdParamDto extends createZodDto(sessionPlayerIdParamSchema) {}
