# The Veil validation report

Inspected commit [5018570374688f64839244b421fa8d246d7012d2](https://github.com/jafetmora79-lab/TheVeil/commit/5018570374688f64839244b421fa8d246d7012d2) on `claude/practical-cray-hi2y54`. Scope is that snapshot. The project bible establishes a normal, inhabited Greyhaven during the first drive. Confirm the destination and stop order with the opening implementation before placing acceptance checkpoints.

## Findings

| Area | Result at the inspected commit |
| --- | --- |
| Runnable opening | The tree contains no `project.godot`, main-scene configuration, or assembled opening. The four baseline asset scenes exist. `Greyhaven_Town_Complete.tscn` instances the residential town and commercial scenes. The sedan scene is a `Node3D` with a driver camera, lights, and entry areas. It has no driving controller or vehicle physics. |
| Scene, model, texture and material paths | Compared 590 literal `res://` references across 76 scenes, 204 resources, seven GDScripts and five shaders with the case-sensitive Git tree. Every referenced path exists. Checked 3,028 source and dependency paths across 550 GLB import sidecars with zero missing paths. Generated `.godot/imported/` destinations were excluded. GLB binary payloads, internal texture URIs, Godot import, and dependency type compatibility remain unverified. |
| Script and resource checks | No duplicate resource IDs, unresolved literal `ExtResource` or `SubResource` IDs, or missing literal script dependencies surfaced. The seven scripts cover the face demo and rig, mist tentacle, atmosphere controller and preset, flicker, and mist cards. No duplicate opening gameplay system or specific GDScript parse error was identified in the static review. GDScript and shader parsing still require Godot. |
| Renderer and Web | No renderer is configured because the project file is absent. No Web export preset, WASM, or PCK exists. The asset handoff specifies Godot 4.3 Compatibility. Shader output, memory use, loading and input are pending real export testing. |
| Gallery and Pages | `docs/index.html`, `docs/.nojekyll`, `gallery.js`, and `preview-glb.js` exist. All 918 bundled catalog paths resolve in the pinned tree. The gallery fetches assets from GitHub at runtime. Live Pages settings and gallery rendering were outside the static check. |

## Running the validators

Use Python 3.10+ from the repository root. All three commands are read-only and return exit status 1 on failed checks.

```sh
python development-tools/validate.py project .
python development-tools/validate.py project . --required-scene path/to/actual_opening.tscn
python development-tools/validate.py route path/to/drive.json
python development-tools/validate.py route path/to/drive.json --planned-distance-m DISTANCE
python development-tools/validate.py web . path/to/staged-pages-root --entry play/index.html
```

- **Project** checks baseline asset scenes, additional required scene paths, the configured entry point, literal resource paths and local resource IDs, and GLB/glTF external image and buffer paths. It does not resolve UID-only or dynamically constructed paths, validate embedded model payloads, or compile scripts. Once a runnable project exists, run `godot --headless --path . --import` and inspect the log. Then run `godot --headless --path . --quit-after 120` and inspect the log for load and startup errors. Exercise the full opening interactively.
- **Web** expects an explicit Compatibility setting and a standard single-threaded export preset with Web extensions disabled. Stage an exact copy of the gallery files and sample GLB from `docs/` at the Pages root. Export with the stock Godot HTML shell into `play/index.html` below that root. The checker verifies the pinned gallery bytes, required same-stem HTML/JS/WASM/PCK files, binary signatures, declared file sizes, and local HTML asset URLs. Use original Git file bytes when staging. Line-ending conversion changes the gallery hashes. After a deliberate gallery update, review and refresh those hashes. Serve the staged site under a repository-style subpath and open both the gallery and the play entry. Check the browser console and network requests, WASM MIME type, input and audio. Confirm Pages publishing settings separately. [Godot Web export](https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_web.html) · [GitHub Pages publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-site)

## Greyhaven route procedure

1. In a disposable QA build, define world-space checkpoint centers and radii for the driveway departure, required turns, and arrival at the confirmed destination. Place radii on the actual drivable lanes. Use metres and seconds.
2. Record the sedan's world position on a single normal drive at 10 Hz or faster, starting in the departure area when the vehicle begins its trip. Include stops for traffic and turns. End in the destination area. Use the actual controller and collisions. Keep pauses, teleports, resets and respawns out of the trace. Repeat on representative drives.
3. Save a JSON object with `checkpoints` in route order and `samples` in time order. Each checkpoint is an object with `xyz` (three numbers) and `radius_m`. Each sample is an object with `t` (monotonic seconds) and `xyz` (three numbers). Sample gaps must be at most 0.25 seconds.
4. Run the route check. It sums the 3D distances between consecutive samples, divides by elapsed time for average speed, and confirms that the run entered every checkpoint in order. The timer ends at the first destination sample after the required checkpoints. The minimum is 60 seconds and the preferred range is 75–90 seconds. If a separately measured centerline length is available, pass it as `--planned-distance-m` to estimate duration at the observed mean speed. Checkpoint entry is evidence for the recorded run. The tool cannot authenticate a trace or prove the road is traversable from scene geometry.

**Measurements pending.** Roads and town layout assets exist. The pinned commit has no drivable opening, so no route distance, speed, duration, or in-game reachability was measured.

## Handoff and test status

- Claude should establish the Godot project and opening entry scene, connect the opening and destination through actual vehicle physics and road collisions, then record a drive. Run import, launch, and browser tests once the project and export exist.
- Completed the static snapshot checks above. Python compilation passed. Local synthetic fixtures exercised valid project references, a case mismatch and undefined resource ID, a completed route, an incomplete route, a drive under 60 seconds, valid staged Web structure, gallery drift, an invalid WASM signature, and a broken loader URL.
- Godot import, headless launch, driving playtest, and browser launch were not performed. Godot was unavailable on PATH, and the pinned snapshot supplies neither a runnable project nor a Web export. The fixtures exercised the validator only.
