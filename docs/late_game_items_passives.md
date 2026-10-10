# Late-game items, recipes and starting passives

## Match item progression

The playable match now has 23 items: twelve purchasable components and eleven
late-game recipes. The separate Combat Sandbox keeps its original fourteen
reference resources. A recipe cannot be bought without every listed component.
Crafting removes those components, charges only the recipe fee, and puts the
finished item into the first released slot. This also works with six occupied
slots. Selling refunds 50% of the finished item's total value.

| Item | Total | Result |
| --- | ---: | --- |
| Giày Tốc Độ | 500 | +55 movement speed |
| Găng Tốc Độ | 650 | +40% attack speed |
| Kiếm Lớn | 700 | +25 physical damage |
| Kiếm Crit I | 1600 | Kiếm Lớn + 900; +25 damage, 20% crit ×1.2 |
| Kiếm Crit II | 4100 | Crit I + Kiếm Lớn + 1800; +80 damage, 25% crit ×2.5 |
| Búa Bash | 2900 | +60 damage, +15 STR; 20% stun 2s and +70 physical damage |
| Giáp Băng | 3600 | +28 armor/+12 magic armor; attackers lose 35% AS for 2.5s |
| Giáp Phản | 3000 | +20 armor/+45 damage; reflects 15% applied damage as pure |
| Trái Tim | 4300 | +2400 HP, +40 STR, +25 HP regeneration |
| Giày Sức Mạnh | 2300 | +75 move, +65% AS, +15 all attributes |

Other final items specialize in AGI/evasion, armor/AS/armor reduction, INT/magic,
and mixed pure damage. STR still adds HP/regeneration, AGI adds armor/attack speed,
and INT adds mana/magic armor through the existing central formulas.

`EquipmentData` stores component IDs and recipe fee. Special combat modifiers are
data too: bash chance/duration/damage, damage reflect, retaliatory attack slow.
Basic attack projectiles snapshot offense as before; bash and on-hit damage roll
only at impact. Reflect never reflects reflected damage. Frost retaliation uses a
refreshing simulation-timed status. Pause freezes every duration.

## BAT and movement

Match heroes use BAT 2.0 (`base_attacks_per_second = 0.5`). Attack speed is capped
at five times base speed, so a hero cannot exceed 2.5 attacks/second (500%), even
with items, AGI and temporary stacks. The Sandbox's existing absolute cap remains.
Opening hero movement is reduced from 430 to 320; movement boots restore meaningful
mobility. Tower collision-edge attack range is reduced from 750 to 600.

## Hero selection and passive skill

A fresh match pauses on a hero/passive draft. Choose one of the three current hero
stat profiles and one of eleven starting passives, then press the start button.
The confirmed reload enters the match once rather than reopening the draft.

The selected passive begins at rank 1. Each hero level gained grants one skill
point; the passive can be raised to rank 5. Extra points remain available for
future skill slots. Implemented choices:

- Base damage: +15% source base physical damage per rank.
- Soul Hunter: +1 permanent damage per creep kill and +5 per hero kill, max 100.
- Long Shot: +80 Attack Range per rank.
- Pure Throw: +20% base physical damage as pure on-hit per rank.
- Fury: each landed hit grants 10% AS per rank for 6s, max ten refreshing stacks.
- Melee Bash: 20% stun for 1.5s with 30/40/50/60/70 bonus physical damage.
- Iron Skin: +6/8/10/12/14 armor.
- Strength or Agility: +20/30/40/50/60 of the selected attribute.
- Assassin: 15–35% crit with multiplier 2.0–3.0.
- Feast: 1.5–3.5% target max HP as pure on-hit damage.

The current content intentionally exposes one passive slot. The skill-point model
and unused points are ready for two future active skills, but those active skills,
their buttons, mana costs and cooldowns are not invented in this change.

## Detailed stats

The shop and Tab comparison now show STR/AGI/INT, current/max HP, three damage
types, armor and its physical damage reduction, magic armor, miss/evasion,
accuracy, crit chance/multiplier, status resistance, attack/cast range, movement,
attack-speed percentage, attacks/second, BAT, passive rank and six real items.

## Verification

Godot 4.7.2 executed 51 focused headless checks and 53 renderer checks with zero
failures. Coverage includes full-slot crafting, component consumption, exact Crit
I/II values, attribute/HP items, 500% cap, every passive category, skill points,
melee and projectile-impact bash, frost AS slow, finite 15% reflect, max-HP pure
damage, detailed UI, startup draft, and confirmed-draft transition. Renderer
captures: `.local/late-game-shop.png` and `.local/hero-passive-draft.png`.

All Phase 1–6, range/projectile, playable match, progression/shop, fountain,
match balance/navigation, siege/rewards and side-lane tests were also rerun. Exact
counts and the stable commit are reported with the completed change.
