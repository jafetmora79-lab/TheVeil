# THE VEIL - Phase 1: the playable opening

Friday, 6:42 PM:

1. You wake up from a nap in your bedroom.
2. You find the fridge almost empty.
3. You grab the car keys.
4. You leave the house and get into your old sedan.
5. You drive through Greyhaven and park at the supermarket.

There are no monsters and no mist: the town is still ordinary.

* **Engine:** Godot 4.3, Compatibility renderer (OpenGL 3 / WebGL 2).
* **Project root:** the repository root (`project.godot`), so every asset keeps its `res://THE_VEIL_ASSETS_V2/...` path.
* **Browser build:** `docs/play/` → <https://jafetmora79-lab.github.io/TheVeil/play/>. The asset gallery stays at
  `/TheVeil/`.

## Run

* **Editor:** open the repository folder in Godot 4.3 and press Play (main scene `res://game/scenes/MainMenu.tscn`).
  The first import takes about a minute.
* **Headless automated playthrough:** wake-up to parking, with the real controllers and fixed 60 Hz physics:

  ```bash
  godot --headless --path . --fixed-fps 60 --script res://game/tests/opening_test.gd -- 50
  ```

  The last argument is the autopilot cruise speed in km/h.
* **Compatibility-renderer smoke run:** draw-call counts, no screenshots:

  ```bash
  xvfb-run godot --path . --rendering-driver opengl3 --script res://game/tests/render_smoke.gd
  ```

* **Regenerate the extended town:** this needs only numpy and Pillow. It writes `game/world/*` and does not modify
  `THE_VEIL_ASSETS_V2/`:

  ```bash
  python3 game/tools/build_world.py
  ```

* **Whole-map geometry check:** surface coverage / cracks, houses on the ground, route on the road:

  ```bash
  python3 game/tools/check_world.py
  ```

* **Web export:** uses the "Web" preset in `export_presets.cfg` (no-threads template, so it works on GitHub Pages
  without special headers), then copy the result to `docs/play/`:

  ```bash
  godot --headless --path . --export-release "Web" build/web/index.html
  ```

* **Browser self-test:** `play/index.html?autotest` runs the story interactions inside the exported build and
  logs `[Autotest] ...` to the browser console.

## Controls

| On foot | | In the car | |
|---|---|---|---|
| W A S D | move | W | accelerate |
| Mouse | look | S | brake, then reverse |
| Shift | sprint | A / D | steer |
| Ctrl (or C) | crouch | Space | handbrake |
| E | interact | E | get out (when nearly stopped) |
| Tab (or I) | inventory | Mouse | look around the cabin |
| Esc (or P) | pause / release the mouse | | |

In the browser, click the game to capture the mouse. Esc releases it, and the browser handles that itself. F10
prints the player state to the console (a developer aid).

## What is where

| Path | Purpose |
|---|---|
| `game/autoload/game_state.gd` (`Game`) | flags, objectives, inventory, interaction states, save / load (`user://veil_save.json`), settings (`user://veil_settings.cfg`), input map |
| `game/autoload/dialogue.gd` (`Dialogue`) | subtitles / protagonist observations. Data: `game/data/dialogue.json` (supports future `choices` for branching NPC dialogue) |
| `game/autoload/sfx.gd` (`Sfx`) | small original sound set synthesised at start-up (footsteps, doors, pickup, fridge hum, evening ambience); the engine hum is in the sedan |
| `game/data/objectives.json`, `items.json` | the opening's objective chain; item definitions with the future categories (tools, flashlight, radio, medical, notes, puzzle items, weapons) |
| `game/player/player.gd` | first-person controller (CharacterBody3D): walk 2.4 m/s, sprint 4.3, crouch 1.3; gravity, ramps / stairs, head bob, interaction raycast, wake-up camera |
| `game/interaction/interactable.gd` | one reusable component: hinge, slide, pickup, light toggle, observe, custom (vehicle) |
| `game/vehicles/player_sedan.gd` | the Pack 05 sedan with an arcade driving model (top speed 55 km/h), wheel spin / steer, steering wheel, driver door, first-person camera, procedural engine sound |
| `game/world/world.gd` | wires the assets into gameplay: Player_Home interaction metadata, observations, fridge contents, triggers, car entry / exit, parking, autosave / restore, distance culling |
| `game/world/scatter.gd` | woods and undergrowth as MultiMesh, with trunk collision |
| `game/ui/` | HUD (prompt, objectives, subtitles, fades, title card, inventory, pause, end card), settings panel, shared look |
| `game/scenes/MainMenu.tscn`, `World.tscn` | main menu (New Game / Continue / Settings / Quit) and the whole connected town |
| `game/world/Greyhaven_Core.tscn` | game copy of the Pack 02 town: same placements, minus the old ground, the woods and the debug zone labels |
| `game/world/Greyhaven_Extension.tscn`, `Greyhaven_Houses.tscn`, `generated/` | the extension and the re-fitted houses (from `game/tools/build_world.py`) |
| `game/world/world_data.json`, `scatter.json` | spawn / route / destination data and the woods scatter |

## Greyhaven, extended

In the Pack 02 layout the protagonist's house on Maple Ave was only about 200 m of road from the supermarket, about
15 s of driving. Greyhaven was therefore extended with the **existing generators used as libraries** (Pack 02
`town_layout.py`, Pack 03 `placement.py` / `build_residential.lot_connections`):

* **Route 9** continues as a county road from the town's south-east edge through the woods (two gentle bends, utility
  poles with street lights) to a T junction with a bus stop. It continues south to a closed future exit.
* **Harlow Ln** runs west into a new subdivision with **Aspen Ct** (a cul-de-sac) and **Fern Ct**, about 60 new
  Pack 03 houses with driveways, walkways, mailboxes, fences, yard trees and street lamps.
* The **protagonist's house** (`Player_Home.tscn`, furnished, unchanged) now stands on Fern Ct. Its lot reproduces
  the old Maple Ave lot exactly (same width, driveway offset, house shift and orientation), so the Pack 03 sedan
  marker, walkway and garage apron still fit. The generator asserts this.
* The old Maple Ave lot holds an ordinary neighbour's house (Pack 03 Ranch B).
* **Ground and woods** are regenerated for the whole, larger map. The ground is cut around every road, sidewalk and
  lot, so nothing sits under grass. A crack filler patches the two slivers where 30 m curve modules met the 0.5 m
  ground grid.
* **Fix:** the Pack 02 fence generator puts a post every 1.25 m across each driveway gap, so every driveway had 3-4
  posts standing in it. The extension uses a corrected fence run, and 34 such posts are removed from the game copy of
  the core town. `THE_VEIL_ASSETS_V2/` is untouched.

**The route** runs from the driveway on Fern Ct to the supermarket parking lot: Fern Ct, Harlow Ln, Route 9 (county
road), Route 9 (town edge), Main St (commercial district, past the game shop), then the supermarket lot. It is
**1,069 m** of continuous road with no detours or loops.

| Drive (real vehicle controller, autopilot along the road, fixed 60 Hz) | Measured time |
|---|---|
| Flat out (cruise above the car's 55 km/h top speed, slowing for bends) | 76.7 s |
| Normal: 50 km/h cruise | 82.4 s |
| Relaxed: 40 km/h cruise | 99.4 s |

## First destination

The story bible (section 2.1) makes the supermarket the opening's destination: "Get some groceries". The Pack 04
supermarket (signage, building, parking lot) is in the core town. The milestone completes when the car stands still
for 1 s inside the parking lot, and the end card shows the drive time. The game shop is directly across Main St, and
the protagonist mentions it (bible: he also wants a horror game) without leaving the scope of Phase 1.
