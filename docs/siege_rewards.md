# Siege creeps and shared death rewards

## Match tuning

| Unit | HP | Physical armor | Attack range | Physical damage |
| --- | ---: | ---: | ---: | ---: |
| Melee creep | 700 | 4 | 110 | 35 |
| Ranged creep | 450 | 0 | 390 | 45 |
| Siege catapult | 1600 | 10 | 300 | 80 |
| Tower | 5000 | 16 | 600 | 220 |
| Default ranger | 1600 | 8 | 550 | 100 |

Tower previously had 6000 HP/20 physical armor/235 damage. Hero attacks now apply
50% of mitigated damage to structures, up from 40%; normal creeps retain 65%,
catapults apply 100%. Tower magic armor remains 12; cores remain unchanged.
Each unit uses its own collision-edge Attack Range, independently of Cast Range.
Hero profiles/equipment/effects still modify those ranges through existing stats.

Waves contain two melee and one ranged creep per team/lane. One catapult is added
on waves 1, 4, 7, ... (configurable `siege_wave_interval`, zero disables it).
The first wave is 24 units, regular waves 18. Live cap remains 108 and counts all
three types; spawning is atomic, so skipped waves do not advance the wave number.
Catapults use the same A* routes, terrain collision, target selection, cooldowns,
seeded engine and impact-time damage as other creeps. Speed is 360, radius 26,
attack rate 0.65/s, projectile speed 650. The rectangular cart/wheels/stone mark
is presentation only; this unit has no separate combat engine or special damage
immunity. Towers still prioritize creeps over heroes, nearest within category;
melee units normally enter tower range first, then the cart can absorb shots.
No hero-defense retaliation/aggro lock has been added in this change.

## Rewards

`MatchRewards` calculates payouts from shared runtime states and simulation ticks;
scene applies them through existing HeroProgression. Settings remain configurable.
The following are Clashborn defaults inspired by Dota's reward principles, not a
full reproduction of a particular Dota patch's formulas:

- Melee creep: 40 last-hit gold; ranged creep: 50; both give **45 total XP**.
- Catapult: 75 last-hit gold, **90 total XP**.
- Hero: kill gold **250 + 16 × victim level**; **100 + 40 × victim level total XP**.
- Hero assistance: a separate pool **80 + 12 × victim level**, shared by eligible
  assistants (nearby living heroes or heroes damaging the victim in the last 30s),
  excluding the credited killer. No assist pool is paid for an uncredited team kill.
- Tower: 250 last-hit gold, **150 total XP**; cores have no death bounty.

Living enemy-team heroes within 1000 center-to-center units (inclusive) split the
XP pool, independently of last hit. Dead/outside heroes receive none and do not
dilute the pool. All living nearby heroes count, including capped heroes; capped
HeroProgression discards its XP share. Integer remainder goes to lexically sorted
hero IDs, conserving the pool and giving deterministic results. Two nearby heroes
share a regular creep's 45 XP as 23/22; one hero receives 45. Friendly heroes never
receive rewards for their own team's deaths. Last-hit gold is independent of XP
range, even for a projectile whose hero source has died.

Actual positive applied hero damage is recorded at **impact**, not launch. A hero
last hit gets direct kill credit. When an enemy tower/core/creep lands the last hit,
the most recent hostile hero dealing damage within 30 simulation seconds gets
kill gold, even if that hero has left the area or died. Simultaneous-tick ties use
sorted hero IDs. Prior contributors or living nearby allies can receive assists.
If no recent hostile hero exists, the kill bounty is split across the killing
team's entire hero roster, including dead/distant heroes. A single Blue player
therefore receives 266 gold for a level-one Red hero dying to Blue tower even
without prior damage; five Blue heroes split the same bounty 54/53/53/53/53.
XP is still local. Death and respawn clear attribution so a previous life cannot
claim a later kill. Pause freezes the clock, including credit-window aging.

The calculator is tested with ten heroes, but the playable map remains 1v1.
No 5v5 controls, kill-streak/first-blood/comeback bounty, death gold loss, unreliable
vs reliable gold, denies, neutral kills or full Dota economy are implemented.

## Changed files

New: `scripts/match/match_rewards.gd`, `tests/test_siege_rewards.gd` and their UID
companions; this document. Updated: MatchSettings, default_match Resource, match
controller, CombatUnit view, three match regression suites, README, DESIGN and
combat/progression/playable/balance documentation. Core damage formulas and Sandbox
reference stats are unchanged.

## Verification

Godot 4.7.2 executed siege/rewards tests: 50 headless checks, 51 with the NVIDIA
OpenGL renderer, zero failures. Tower-only tests measured regular melee survival
3.50s and catapult survival 12.40s using actual combat projectiles. Tests cover
five-hero team bounty conservation, two-hero XP sharing, assists, high-level
victims, dead/distant contributors, expiry boundaries, insertion-order invariance,
siege wave scheduling/cap, all six routes, and an actual hero-impact followed by
lethal tower projectile paying the player once. The renderer image is saved to
`.local/siege-creeps.png` and inspected for cart silhouettes.

Existing automated suites also passed: Phase 1–6 (23/112/170/645/170/690 checks),
range/projectiles (93), playable match (72), progression/shop (43), fountain (18),
and match balance/navigation (55 including the three-minute native-physics soak).
The soak reached tick 5400, eight admitted waves (cap can skip a scheduled spawn),
cores 10000/10000, creep damage TOP/BOT 6925.81 and MID 1278.87, with no targetless
navigation stalls. This is an idle-player baseline, not a guaranteed human match
length. Default project scene also ran 180 frames on the real renderer, exit 0.

Reference reward principles: [Dota Gold](https://liquipedia.net/dota2/Gold) and
[shared Experience](https://liquipedia.net/dota2/Experience). Clashborn deliberately
uses its own configurable bounty amounts and credit window.
