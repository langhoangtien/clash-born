# Phase 2 — Behavior Intent foundation

Authority: `docs/mobile_moba_behavior_contract.md` only.

Phase 2 installs a dark-launch pipeline without changing gameplay ownership:

```text
previous-tick BehaviorFact → BehaviorWorldSnapshot → controller decide
→ IntentExecutor apply → existing CombatEngine.step
```

`MobaMatch` collects expiry-bounded hero-damage and target-invalid facts after
combat, then creates the next tick's read-only snapshot before legacy decisions.
The pipeline's controller set is intentionally empty in this phase, so no live
actor is written by both legacy orchestration and `IntentExecutor`.

Typed API for Phase 3 lane-creep migration:

```text
BehaviorWorldSnapshot.begin_tick(...)
LaneCreepController.decide(snapshot, actor_id) -> BehaviorIntent
IntentExecutor.apply(intent, snapshot, entities, objective_registry)
```

The future controller must make exactly one `BehaviorIntent`; only the executor
may then write `runtime.target_id`, stop/cancel a path, or call `go_to`. It
validates expiry, life/team/visibility, and objective attackability through
`ObjectiveRegistry.is_attackable` before issuing any order. It deduplicates
movement destinations and rejects a second order for the same actor in a tick.

Controller ownership is declared in `BehaviorOwnership`:

| Actor | Future decision owner |
| --- | --- |
| Lane creep/catapult | `LANE_CREEP` |
| Jungle creep | `JUNGLE_CREEP` |
| Tower/base guard/core | `STRUCTURE` |
| Bot hero | `BOT_HERO` |
| Player hero | `PLAYER_COMMAND` |
