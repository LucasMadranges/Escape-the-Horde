import { Controller, Delete, Get, Post, Put } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';

import { ProductsService } from './players.service';

@Controller('products')
@ApiTags('products')
export class ProductsController {
  constructor(private readonly productsService: ProductsService) {}

  @Get()
  @ApiOperation({ summary: 'Récupérer tous les produits' })
  findAll() {
    return this.productsService.findAll();
  }

  @Get(':id')
  findOne() {
    return this.productsService.findOne();
  }

  @Post()
  create() {
    return this.productsService.create();
  }

  @Put()
  update() {
    return this.productsService.update();
  }

  @Delete()
  delete() {
    return this.productsService.delete();
  }
}
