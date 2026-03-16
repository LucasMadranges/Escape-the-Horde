import { Module } from '@nestjs/common';

import { ProductsController } from './players.controller';
import { ProductsService } from './players.service';

@Module({
  controllers: [ProductsController],
  providers: [ProductsService],
})
export class ProductsModule {}
