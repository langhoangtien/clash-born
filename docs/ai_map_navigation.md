# AI map navigation contract

The map presentation in `assets/maps/moba-simple-navigation-background.svg` is
the flat, no-foliage reference supplied for this map. It is visual-only: roads,
river and open ground are walkable; dark outlined islands are blocker polygons.
It is never used as a collision surface or as a single walkable rectangle.

The source guide's 600 × 600 marker coordinates are stored verbatim in
`reference_tower_points` and `reference_jungle_camp_points`.  `tower_world()` and
`jungle_camp_world()` provide their scaled positions for presentation tools while
the existing cell markers retain the match's authored lane/objective ordering.

Scene layers are deliberately separate:

- `VisualBackground`: SVG presentation only.
- `WalkableNavigation`: navigation data owner.
- `StaticBlockers`: terrain and world-boundary collision.
- `TowerBodies`: one `StaticBody2D` per live tower.
- `TowerRanges`: one `Area2D` per live tower, detection-only and never movement collision.
- `JungleCampSpawns`: spawn-anchor layer; never movement collision.

Blocked click destinations are rejected. Terrain polygons are checked both by
pathfinding and by `StaticBlockers`, so an actor cannot cut through a cliff even
when it is driven continuously.
