# Amélioration du système de champ de vision (FOV)

**Date :** 2026-04-27
**Statut :** Approuvé

## Contexte

Le système FOV actuel (`scripts/field_of_view.gd`) gère la détection en cône, le tir automatique et un rendu "lampe de poche". Deux problèmes principaux :

1. **Rendu insuffisant** — le cône ne respecte pas les obstacles, l'effet lampe de poche manque de dramatisme
2. **Pas de line-of-sight** — les zombies derrière les murs sont détectés et ciblés

De plus, un bug latent : le joueur est à `scale = Vector2(4, 4)`, donc le cône visuel dessiné est 4× plus grand que la zone de détection réelle.

## Architecture

### Composants

**`FieldOfView` (modifié)** — `scripts/field_of_view.gd`
- Construit le polygone de visibilité par raycast angulaire
- Émet `visibility_polygon_updated(polygon: PackedVector2Array)` chaque frame
- Valide le LOS des zombies par raycast direct
- Dessine le faisceau lumineux (warm gradient)
- Dessine l'indicateur de cible sur le zombie ciblé

**`FovOverlay` (nouveau)** — `scripts/fov_overlay.gd`
- Nœud enfant d'un `CanvasLayer` (layer = 10)
- Reçoit le polygone de visibilité via signal
- Dessine l'overlay sombre (plein écran minus polygone de visibilité)

**Convention murs**
- `StaticBody2D` sur la couche de collision physique **4** (dédiée)
- Les raycast FOV ciblent exclusivement cette couche
- Les zombies (layer 2) et le joueur (layer 1) ne bloquent pas la lumière

## Polygone de visibilité (Section 2)

Chaque frame dans `_update_fov()` :

1. Calculer `aim_angle` depuis la position souris → joueur
2. Lancer des rayons de `aim_angle - fov_angle/2` à `aim_angle + fov_angle/2` par pas de `ray_step_degrees` (défaut : 2°)
3. Chaque rayon : `PhysicsRayQueryParameters2D` sur couche 4 uniquement
   - Si collision : point = position de collision
   - Sinon : point = `origin + direction * fov_distance`
4. Ajouter `origin` au début et à la fin du tableau → polygone fermé
5. Émettre `visibility_polygon_updated(polygon)`

**LOS zombies** : raycast direct joueur → zombie sur couche 4. Si touché avant le zombie → zombie exclu du FOV.

**Perf estimée** : ~45 raycasts/frame (cône 90° à 2°) + 1 par zombie ≈ négligeable pour Godot 4.

## Overlay sombre (Section 3)

`FovOverlay` dessine via `_draw()` :

1. Convertir le polygone de visibilité (coordonnées **monde**) en coordonnées **écran** via `get_viewport().get_canvas_transform()` appliqué à chaque vertex
2. Récupérer les coins de l'écran (`get_viewport().get_visible_rect()`)
3. Construire un polygone unique via la technique du **pont** :
   - Coins écran (sens horaire)
   - Pont vers le premier vertex du polygone de visibilité (sens inverse = trou)
   - Polygone de visibilité en sens inverse
   - Pont retour vers le coin initial
4. `draw_colored_polygon(dark_polygon, Color(0, 0, 0, overlay_alpha))`

Aucun shader, aucun SubViewport. Signal uniquement pour la communication.

## Détection & tir automatique (Section 4)

**Zombie visible** si :
1. Dans l'angle du cône
2. Distance ≤ `fov_distance`
3. Raycast joueur → zombie (layer 4) ne touche aucun mur avant lui

**Cible** : zombie visible le plus proche (logique existante conservée).

**Tir** : `FieldOfView` appelle `_player.call("_shoot_at", direction: Vector2)` au lieu d'instancier les balles directement. `player_2d.gd` expose une méthode `_shoot_at(direction: Vector2)` découplée de la position souris.

**Indicateur de cible** : triangle pointant vers le bas dessiné au-dessus du zombie ciblé, dans `_draw()` du `FieldOfView` (position monde → espace local via `to_local()`).

## Correction scale & exports (Section 5)

**Fix scale** : dans `_draw()`, diviser toutes les distances de dessin par `_player.scale.x` pour corriger l'héritage du scale 4× du joueur.

**Exports :**

| Export | Valeur par défaut | Description |
|--------|-------------------|-------------|
| `fov_angle` | `90.0` | Angle du cône en degrés |
| `fov_distance` | `400.0` | Distance max (pixels monde) |
| `shoot_cooldown` | `0.3` | Délai entre tirs (secondes) |
| `ray_step_degrees` | `2.0` | Pas angulaire des raycasts |
| `overlay_alpha` | `0.85` | Opacité de l'overlay sombre |
| `wall_collision_layer` | `4` | Layer physique des murs |

## Fichiers à créer / modifier

| Fichier | Action |
|---------|--------|
| `scripts/field_of_view.gd` | Modifier — raycast polygon, LOS, scale fix, indicateur cible |
| `scripts/fov_overlay.gd` | Créer — overlay sombre CanvasLayer |
| `scripts/player_2d.gd` | Modifier — ajouter `_shoot_at(direction)` |

## Hors scope

- Système de particules pour le faisceau
- FOV dynamique (zoom/dézoom)
- Multiple sources de lumière
- Fog of war persistant (mémoire des zones explorées)