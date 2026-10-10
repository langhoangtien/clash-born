# Hero death and side-lane attack approach

## Rules

MatchSettings now provides `respawn_seconds_per_level = 2` and
`death_gold_per_level = 25`, in addition to the existing `respawn_seconds = 8`.
Respawn duration is max(0, base) + max(0, growth) × max(0, level − 1).
Defaults: level 1 = 8s, level 5 = 16s, level 10 = 26s, level 15 = 36s.
A deadline is stored on death in 30Hz simulation ticks (at least one tick).
Pause stops aging; leveling cannot change an already scheduled deadline.

HeroProgression removes min(current gold, max(0, rate) × level) on an actual hero
death, exactly once per death event. No negative wallet, item loss, XP loss or
level loss. The bot uses the same rules. The HUD shows the actual gold lost
alongside the respawn countdown. Passive income continues while dead; purchasing
and selling still work as before. This is a simple configurable match penalty,
not Dota's reliable/unreliable gold system. Respawn clears the notice and restores
full current max HP/Mana at the team's base, retaining progression and equipment.

## Reproduced bug and correction

Auto-attack previously rejected any target hidden by terrain, including reachable
creeps on TOP/BOT across a jungle wall. Pressing J found no target and therefore
issued no approach path; the creep remained unharmed. This was reproduced with
walkable endpoints and a valid A* route in both side lanes before applying the fix.

Player auto-acquisition now accepts an occluded target only when existing
MapNavigation can find a route to it. MapUnit approaches through normal physical
terrain collision. The attack target ID remains empty until line of sight clears;
engine range validation and impact-time damage remain unchanged. Towers and NPC
acquisition retain their existing line-of-sight rules, using the default selector
parameter. Explicit friendly/dead targets are rejected by map attack driving.
Periodic pursuit replans also used to send the actor backwards to its current
cell center, causing diagonal approach oscillation. MapNavigation now starts each
path at the actual supplied world position while preserving A* intermediate
centers, exact destination and terrain collision. Clicking a friendly unit now explains that only enemy creeps/heroes can be attacked;
no friendly damage or deny feature is added.

This fixes the reproduced automatic approach failure; it does not enable attacking
through terrain or commanding a hero across the entire map. Targets must still be
within the configured acquisition radius. The playable scene remains 1v1.

## Files

Updated: `scripts/match/match_settings.gd`, `hero_progression.gd`, `moba_match.gd`,
`scripts/map/map_navigation.gd`, README, DESIGN, combat formulas, progression/shop
and playable match documentation.
New: `tests/test_death_lane_attacks.gd` and UID, this document.

## Verification

Godot 4.7.2 ran the real scene: 31 headless checks and 33 renderer/capture checks,
zero failures. Side-lane tests use continuous native movement
around jungle walls, the existing clock/engine and real projectile impacts.
Both TOP and BOT creep HP decreases from 700 to 619.35, with clear line of sight
and valid attack range at impact. Renderer captures `.local/attack-top.png` and
`.local/attack-bot.png` show the approach result and damage.

Tests also cover duration/gold configuration, poor/empty wallets, an actual level-5
lethal hit, 480-tick respawn deadline, one-time 125 gold loss, HUD notice, pause,
gear/XP persistence and revival. All prior automated suites were rerun successfully:
Phase 1–6 (23/112/170/645/170/690 checks), range (93), playable match (72),
progression/shop (43), fountain (18), match balance/navigation (50), siege/rewards
(46). No changes to the Sandbox combat math or reference stats.
