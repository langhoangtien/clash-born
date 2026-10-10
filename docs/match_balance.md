# Match balance, lane recovery and equipment inspection

## Current tuning

| Setting | Previous | Current |
| --- | --- | --- |
| Tower HP | 1900 | 5000 |
| Tower physical damage | 185 | 220 |
| Tower physical/magic armor | 12 / 0 | 16 / 12 |
| Core HP | 3000 | 10000 |
| Core damage, physical/magic armor | 100, 8 / 0 | 150, 25 / 15 |
| Hero damage to structures after mitigation | 100% | 50% |
| Creep damage to structures after mitigation | 100% | 65% |
| Opening gold | 1000 | 250 |
| Passive income | 3/second | 1 every 2 seconds |
| Creep / hero kill gold | 40 / 250 | 20 / 125 + 8 × victim level |
| Ranger opening damage / per-level damage | 155 / 12 | 100 / 7 |
| Ranger attack-speed bonus per level | 3.5 percentage points | 2.5 percentage points |
| Tank opening / per-level physical damage | 145 / 7 | 95 / 5 |
| Mage opening physical/magic damage | 60 / 95 | 40 / 60 |
| Mage magic damage per level | 16 | 10 |

Only the local match uses siege modifiers and tuned item copies. Sandbox
reference item prices/bonuses and damage formulas remain intact. The engine
still resolves projectiles at impact; offensive stats and siege factor are
snapshotted at launch, so source death does not bypass reduction.

`MatchItemCatalog` halves physical/magic/pure damage, attack speed, crit chance,
accuracy and armor-reduction modifiers; item prices are tuned separately.
Examples: Heavy Sword +30 physical damage/1200 gold, Arcane Staff +30 magic/1400,
Swift Gloves +15% attack speed/650, Critical Blade +12.5% crit/1800.
All fourteen items have native SVG icons; UI tooltips describe current bonuses.
Buying/selling still preserves HP/Mana fractions, effects and combat cooldowns.

## Creep navigation and visuals

The old recovery code could create a direct segment to an earlier lane point
across blocked jungle after abandoning a target. Recovery now selects the
nearest forward point and routes there through the existing AStarGrid2D.
No teleport, obstacle disabling or second navigation engine is introduced.
Creeps target enemy creeps/towers from the same lane, avoiding accidental
cross-lane pulls. Heroes and cores remain valid targets in range.

Waves contain two melee and one ranged creep per team/lane plus a catapult on
waves 1/4/7/...; see `docs/siege_rewards.md` for updated stats/rewards. Regular creeps
have distinct silhouettes: melee circle/sword mark; ranged diamond/bow mark.
Melee resolves instant attacks; ranged creeps use moving projectiles.

## Equipment inspection

**Tab** or **Trang bị hai đội** toggles a two-hero comparison panel showing
level, HP, physical/magic damage and six live equipment icons per hero. Hover an
icon for item name/bonuses. Shop and comparison panels are mutually exclusive.
Opening either cancels player movement/attack; the match continues unless paused.
Bot checks an affordable purchase every ten simulation seconds, using the same
catalog/prices/gold and six-slot inventory; it does not get free equipment.

## Previous balance revision verification

Godot 4.7.2: new balance/navigation suite **55 headless checks including a
three-minute native-physics match / 52 renderer checks**, zero failures.
The long run reached tick 5400, nine creep waves, cores 10000/10000. Recorded
creep damage: TOP 9176.25, MID approximately 1242.81, BOT 9176.25. No targetless
creep remained stationary across the stall-check window. This is a baseline
autonomous match with the player idle, not a guarantee of human match duration.

Tests include all six team/lane recoveries from off-route positions through
physical collision, wave composition, lane target filtering, siege damage for
all three damage types, impact timing/source death, starting gold/income timing,
item/source isolation, loaded icons, bot buying, actual Tab input and panel slots.
Renderer images `.local/opponent-equipment.png` and `.local/balanced-shop.png`
were inspected. Existing Phase 1–6 tests (23/112/170/645/170/690), range (93),
playable match (66), progression/shop (43), fountain (18) passed again.

## Files and remaining limits

New: `scripts/match/match_item_catalog.gd`, `opponent_panel.gd` and UID files;
`assets/items/` fourteen SVG icons/import descriptors; `tests/test_match_balance.gd`
and UID; this document.
Updated: core engine and UnitRuntimeState siege fields, EquipmentData icon/summary,
match settings/controller/shop, CombatUnit silhouettes, four match Resources,
all fourteen equipment Resources (icon references only), progression/shop tests,
README/DESIGN/formula/progression/playable documentation.

Balance remains experimental, with no forced game length. Bot purchasing uses a
simple fixed build, not matchup reasoning. There is still no structure-body
blocking, dynamic unit avoidance, tower-before-core invulnerability, skill UI,
item recipes or multiplayer. Next useful validation is player testing siege
with creep support, then adjusting these configurable values from match feedback.

Current siege/reward verification and modified files: `docs/siege_rewards.md`.
