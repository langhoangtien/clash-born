# Hero level and shop

Press **B** or **Shop / Hero** in the match. Buy from the 25-item match catalog of components and recipes with icons,
inspect six slots, click an equipped item to sell. Purchase auto-equips into the
first free slot. Insufficient gold, duplicate exclusive items and a full inventory
are rejected without charging. Selling refunds 50% (rounded down). Final recipes
can be purchased directly and discount owned direct components.
Shop is available anywhere, including while dead; the match continues unless P
pauses it. Opening the panel stops hero approach/attack and movement input.

The dropdown and **Chọn hero & chơi trận mới** restart the match with that named
hero and its fixed skill. The default remains Aelira, preserving the controls.

| Hero | Base STR/AGI/INT | Skill and main growth |
| --- | --- | --- |
| Aelira · Xạ thủ | 21/27/17 | Base Power; AGI +3.2/level |
| Brakk · Thiết Quyền | 30/16/15 | Battle Rhythm; STR +3.8/level; melee |
| Myra · Pháp sư | 18/18/30 | Pure Throw; INT +3.7/level |

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
  allied tower/creep lands the last hit. Melee/ranged creeps give 45 total XP and
  40/50 last-hit gold; catapult gives 90 XP/75 gold; tower gives 150 XP/250 gold.
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
their UID companions; twelve `data/match/*_growth.tres` Resources;
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
The original limitation above has been superseded: direct recipe purchases and one
fixed five-rank skill per named hero are implemented in `docs/late_game_items_passives.md`. Two future
active skill slots are still pending.

Latest siege/economy/navigation tuning: `match_balance.md`.

Hero death defaults: 8 + 2 × (level − 1) seconds to respawn, lose up to
25 × level unspent gold. Exact behavior/tests: `docs/death_lane_attacks.md`.
