# Escape the Horde

Sur le théme de vesperal, Escape the Horde est un jeu video de type top-down shooter.
Une partie doit être lancer par minimum 2 personnes. N'hésitez pas à ouvrir plusieurs onglets pour tester !
Vous devez survivre a 5 vagues de hordes de zombies par niveau.
Un shop est disponible après les 5 vagues pour acheter de nouveaux équipements.

Le projet est disponible à l'adresse ici : [escape-the-horde.mxv.me](https://escape-the-horde.mxv.me/)

Le projet contient :

- un jeu Godot (scenes/, scripts/, assets/)
- une API NestJS (dossier api/)
- un build web du jeu (dossier web/), servi par Nginx

## Équipes

Maxence Persine :

- Développement de l'HUD de création de partie, rejoindre, paramètres et quitter.
- Création des zombies et de la logique de déplacement des zombies / joueurs.
- Réécriture de l'API avec une base plus propre.
- Création du shop et des armes fusil à pompe / fusil d'assaut.
- Interconnexion des différents niveaux.

Paul Pruvost :

- Création de la scéne d'attente
- Récupération de tous les assets nécessaire au projet.
- Création du système de tir automatique et FOV.

Lucas Madranges :

- Création de l'API en temps réel sur NestJS.
- Ajout des connexions réseau temps réel entre le moteur Godot et l'API.
- Création de la map 1 et map 2.

## Demarrage rapide

1. Dupliquer .env.cp en .env a la racine
2. Lancer l'environnement complet :

```bash
docker compose up -d --build
```

Services exposes :

- web (Jeu Godot + build HTML5) via Nginx
- api (NestJS) en interne derriere Nginx
- db (Postgres)

## Mode dev (API)

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

Ce mode expose :

- Postgres sur 5432
- API sur 3000

## Architecture du depot

### Jeu (Godot)

- scenes/ : scenes principales (main_menu, main, level_1, level_2, etc.)
- scripts/ : logique du jeu (joueur, zombies, UI, reseau)
- assets/ : sprites, tilesets, sons
- shaders/ : shaders Godot
- project.godot : configuration du projet (Godot 4.6, Forward Plus)

### Web (build HTML5)

- web/ : export HTML5 Godot (Escape The Horde.html, .wasm, .pck)
- nginx/nginx.conf : sert le build web et proxy l'API et le WebSocket

### API (NestJS)

- api/ : serveur backend NestJS
  - modules/ : domaines applicatifs (game, players, realtime, session)
  - database/ : configuration TypeORM
  - common/ : filtres/partage
  - src/ : bootstrap et module principal

## Scripts utiles (API)

Dans api/ :

```bash
npm run start:dev
npm run build
npm run test
```

## Docker

- docker-compose.yml : stack prod avec db + api + web
- docker-compose.dev.yml : stack dev avec db + api
- nginx/ : reverse proxy pour le build web Godot et l'API

## Branches

- main
- develop (par defaut)
- feat/<nom-de-branch>
- fix/<nom-de-branch>
