import { Column, CreateDateColumn, Entity, Index, PrimaryColumn, UpdateDateColumn } from 'typeorm';

@Entity()
export class Session {
  // Un joueur ne peut etre present que dans une seule game.
  @PrimaryColumn('uuid')
  playerId!: string;

  // Une game peut contenir plusieurs joueurs.
  @Index()
  @Column('uuid')
  gameId!: string;

  @CreateDateColumn({ type: 'timestamp' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp' })
  updatedAt!: Date;
}
