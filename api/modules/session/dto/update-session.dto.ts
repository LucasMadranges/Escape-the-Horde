import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

export const updateSessionSchema = z.object({
  gameId: z.string().uuid(),
});

export class UpdateSessionDto extends createZodDto(updateSessionSchema) {}
