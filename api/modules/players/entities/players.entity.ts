import { ApiProperty } from '@nestjs/swagger';
import { Column, Entity, OneToMany, PrimaryGeneratedColumn } from 'typeorm';

@Entity()
export class Player {
  @PrimaryGeneratedColumn('uuid')
  @ApiProperty({
    description: 'ID unique du joueur',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  id!: string;

  @Column({ type: 'varchar', length: 25 })
  @ApiProperty({
    description: 'Nom du joueur',
    example: 'PlayerOne',
  })
  username!: string;

  @Column({ type: 'int', default: 0 })
  @ApiProperty({
    description: 'Montant d\'argent du joueur',
    example: 100,
  })
  gold!: number;

  @Column({ type: 'int', default: 0 })
  @ApiProperty({
    description: 'Expérience du joueur',
    example: 200,
  })
  experience!: number;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  createdAt!: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  updatedAt!: Date;
}
