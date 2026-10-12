# Balance Hub

Open `data/balance/balance_hub.tres` in the Godot editor when tuning the game.
It is the central index for the match balance resources:

- `match_settings`: wave timing, creep/tower values, rewards, respawn and fountain rules.
- `global_formulas`: shared armor, damage, attack-speed and resistance formulas.
- `hero_archetypes`: the five playable unit archetypes and their attached stats/skills.
- `abilities`: the current stun, slow and armor-shatter definitions.
- `item_resources`: the editable equipment Resources already stored in `data/equipment`.

`match_settings` also exposes player command limits:
`player_creep_command_radius` for nearby creep farming,
`player_structure_command_radius` for tower/core approach, and
`player_hero_command_radius` for hero commands. These keep
the attack button local to the current lane/camp instead of selecting a wave at
the enemy base.

Each roster profile in `match_settings.hero_profiles` now owns its base
strength/agility/intelligence, HP, physical armor, attack speed/BAT and per-level
growth. `primary_attribute` is authoritative: one point of the primary stat
adds one physical damage, so a STR/AGI/INT item grants the matching damage in
addition to its normal HP, armor or attack-speed bonus.

The match catalog also exposes the complete generated item list through the hub,
including recipes and late-game items. Edit the referenced Resource, save it,
then run the balance tests before judging a change in a live match. Values that
belong to a formula stay in `scripts/core`; changing a formula should be treated
as a rules change and verified against the full regression suite.

Validation command:

```powershell
$godotExe = 'C:\Users\Admin\.codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --path 'D:\Clashborn' --script res://tests/test_balance_hub.gd
```
