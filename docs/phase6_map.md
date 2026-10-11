# Phase 6 — MOBA Map Foundation

## Run

Open the project normally (F5) and click **Map Prototype** in Combat Sandbox.
The map's **Combat Sandbox** button returns to the original mode. Direct launch:

```powershell
& 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path 'D:\Clashborn' res://scenes/map/map_prototype.tscn
```

Right-click walkable ground to move the selected probe. WASD drives it manually;
terrain collision still applies. Click a probe or use the team dropdown to select.
TOP/MID/BOT buttons traverse that lane to the enemy base. Stop clears the route;
Reset returns both probes to their team spawns; Pause movement freezes both.

Middle-drag or arrows pan the camera and disable follow. Wheel zooms. F toggles
follow selected; O/Overview shows the complete map. The panel has seven independent
overlay toggles. Spawn circles and empty tower rectangles are initially visible;
they can both be hidden. No tower entities or tower attacks are implemented.

## Authoring

Edit `data/maps/moba_foundation.tres` in Godot or a text editor. Tile rows form an
explicit grid, rather than generated geometry hidden in gameplay scripts.

| Symbol | Terrain | Walkable |
| --- | --- | --- |
| . | Ground / jungle passage | Yes |
| J | Jungle | Yes |
| L | Lane | Yes |
| W | River | Yes |
| # | Wall / rock cluster | No |
| B | Blue base | Yes |
| R | Red base | Yes |

`dimensions` must match row lengths/count; `tile_size` sets world units per cell.
`terrain_definitions` configures symbol color/name/walkability. Lane waypoints,
spawns and tower markers use cell coordinates; base areas use cell rectangles.
Blue lane order is stored; Red order reverses that same lane's array.
Keep passages wide enough for the intended collision radius. Editing a map
requires restarting the scene so static paths/collision rebuild from the data.

## Automated verification

```powershell
$godotExe = 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path 'D:\Clashborn' --editor --import
foreach ($phase in 1..6) {
    & $godotExe --headless --path 'D:\Clashborn' --script "res://tests/test_phase$phase.gd"
    if ($LASTEXITCODE -ne 0) { throw "Phase $phase failed" }
}
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_range_projectiles.gd
& $godotExe --path 'D:\Clashborn' --script res://tests/test_phase6.gd -- --capture
```

The capture run saves `.local/phase6-map-overview.png` and
`.local/phase6-map-navigation.png` (ignored QA files). It executes the real
Compatibility renderer; the headless run checks physics, navigation and UI input.
Executed with Godot 4.7.2: **690 headless / 692 renderer checks passed**.
Existing Phase 1–5 suites passed **23 / 112 / 170 / 645 / 170** checks; the
range/projectile regression passed **93**. Both standalone scenes ran 180 frames
with exit 0 and no runtime/resource-leak errors. Overview/navigation screenshots
were visually inspected.

## Modified-file inventory

| File | Change |
| --- | --- |
| data/maps/moba_foundation.tres | Authored grid, terrain, routes, bases, spawns, tower markers |
| scenes/map/map_prototype.tscn | Runnable scene with map world and camera |
| scripts/map/map_layout.gd | Resource, coordinate helpers, routes and validation |
| scripts/map/map_navigation.gd | Static radius-aware AStarGrid2D paths |
| scripts/map/map_world.gd | Primitive map drawing, terrain collision and debug overlays |
| scripts/map/map_unit.gd | Continuous physics probe reusing existing unit state/view |
| scripts/map/map_camera.gd | Pan, zoom, follow and map clamping |
| scripts/map/map_prototype.gd | Scene coordination, input and controls |
| scripts/units/combat_unit.gd | Flat-vector hero, creep and structure silhouettes |
| scripts/match/fountain_view.gd | Flat-vector fountain crystal and team aura |
| scripts/ui/sandbox_controller.gd | Map Prototype entry button |
| tests/test_phase6.gd | Map/navigation/collision/camera/input/mode regression tests |
| README.md | Phase 6 launch, controls, scope and executed QA |
| DESIGN.md | Map architecture and integration contract |
| docs/phase6_map.md | Usage, authoring, verification and file inventory |

## Flat-vector style slice

The prototype now includes a first style reference built from Godot drawing
primitives: soft lane insets, a continuous blue river ribbon, deterministic
jungle foliage, team-colored base badges, crystal towers, a fountain crystal,
and primitive hero silhouettes. This keeps the simulation independent from
rendering and avoids a large background texture. It is a visual slice for
approval; it does not yet replace every map decoration or provide final hero
and item artwork.

Godot also creates tracked `.gd.uid` files for the six new map scripts and the
new Phase 6 test. Existing scenes, unit Resources, combat formulas and earlier
tests retain their behavior; `project.godot` still opens the Combat Sandbox.

## Remaining limitations

Two navigation probes demonstrate the foundation; this is not a full 5v5 match.
No creep spawning, tower/base combat, jungle objectives, abilities on the map,
fog of war, multiplayer or Phase 7 features. Jungle/river have no gameplay bonuses.
Paths use a static grid with world-space movement, without smoothing or dynamic
unit avoidance; probes do not collide with one another. Right-clicking blocked
terrain rejects the destination instead of snapping to a nearby cell. Navigation
probe physics is not an authoritative multiplayer simulation. Map edits are not
saved from the running prototype. Camera clamping can show centered background
margins when the viewport exceeds map dimensions at small zoom values.

Stop after Phase 6. Further gameplay requires a separate requested phase.
