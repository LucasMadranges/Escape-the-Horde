import { createZodDto } from 'nestjs-zod';

import { createPlayerSchema } from './create-player.dto';

export const updatePlayerSchema = createPlayerSchema.partial();

export class UpdatePlayerDto extends createZodDto(updatePlayerSchema) {}
