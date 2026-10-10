# Late-game items, named heroes and fixed skills

## Match item progression

The playable match now has 25 items: twelve purchasable components and thirteen
late-game recipes. The separate Combat Sandbox keeps its original fourteen
reference resources. Clicking a final recipe buys missing parts when the hero can
afford the remaining total. Owned direct components are consumed and discounted.
This also works with six occupied slots when crafting releases one. Selling refunds
50% of the finished item's total value.

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
| Desolator I | 2600 | +50 damage, −10 target physical armor |
| Desolator II | 4700 | +80 damage, −15 target physical armor |

Other final items specialize in AGI/evasion, armor/AS/armor reduction, INT/magic,
and mixed pure damage. STR still adds HP/regeneration, AGI adds armor/attack speed,
and INT adds mana/magic armor through the existing central formulas.

`EquipmentData` stores component IDs and recipe fee. Special combat modifiers are
data too: bash chance/duration/damage, damage reflect, retaliatory attack slow.
Basic attack projectiles snapshot offense as before; bash and on-hit damage roll
only at impact. Reflect never reflects reflected damage. Frost retaliation uses a
refreshing simulation-timed status. Pause freezes every duration.

## BAT and movement

Match heroes use BAT 2.0 (`base_attacks_per_second = 0.5`). Regular creeps use
BAT 2.5; towers and catapults use BAT 3.0. Attack speed is capped
at five times base speed, so a hero cannot exceed 2.5 attacks/second (500%), even
with items, AGI and temporary stacks. The Sandbox's existing absolute cap remains.
Opening hero movement is reduced from 430 to 320; movement boots restore meaningful
mobility. Tower collision-edge attack range is reduced from 750 to 600.

## Named heroes and fixed skills

A fresh match pauses on a twelve-hero draft. Every hero has a unique name,
starting STR/AGI/INT, primary attribute, per-level attribute growth and one fixed
skill. The confirmed reload enters the match once rather than reopening the draft.

The selected passive begins at rank 1. Each hero level gained grants one skill
point; the passive can be raised to rank 5. Extra points remain available for
future skill slots. Implemented choices:

- Base damage: +15/20/25/30/35% source base physical damage.
- Soul Hunter: permanent damage from creep/hero kills scales with rank.
- Long Shot: +80/120/160/200/240 Attack Range.
- Pure Throw: +20/25/30/35/40% base physical damage as pure on-hit.
- Fury: landed hits grant 10/12.5/15/17.5/20% AS for 6s, max ten stacks.
- Battle Rhythm: BAT becomes 1.9/1.8/1.7/1.6/1.5.
- Melee Bash: 20% stun for 1.5s with 30/40/50/60/70 bonus physical damage.
- Iron Skin: +6/8/10/12/14 armor.
- Strength or Agility: +20/30/40/50/60 of the selected attribute.
- Assassin: 15–35% crit with multiplier 2.0–3.0.
- Feast: 1.5–3.5% target max HP as pure on-hit damage.

The current content exposes one fixed skill per hero. Two future active skills,
their buttons, mana costs and cooldowns remain future work.

## Detailed stats

The always-visible bottom panel, shop and Tab comparison show STR/AGI/INT,
current/max HP/Mana, three damage
types, armor and its physical damage reduction, magic armor, miss/evasion,
accuracy, crit chance/multiplier, status resistance, attack/cast range, movement,
attack-speed percentage, attacks/second, BAT, skill rank and six real items.
World text uses blue for physical, white for magical and purple for pure damage.
MISS, CHOÁNG, CHẬM and CHẬM ĐÁNH appear directly over affected units.

## Verification

Godot 4.7.2 executes focused headless and renderer checks with zero
failures. Coverage includes full-slot crafting, component consumption, exact Crit
I/II values, attribute/HP items, 700% cap, Demon Claw, 8%/15% lifesteal,
generated bow/sickle/hammer icons, every passive category, skill points,
melee and projectile-impact bash, frost AS slow, finite 15% reflect, max-HP pure
damage, detailed UI, startup draft, and confirmed-draft transition. Renderer
captures: `.local/late-game-shop.png` and `.local/hero-passive-draft.png`.

All Phase 1–6, range/projectile, playable match, progression/shop, fountain,
match balance/navigation, siege/rewards and side-lane tests were also rerun. Exact
counts and the stable commit are reported with the completed change.
