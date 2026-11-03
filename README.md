# THE VEIL — Ordinary Friday opening prototype

A Godot 4.3 desktop opening built from the existing Greyhaven town, residential scenes, furniture, and character placeholders. Starts Friday at **6:42 PM**. No supernatural mist or monsters appear.

## Play in a browser

[Play the browser opening](https://the-veil-opening-finn.velvetymyna.chatgpt.site). This is a single-threaded WebGL2 export. Desktop Chrome, Edge or Firefox with WebGL2 enabled is required. Click the canvas to capture the mouse; Escape releases it. This is the same guided-driving prototype, not a new environment or a second implementation.

To rebuild with the official Godot 4.3 Web export templates installed:

```sh
godot --headless --path /path/to/TheVeil --export-release Web /absolute/export/index.html
python opening/build_web.py /absolute/export
```

The postprocessor wraps gzip transport for the engine and game pack, keeping each file below common static-host limits. The original asset files are unaffected. Serve the export over HTTPS (or localhost for development). Full browser playthrough is still unverified: the cloud QA browser reported missing WebGL2 on the preview environment.

## Run

1. Download/clone branch `work/opening-prototype` with all assets:
   ```sh
   git clone --branch work/opening-prototype https://github.com/jafetmora79-lab/TheVeil.git
   ```
2. Install **Godot 4.3 stable (standard build)**. Later Godot 4 versions have not been tested.
3. In Godot, Import the repository-root `project.godot`. Wait for the first asset import; the town contains many models.
4. Press **F6** with `opening/opening.tscn` open, or **F5** to run the project.

Command line after import:
```sh
godot --path /path/to/TheVeil
```

This is source for the Godot editor, not a packaged Windows executable ; the browser export is hosted separately. The existing GitHub Pages asset gallery remains separate and unchanged.

## Controls

| Input | Action |
|---|---|
| W/A/S/D | Walk |
| Mouse | Look |
| E | Interact with the object in view within 2.5 metres |
| Shift | Walk faster |
| Escape | Pause/resume and release/capture the mouse |
| R | Restart the whole opening |
| W while driving | Accelerate |
| S while driving | Brake |

## Playthrough

Wake beside the bed. Open the bedroom door with E and explore the house. Check the kitchen fridge to discover the grocery objective. Take the keys hanging from the coat rack beside the front door; taking them early also works. Open the front door, walk down the porch steps, and approach the labelled car seat marker on the driveway. Press E, then hold W to drive; release W to coast or press S to brake. Arrival at the supermarket parking marker ends this prototype. R replays it.

Doors, windows, drawers and appliance hinges use the existing house interaction metadata. Room ceiling switches work. The grocery/key checks gate front-door departure. The first destination is the existing supermarket **parking area**, not a new shop interior; this is a reversible prototype choice, not a decision about the later game-shop/mist ordering.

## Scope and limitations

- **Driving is guided:** the player controls acceleration/braking, with automatic steering along Maple Avenue → Oak Street → Main Street → supermarket parking. No reverse, free steering, vehicle physics, traffic simulation, collision response or car exit yet. Turns currently snap at road intersections.
- **No sedan asset exists on the inspected source branch.** A labelled driveway seat and an eye-height driving camera substitute for it. No new vehicle model was generated.
- Pack 04 commercial building models are absent. The existing parking lot is present, but the supermarket building/interior and grocery purchase are unfinished. Do not mistake arrival text for a playable shop.
- Ruth, Sarah and Eddie's existing meshes stand along the route as static population placeholders. No new character art, animation, dialogue or story roles were authored for them. Traffic, crowds and an ordinary-town soundscape remain unfinished.
- The existing fridge has a solid carcass, without modelled interior shelves. Its animated door and inspection subtitle convey the empty-fridge discovery; a visible hollow interior is still needed when asset work resumes.
- Existing clock art says 6:47. This prototype hides the alarm-clock instance at runtime and places a 6:42 PM label at its location; original models/textures and source scene metadata remain unchanged. HUD time is fixed for this short opening; there is no day/night simulation.
- No voice acting, music, footstep/engine audio, inventory UI, save/load, controller/mobile UI or final cinematic polish. R is a full reset, not a save checkpoint.
- The whole residential town loads at once. Performance and visual presentation on Windows hardware still need a human playtest.

## Validation

Read [opening/TEST_REPORT.md](opening/TEST_REPORT.md) for the exact checks, known engine diagnostic, and untested areas. To repeat the automated checks with Godot 4.3:

```sh
godot --headless --path /path/to/TheVeil --editor --import --quit
godot --headless --path /path/to/TheVeil --script res://opening/tests/smoke.gd
```

Success prints `OPENING_SMOKE: PASS` and exits 0; failed assertions exit 1. The test checks collision traversal and progression in the real scene, not visual quality or human input feel.

## Preservation and project context

Based on source commit `0d8088dc6dff65a526f2b09df777f0fa92ab445e` of `claude/practical-cray-hi2y54`. Implementation lives under `opening/`, plus the root project configuration. Existing asset files and gallery content are preserved. `docs/.gdignore` excludes website-only assets from Godot scanning (including a pre-existing GLB with a corrupt embedded PNG) without altering website delivery.

Read [docs/THE_VEIL_MASTER_CONTEXT.md](docs/THE_VEIL_MASTER_CONTEXT.md) before extending story or assets. The inspected branch contained asset scenes and interaction metadata, but no `project.godot`, player script, driving system or quest implementation to reuse. This prototype supplies that missing gameplay layer and instantiates the existing combined town/house scene.
