# Physics review: vanishing characters, walking through walls / floors / props (2026-11-20)

## Causes found (by reading the code, then measured with `game/tests/npc_physics_audit_test.gd`)

| # | Cause | Where |
|---|---|---|
| 1 | Scripted NPC walks (`NpcAnimator.walk_to`) moved the body with `root.position += ...`: no wall, prop, door or person collision and no floor height. Only a *following companion* collided. | `game/npc/npc_animator.gd` |
| 2 | Nothing moved a character out once a counter / crate / prop ended up on them (audit: the Cashier stood inside the supermarket counter in chapter 2). | `game/npc/survivor_body.gd` |
| 3 | `place_at` hides a character for good when no clear floor is found within 3 m (the story spot is too high / low, or not layer-1 floor). | `survivor_body.gd`, `world._spawn_npc`, `place_survivor` |
| 4 | The player's out-of-world recovery fired after 20 m / 1 s of falling (the world visibly vanishes first); and a hand-typed scene teleport (31 sites, some with y 0.7, -0.6, -0.8) could leave the player inside a prop. | `game/player/player.gd` |
| 5 | ~108 `tween_property(..., "position")` cutscene moves pass through geometry. Mostly monsters and props, where that is the staging; three move the player (`chapter11.gd:870`, `chapter14.gd:373`, `world.gd:1728`). Left as they are. | various |

## Changes

- **Scripted walks of every `VeilSurvivorBody` now collide** (walls, props, doors, people) and follow the floor. A blocked walk: opens a door it is heading for (0.5 s), asks `world.npc_route` for a detour (1.0 s), and only after 1.6 s with no way round walks through for 1.2 s (`NpcAnimator.jams` counts these) so a scene never waits forever on `arrived`.
- `NpcAnimator.free_walk = true` opts an authored scene out (used for Joan leaving the gas-station door in `living_town.gd`).
- **Survivor safety net:** once a second, a visible, idle (not walking / seated / holding) body overlapping a solid twice in a row moves to the nearest clear floor (<= 1.5 m).
- `place_at` widens its search to 6 m before giving up and hiding.
- **Player:** the same lift-out net (<= 1.5 m, only in control and on foot); out-of-world recovery after 8 m / 0.8 s.

## Tests

- New `npc_physics_audit_test`: every chapter start (2-16) lists hidden / unplaced / inside-a-solid / off-floor characters (seated and walking ones skipped); a scripted walk at a wall (may only cross when a jam was recorded); the player buried in a crate is lifted out. **PASS**.
- Passing with the change: chapter9, 10, 12_noah, 13, 14, 15, frank_skitter, colossus_market_last, pay_first.
- Same result as before the change: shelter_systems_test (1 failure), living_town_test (2 failures: `E4_crash_once`, `E4_car_stays`); scavenge_companion_test and eddie_exit_test give no result in either state.

## Needs the owner's eyes (nothing visual was checked)

Characters that pause at a doorway for ~1 s before detouring or pushing through; a character that shifts sideways when a prop lands on it; any cutscene whose NPC now stops short of its mark.
