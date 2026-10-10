# Hero level and shop

Press **B** or **Shop / Hero** in the match. Buy from the 23-item match catalog of components and recipes with icons,
inspect six slots, click an equipped item to sell. Purchase auto-equips into the
first free slot. Insufficient gold, duplicate exclusive items and a full inventory
are rejected without charging. Selling refunds 50% (rounded down). No recipes.
Shop is available anywhere, including while dead; the match continues unless P
pauses it. Opening the panel stops hero approach/attack and movement input.

The dropdown and **Chọn hero & chơi trận mới** restart the match with that hero.
Default hero remains ranger, preserving the existing playable controls.

| Hero | Base HP | Per-level growth |
| --- | --- | --- |
| Xạ thủ | 1600 | HP +120, physical damage +7, attack speed bonus +2.5 percentage points, move speed +2 |
| Đỡ đòn | 2400 | HP +200, physical damage +5, armor +0.8, move speed +1; melee |
| Pháp sư | 1400 | HP +100, magic damage +10, mana +30, move speed +1 |

Growth and equipment are recalculated through existing StatCalculator. Buying,
selling or leveling preserves current HP/Mana percentage, effects, attack/cast
timers, combat tick and position. There is no full-heal or reset shortcut. Hero
respawn keeps level/XP/gear and gold remaining after the death penalty; new matches reset them. Mage basic attacks use
the existing mixed physical/magical damage system; there are still no skill buttons.

## Economy defaults

- Starting gold 250; income 1 per two simulation seconds, frozen by pause.
- Maximum level 15; next-level XP = 100 + 50 × (level − 1). Overflow is retained
  and can grant multiple levels; capped heroes stop accumulating XP.
- Living opposing heroes within 1000 world units split death XP, even when an
  allied tower/creep lands the last hit. Regular creep 45 total XP / 20 last-hit
  gold; catapult 90 total XP / 45 last-hit gold; tower 150 total XP / 250 gold.
- Hero bounty scales with victim level. Tower/creep kills credit recent hero
  damage or share team gold; nearby/recent contributors can receive assists.
  Exact formulas and eligibility: `docs/siege_rewards.md`.
- Bots receive XP/gold and check for an affordable item every ten simulation seconds, using the same prices and six-slot inventory.

Settings are in `data/match/default_match.tres` / MatchSettings. Each hero profile
is a HeroGrowth Resource in `data/match/*_growth.tres`; base overrides and per-level
numeric UnitStats fields can be edited without changing combat code. Level and
shop live in HeroProgression and match_shop; structure damage remains in CombatEngine.

## Changed files and verification

New: `scripts/match/hero_growth.gd`, `hero_progression.gd`, `match_shop.gd`,
their UID companions; three `data/match/*_growth.tres` Resources;
`tests/test_progression_shop.gd` and UID; this document.
Updated: `scripts/match/match_settings.gd`, `moba_match.gd`,
`data/match/default_match.tres`, `README.md`, `DESIGN.md`,
`docs/playable_match.md`, `docs/combat_formulas.md`.

Godot 4.7.2 executed **43 new headless checks / 44 renderer checks**, zero failures.
Tests cover growth differences, thresholds/overflow/cap, source isolation, gear
stacking with level, HP/Mana and timer preservation, affordability, full slots,
unique items, refunds, UI, actual creep kill XP/gold, nearby assist XP, distance,
passive income/pause, respawn and new-match hero selection. Renderer screenshot
`.local/shop-level-preview.png` was inspected after improving panel readability.
All regression suites also executed: Phase 1–6 **23/112/170/645/170/690**, range
**93**, playable match **66** checks; zero failures.

Hero growth/economy remain experimental. No persistence between matches,
The original limitation above has been superseded: recipes and one five-rank
starting passive are implemented in `docs/late_game_items_passives.md`. Two future
active skill slots are still pending.

Latest siege/economy/navigation tuning: `match_balance.md`.

Hero death defaults: 8 + 2 × (level − 1) seconds to respawn, lose up to
25 × level unspent gold. Exact behavior/tests: `docs/death_lane_attacks.md`.
