# Phase 3 — Lane creep / catapult migration

Authority: `docs/mobile_moba_behavior_contract.md` only.

`LaneCreepController` now owns decisions for every non-neutral TOP/MID/BOT
creep, including siege catapults. It emits one `BehaviorIntent` in this order:

1. `HERO_RETALIATE` from a bounded `HERO_DAMAGE` fact;
2. `LANE_COMBAT` against an enemy, non-neutral creep in the same lane;
3. `STRUCTURE_SIEGE` against the snapshot's `ObjectiveRegistry`-supplied next
   T1/T2/T3 for that lane;
4. `LANE_ADVANCE`; or
5. `RETURN_TO_LANE` after invalid/unreachable target facts.

Incomplete/missing lane objective configuration emits `CONFIG_ERROR` and no
target or movement destination. T4 and Core are absent from the snapshot's lane
objective query, so lane creeps cannot choose them.

The legacy `lane_creep_ai.gd` is no longer instantiated or called by
`MobaMatch`. The migrated actor's only target/path writer is `IntentExecutor`.
Neutral creeps remain on their existing jungle path, as do towers, Core, bot,
and player actors.

## Phase 4 structure-controller handoff

Use the existing API; do not create a second intent/objective system:

```text
snapshot = behavior_pipeline.begin_tick(tick, entities, visibility, objective_registry)
intent = StructureController.decide(snapshot, structure_memory)
behavior_pipeline.apply_intents([intent], snapshot, entities, objective_registry)
```

The structure controller emits combat-only intents (`has_destination = false`)
and hands them to the existing pipeline's `apply_intents` call.
`IntentExecutor` validates target life/team/vision and locked objectives. Tower
priority, target lock, and protection facts remain a Phase 4 migration concern.
