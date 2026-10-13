# Phase 0 audit — Objective Registry scope

Authority: `docs/mobile_moba_behavior_contract.md` only. This audit records the
pre-Phase-1 state; it does not introduce another behavior contract.

| Contract rule | Pre-Phase-1 state | Phase-1 result |
| --- | --- | --- |
| Semantic objective IDs and explicit prerequisites | `MapLayout` supplied IDs/prerequisite arrays, while `tower_registry` was an untyped runtime dictionary. Core was outside that registry. | `StructureNode` and `ObjectiveRegistry` hold semantic topology; both cores are registered with explicit guard prerequisites. |
| T1 → T2 → T3 independent per lane | Runtime check iterated authored tower prerequisites and was correct for lane tiers. | Preserved through `ObjectiveRegistry.is_attackable`. |
| Any destroyed T3 opens both T4 | T4 used the authored prerequisite list as an implicit **all** condition, so it required all three T3s. | T4 lists those IDs as `prerequisites_any`; either guard opens after one T3. |
| Both T4 destroyed opens Core | Separate `_core_is_unlocked` check. | Core topology is in the registry; compatibility helper delegates to it. |
| Damage rejected at impact | `CombatEngine.damage_filter` called separate tower/core checks. | The filter calls `ObjectiveRegistry.is_attackable` for every structure/core impact. |
| Creep objective query | `get_next_attackable_structure` walked T1/T2/T3, then returned a T4 guard. | It delegates to `next_lane_objective`, which returns only T1/T2/T3 in the requested lane. |

Current target/movement ownership observed during the audit:

| Actor | Target writer | Movement/path writer |
| --- | --- | --- |
| Lane creep | `lane_creep_ai.gd` | `lane_creep_ai.gd` through `MobaMatch._issue_ai_move` |
| Bot hero | `enemy_bot_ai.gd` / `_drive_target` | `enemy_bot_ai.gd` through `MobaMatch._issue_ai_move` |
| Tower | `tower_ai.gd` | None (combat-only) |
| Core | `MobaMatch._tick` | None (combat-only) |
| Player | input handlers / `_drive_target` | input handlers / `MapUnit.go_to` |

These are legacy orchestration paths. They remain intentionally unchanged in
Phase 1, except that objective legality is now centralized. In particular,
there is not yet a `MatchIntentExecutor`; the existing controllers still own
their existing target/path writes, so Phase 1 does not introduce a second
writer for any actor.

Existing relevant regression coverage before this phase: `test_lane_ai_regressions.gd`
covered real creep T1→T3 progression. New `test_objective_registry.gd` covers
the contract's independent lane locks, T4-any-T3 unlock, Core-both-T4 unlock,
impact-time checks, and lane-query non-jumping behavior.
