"""THE VEIL cinematics - builds the shot ledger from one data table and VERIFIES every cited source function / flag against the repo.
   python docs/cinematics/tools/build_ledger.py            (run from the repo root)
Writes docs/cinematics/SHOT_LEDGER.md, data/shots.json, data/hookup_manifest.json, audio/cue_sheet.csv; prints every check it ran and exits 1 on a miss.
Row status: BUILT = camera/timing data exported from Blender and checked there; LEDGER = source-verified row only (no Blender/animatic yet); UNBUILT/UNTESTED are said plainly."""
import json, os, re, sys, csv

ROOT = os.getcwd()
W = "game/world/"
rows = []
checks = []


def R(id, title, cls, src, entry, present, assets, shots, dialogue, sound, control, exit_, handoff, skip, status="LEDGER", notes="", verify=()):
    rows.append(dict(id=id, title=title, **{"class": cls}, source=src, entry_predicate=entry, present=present, assets=assets, shots=shots,
                     dialogue=dialogue, sound=sound, control_state=control, exit_camera_pose=exit_, handoff=handoff, skip_retry_load=skip,
                     status=status, notes=notes, verify=[list(v) for v in verify]))


def S(name, dur, fov, blocking):
    return dict(shot=name, seconds=dur, frames_24=None if dur is None else round(dur * 24), fov_deg=fov, blocking=blocking)


# ============================================================ CAMPAIGN
R("C01.00", "Before the evening (new intro)", "campaign",
  "game/world/intro_cinematic.gd: VeilIntro.play, _shot, _build_veil_wall, _place_colossus; called from world.gd:_opening",
  "new game AND not Game.has_flag('intro_seen') AND (not headless OR world.force_intro); main_menu.gd:_start goes straight to World.tscn (the old title reel is NOT played)",
  "player (hidden); the living town's Meshy walk-ons; radio; Colossus (tripod, 70 m) in the Veil",
  "Greyhaven_Core/Commercial/Houses; MON_tripod.glb; veil_mist_boundary.gdshader; V.Intro_VeilWall (5 curtains)",
  [S("black + radio static", 4.0, None, "HUD fade alpha 1 from the first frame; the radio breaks a human sentence"),
   S("crane over the town", None, 55, "high sweep, caption GREYHAVEN / Friday 6:40 PM"),
   S("sidewalk dolly", None, 55, "pedestrian height, Meshy townspeople"),
   S("supermarket push-in", None, 55, "lit supermarket"), S("mist at the woods road", None, 55, "wrong note 1"),
   S("game shop stutter", None, 55, "lights stutter, wrong note 2"), S("dog bark / yard", 4.2, 45, "yard, bark at 0.6 s and 1.4 s"),
   S("driveway low + rise", 9.1, 50, "low at the sedan, rise to +24 m, Veil curtains creep 30 m in 8 s; Colossus a silhouette in thick mist, faint eye glow"),
   S("long-lens loom", 5.0, 32, "wall rolls in; colossus_call -1 dB pitch 0.55"), S("title", 3.4, None, "THE VEIL card; then slow fade to black (1.8 s) + 0.5 s hold")],
  [], ["radio static", "hound_bark x2", "MUSIC_COLOSSUS at the rise", "veil_rumble", "colossus_call"],
  "controls off, HUD hidden, hold E / Esc skips (skipped=true)", "black, then world.gd fades in on the bedroom spawn (no bed, no wash after the new intro)",
  "intro_seen set in _end; game continues to C01.01", "skip: any time, 0.2 s measured; load: Continue never plays it (intro_seen)",
  "LEDGER", "Visual framing NOT verified (owner's visual test). intro_trailer_test passes.",
  [(W + "intro_cinematic.gd", "func play"), (W + "intro_cinematic.gd", "func _place_colossus"), (W + "world.gd", "func _opening"), ("game/scenes/main_menu.gd", "change_scene_to_file")])

R("C01.01", "6:42 PM, waking and the drive", "campaign",
  "world.gd:_opening (wake branch), home_bathroom.gd:wash_face, world.gd:enter_car/_arrival_ease",
  "after the intro (new game) or fresh world; intro skipped/seen paths still play the bed wake-up + wash",
  "protagonist only", "PLAYER_HOME (Greyhaven_Houses), Markers/Spawn_WakeUp, fridge note, car keys (pickup 'car_keys'), sedan",
  [S("wake (legacy path)", 4.6, None, "player.play_wake_up(4.6,false); chapter_start(1) + 'FRIDAY - 6:42 PM'"), S("after new intro", 2.0, None, "straight fade-in, no bed/wash"),
   S("keys, front door, car", None, None, "first-person interactions")],
  ["wake", "wake_hint", "keys"], ["fridge_hum", "door_open/close", "step"], "wake: locked until wash_face finishes (legacy); new-intro path: controls on after fade",
  "first person at the bedroom spawn or after wash", "objective from Game.current_goal(); has_keys, fridge_checked, left_house, entered_car",
  "pause disabled until controls return", "LEDGER", "Bathroom hand-washing is its own hook (handwash_test).",
  [(W + "world.gd", "func enter_car"), (W + "home_bathroom.gd", "func wash_face")])

R("C02.01", "One Last Stop - arrival shot and errands", "campaign",
  "world.gd:_arrival_ease/_arrival_shot, _on_market_entered, _checkout, _pay_guard",
  "in_car AND sedan.driven AND not arrival_shot AND not _auto_parking",
  "protagonist, cashier, Eddie (game shop), living-town people", "market sign, Greyhaven_Commercial, sedan, checkout, game shop",
  [S("market sign focus (arrival zoom)", None, None, "the sedan brakes into the sign; exit camera = vehicle camera; exiting the car ends it early")],
  ["town"], ["engine/radio", "door"], "driving; locked during the zoom, released by exit_car",
  "vehicle camera", "arrival_shot, groceries_done, game_bought (either order); pay-before-you-leave (_pay_guard)", "state flags make it once-only; load re-enters without replay", "LEDGER", "",
  [(W + "world.gd", "func _arrival_shot"), (W + "world.gd", "func _checkout"), (W + "world.gd", "func _pay_guard")])

R("C03.01", "Mist arrival", "campaign", "world.gd:_p3_tick -> _p3_start_mist",
  "groceries_done AND game_bought AND not p3_mist; not in car, not _encounter_running, not conversing",
  "protagonist, Eddie, Marcus (placed in the game shop), clerk if inside the market zone", "veil_rumble, night_preset('approach'->'active'), _build_mist_ceiling, _stutter_lights",
  [S("lights stutter, distant horizon goes", 5.0, 72, "atmosphere preset approach for 5 s then active; clerk/Eddie walk to the door; shop door set open")],
  ["p3_fog"], ["veil_rumble", "light stutter"], "player keeps control; Dialogue.say(p3_fog, false, true)", "first person", "p3_mist set; chapter_start(3)", "once-only by p3_mist", "LEDGER", "",
  [(W + "world.gd", "func _p3_start_mist"), (W + "world.gd", "func _p3_tick")])

R("C03.02a", "Colossus encounter - ORIGINAL stomping version", "campaign (legacy path: `-- old_colossus`)",
  "world.gd:_colossus_encounter (dispatch at its first line: VeilMeshyNpcs.tripod_enabled() -> _tripod_encounter instead)",
  "p3_mist AND not p3_stepped_out AND _outdoors() (polled in _p3_tick); sets p3_stepped_out",
  "protagonist (stand-in Protagonist_Cine for the face shot), clerk if out, living town fright, lamp post", "CRT_Colossus.tscn at COLOSSUS_SCALE 6 (~60 m), leg blockers, street lamp (_crush_lamp), VeilCreatureLook.apply_colossus",
  [S("1 call + look at the sound", 1.5, 72, "controls held, EncounterCam = player cam; slerp to L+4 m"), S("held beat", 4.0, 72, "creature hidden; far parts in mist"),
   S("2 the foot comes down from 12 m above onto L", None, 72, "contact frame measured from claw tips; lamp struck on the way down; dust, shake 0.35 s, light flicker < 45 m, clerk flees"),
   S("3 protagonist's face lit, eyes go up", 2.8, 42, "cam 1.05 m in front of his head, key light warm"), S("4 up the leg into the mist", 4.2, 60, "slerp up to +40 m, fov 60->50"),
   S("5 it walks on", 3.6, None, "two distant steps; frozen"), S("6 return to first person", 0.7, None, "ease to player camera, pitch 8 deg")],
  ["p3_colossus (prompt after)", "p3_doors_dead (supermarket)", "p3_eddie_over_here"], ["colossus_call +4/-6 dB", "MUSIC_COLOSSUS", "colossus_step +6 dB pitch 0.7", "hurt (clerk)", "lamp sparks"],
  "controls_enabled=false, allow_pause=false from stage 1 until stage 6", "first-person at yaw toward the leg, pitch 8 deg, fov = player fov",
  "_p3_survival_begins(door_out, shop_door): survival HUD, beacon store_back, tentacles; save()", "no skip; load before p3_stepped_out replays it; after, never",
  "LEDGER", "Where the lamp is broken its final state persists (_crush_lamp). Not retested in this pass.",
  [(W + "world.gd", "func _colossus_encounter"), (W + "world.gd", "func _crush_lamp"), (W + "world.gd", "func _p3_survival_begins")])

R("C03.02b", "Colossus encounter - Meshy tripod (DEFAULT)", "campaign (default path)",
  "world.gd:_tripod_encounter, _enc_mist, _tripod_watch; dispatched from _colossus_encounter when VeilMeshyNpcs.tripod_enabled()",
  "same as C03.02a (p3_mist, not p3_stepped_out, _outdoors())",
  "protagonist, clerk (if _clerk_out: _clerk_beside, _clerk_flees), Eddie (at game shop after), Colossus 85 m",
  "game/prototypes/monsters_meshy/MON_tripod.glb (+tripod_eye.gd searchlight), colossus_veil.gdshader, veil_mist_boundary.gdshader x3 curtains at 34/52/70 m, docs/cinematics/blender/C03_02b_pilot.blend",
  [S("walk-in out of the fog", 13.0, 72, "creature starts 104 m ahead, 14 m left, walks toward you at 1.43 m/s facing you; distance_fade 0.1->0.006, eye level 0.25->1, curtains 0.97->0.5; searchlight scan sweeps -60..+8 m"),
   S("it finds you", 2.2, 72, "turn 2.4 s toward you; light converges on head height 1.5 m"), S("lock-on hold", 0.55, 72, "eye.target=player camera, beam_on, level 1.5; clerk flees"),
   S("jump-scare zoom to the eye", 0.8, "72->7", "colossus_call +14 dB pitch 1.35 at the player + second +10 dB at the eye; curtains to 0.12; rotate to the eye over 0.5 s"),
   S("lens holds the frame", 0.9, 7, "npc fright"), S("snap back to first person", 0.35, "7->72", "yaw toward it, pitch 22 deg; curtains fade 3 s"),
   S("survival begins", None, 72, "GET BACK INSIDE THE STORE / GET TO THE GAME SHOP; _tripod_watch holds the light on you until you are under cover, then it swings away, turns and walks off over 30 s")],
  ["p3_colossus", "p3_doors_dead", "p3_eddie_over_here"], ["colossus_step +5 dB pitch 0.55 each step_interval 5.93 s", "colossus_call jump-scare", "MUSIC_COLOSSUS -6 dB"],
  "controls off + no pause from the start to the snap-back (17.8 s); no camera shake anywhere in this branch", "first person, pitch 22 deg toward the creature, fov restored",
  "_p3_survival_begins; _tripod_watch(tc, wd); enc_report keys: colossus_tripod, locked_on, eye_zoom, tripod_released", "no skip; load before p3_stepped_out replays; _encounter_running guards re-entry",
  "BUILT", "Camera + marker data: data/C03_02b_camera.json (428 frames @24). Round trip: camera forward error 0.000 deg. Eye height measured 43.6 m at H=85. Design conflict: the narrative bible says four legs, the Meshy rig has three (Leg_L, Leg_R, Leg_B).",
  [(W + "world.gd", "func _tripod_encounter"), (W + "world.gd", "func _enc_mist"), (W + "world.gd", "func _tripod_watch"), ("game/enemies/tripod_colossus.gd", "class_name VeilTripodColossus")])

R("C03.03", "Street survival and the failed car", "campaign",
  "world.gd:_p3_survival_begins, _p3_spawn_tentacles, _p3_car_dead, _p3_back_inside",
  "p3_stepped_out AND not p3_back_inside; car interaction any time after p3_mist",
  "protagonist, Eddie (calls from the game shop door), Marcus", "tentacle scenes (monster_scene), sedan, beacon store_back",
  [S("player-led", None, 72, "tentacles emerge with wind-up/contact/recovery; dead sedan = static + one line")],
  ["p3_car_dead", "p3_car_again", "p3_eddie_calls", "p3_hit"], ["static -4 dB at the sedan", "tentacle_hiss", "colossus_call"],
  "player control; hurt = non-lethal", "first person", "p3_back_inside; then p3_in_shop", "_encounter_running guards; load restores the state", "LEDGER",
  "Frank/Skitter (living_town.gd:_frank) can run here: see OPT.FRANK",
  [(W + "world.gd", "func _p3_car_dead"), (W + "world.gd", "func _p3_back_inside"), (W + "world.gd", "func _p3_spawn_tentacles")])

R("C03.04", "Stockroom and two hours later", "campaign",
  "world.gd:_p3_reach_shop, _shop_seated_talk, _shop_regroup (shots F/G)", "p3_back_inside AND not p3_in_shop",
  "protagonist, Eddie, Marcus", "game shop stockroom (SHOP_TALK spots), door gap light",
  [S("F: Eddie calls from the threshold", 2.4, 46, "cam picked by cam_point_ok/sight_ok"), S("G: all go in, Eddie shuts the door", 9.0, 55, "hinge close when clear of the leaf"), S("seated talk", None, None, "away from windows"),
   S("2 HOURS LATER card", None, None, "fade through black, then lights reset")],
  ["p3_eddie_calls", "p3_colossus", "shop talk ids"], ["door_close", "footfalls outside"], "controls_enabled=false during _shop_seated_talk", "stockroom, half-lit exit route", "p3_in_shop; time skip; town_destruction after the skip",
  "no skip documented; load restores p3_in_shop", "LEDGER", "", [(W + "world.gd", "func _shop_seated_talk"), (W + "world.gd", "func _shop_regroup")])

R("C04.01", "Shop exit and Main Street", "campaign", "world.gd:_p3_escape_tentacle, _street_tentacle_to_chase, _p3_flee_together",
  "_p3_shop_talked AND not _p3_npcs_moved AND _outdoors()", "protagonist, Eddie, Marcus", "street tentacle, VEH_ cars, shop signs",
  [S("exit lash", None, 72, "controls held; tentacle -> chase AI recovery")], ["p3_hit"], ["tentacle_hiss", "chase music"], "controls restored to was_controls after the lash", "first person", "p3_fled_together", "_encounter_running guard", "LEDGER", "",
  [(W + "world.gd", "func _p3_escape_tentacle"), (W + "world.gd", "func _p3_flee_together")])

R("C04.02", "The last open door", "campaign", "world.gd:_p3_market_arrival, _arrival_turn_to, _arrival_wait_lines, _market_blackout, _p3_shut_doors",
  "p3_fled_together AND not p3_in_market AND _near_market_entrance() (polled)", "protagonist, Eddie, Marcus", "market doors (dead: forced apart by Eddie), vestibule, checkout lanes",
  [S("doors forced + vestibule", None, 72, "door_open +2 dB pitch 0.55; power drops; pan past dead lanes")], ["market arrival lines"], ["door_open", "blackout"],
  "controls_enabled=false; hold-to-skip via _arrival_skip_held", "request to secure the entrances", "p3_in_market -> p3_doors_shut -> Lock-In", "skip: hold; already-inside path via _p3_reach_market(from_scene)", "LEDGER", "",
  [(W + "world.gd", "func _p3_market_arrival"), (W + "world.gd", "func _market_blackout"), (W + "world.gd", "func _p3_shut_doors")])

R("C05.01", "Lock-In work", "campaign", "game/world/phase4.gd:begin, _throw_breaker, _pull_loading, _close_back, _push_pallet, _make_bed, _open_supplies",
  "p3_doors_shut", "protagonist, Eddie, Marcus", "flashlight, breaker, rear/loading exits, pallets, bedding", [S("first-person physical beats", None, 72, "no cinematic camera")],
  ["flashlight / breaker lines"], ["door/rattle/flicker on the contact frame"], "player control", "first person", "p4_* flags; p4_slept", "state flags + save", "LEDGER",
  "Common rear-door strike: phase4.gd:_door_strike (see C05.02b).", [(W + "phase4.gd", "func _throw_breaker"), (W + "phase4.gd", "func _push_pallet"), (W + "phase4.gd", "func _door_strike")])

R("C05.02a", "Accept the search (Skitter on the roof)", "campaign", "phase4.gd:_on_choices -> _run_threat -> _hound_charge (name historical; the creature is the Skitter), _spawn_roof_skitter, _skitter_run",
  "p4 choice 'accept'", "protagonist, Marcus", "MON_skitter (Meshy) via skitter_scene, roof building, VeilCreatureLook.apply_skitter", [S("step out, roof sighting, focus zoom, run back", None, 72, "creature crouched ~2.5 m back from the roof edge; _fp_face/_fp_track")],
  ["p4_skitter_seen", "p4_skitter_run"], ["breath", "music cue", "impact after the door closes"], "camera held then control returns", "back inside", "p4 night report", "retry via save", "LEDGER",
  "charge_report keys exist for tests.", [(W + "phase4.gd", "func _hound_charge"), (W + "phase4.gd", "func _spawn_roof_skitter"), (W + "phase4.gd", "func _skitter_run")])

R("C05.02b", "Refuse the search (the unseen thing at the rear door)", "campaign", "phase4.gd:_on_choices -> _run_threat, _night_banging, _spawn_hound, _door_strike, _flicker_burst",
  "p4 choice 'refuse'", "all inside", "rear door seam, pallets", [S("banging, long gap, door strike", None, 72, "source never shown")], ["night lines"], ["impact_wave", "scrape", "door strike"], "per code", "indoors", "p4_slept / night report",
  "state flags", "LEDGER", "", [(W + "phase4.gd", "func _night_banging"), (W + "phase4.gd", "func _door_strike")])

from ledger_chapters import BEATS          # displayed chapters 6-16, beat by beat (incl. the three endings)
for (bid, btitle, bsrc, bentry, bshots, bdlg, bsound, bctl, bexit, bnotes, bver) in BEATS:
    built = bid.startswith("C13.0") or bid == "C13.1"
    R(bid, btitle, "campaign", "game/world/" + bsrc if not bsrc.startswith("game/") else bsrc, bentry,
      "alive/present survivors only (alive()/present() helpers); Marcus lines only if he survived; missing speakers use the _alt / @1 and _Sarah/_Ruth/_Marcus conventions",
      "see source functions", [S(n_, d_, f_, bl_) for (n_, d_, f_, bl_) in bshots], bdlg, bsound, bctl, bexit,
      "checkpoint/skip/retry per story pass C7", "load rebuilds from flags (no replay of finished events)",
      "BUILT (code + headless test)" if built else "LEDGER", bnotes, bver)

R("C16.X", "Epilogue and credits", "campaign", "chapter15.gd:epilogue_lines, _finish, _credits, _menu_main, _menu_replay, _menu_load", "after any ending", "roster from real flags", "title, credits, THANK YOU FOR PLAYING", [S("epilogue lines -> title -> credits -> menu", None, None, "text")], ["epilogue_lines()"], ["music"], "none", "menu", "ending history file", "replay = pre-decision save", "LEDGER",
  "Noah is NOT rescued in this snapshot; a rescue needs a story decision before wiring (separate animatic).", [(W + "chapter15.gd", "func epilogue_lines"), (W + "chapter15.gd", "func _credits")])

# ============================================================ OPTIONAL / DEATH / OTHER
R("OPT.ROOF", "Optional roof Skitter (HOUSE_03)", "campaign (optional)", "game/encounters/roof_skitter.gd: setup, eligible, near_porch, _encounter, _escape_plan", "flag egg_roof_skitter_seen not set; after the mist; near the porch", "protagonist", "MON_skitter (Meshy), HOUSE_03 roof, skitter_hiss.wav, the_veil_jumpscare_sting.wav",
  [S("porch sighting, leap/pin, 10-click struggle 4 s, escape", None, 72, "fallback leap across blocked geometry")], [], ["hiss", "sting"], "struggle clicks; explicit handoff", "first person", "SEEN flag", "once", "LEDGER", "roof_skitter_handoff_test exists", [("game/encounters/roof_skitter.gd", "func _encounter")])
R("OPT.FRANK", "Frank and the Skitter", "campaign (optional-looking, runs after the Colossus)", "game/world/living_town.gd:_frank, _retreat_player", "p3_stepped_out AND not lt_frank_done AND outdoors AND p3_mist AND not p3_back_inside", "Frank, Skitter, protagonist", "MON_skitter via monster_scene, CHR_Frank",
  [S("run, hunt, leap onto his chest (legs on the ground), 1.5 s pin, crawl to his side, grip shoulders, drag", None, 72, "controls locked all scene; then the protagonist walks himself to the nearest open door and inside")], ["lt_frank_help", "lt_eddie_frank"], ["ss_rush", "ss_impact", "hurt", "sk_move_loop"],
  "controls off for the whole scene; returned after the retreat", "inside the store door", "lt_frank_done", "once", "LEDGER", "frank_skitter_test passes.", [("game/world/living_town.gd", "func _frank"), ("game/world/living_town.gd", "func _retreat_player")])
R("OPT.STRUGGLE", "First-person monster struggles (hound/skitter/crab)", "campaign (optional, random)", "game/encounters/struggle.gd", "eligible attack, chance 0.35, cooldown 40 s, never in story scenes", "any", "hound/skitter/crab scenes", [S("grab; click to break free", 5.0, None, "view turns to the creature")], [], ["hs_* / ss_* / cs_* banks"], "clicks", "player cam", "no kill", "nothing saved", "LEDGER", "", [("game/encounters/struggle.gd", "const STYLE")])
R("OPT.GARAGE", "Garage tentacle", "campaign (optional)", "game/world/garage_tentacle.gd", "after the breaker, before the loading door is pulled down", "protagonist", "tentacles x3", [S("reveal (camera held), 10 s countdown to pull the door", 10.0, None, "success/failure variants")], [], ["tentacle_hiss"], "held then countdown", "first person", "p4_garage_done", "retry = save at encounter start", "LEDGER", "", [("game/world/garage_tentacle.gd", "func _taken")])
R("DEATH", "Death sequence", "campaign (all deaths)", "game/world/death_sequence.gd: VeilDeathSequence", "player health reaches 0", "player", "Meshy tripod holder (60 m) + 3 hounds", [S("collapse 0-2 s, last view 2-5 s, the town belongs to them 5-8 s, YOU DIED 8-10 s", 9.5, None, "indoors: cut through black to a fixed Main St vignette; nothing spawns inside")], [], ["muffle", "distant calls"], "controls off", "black + panel", "RETRY loads last save", "no flags/saves touched", "LEDGER", "death_test fails identically with old creatures (baseline, not caused by this pass: 'death_stages_false started:true').", [("game/world/death_sequence.gd", "func _spawn_colossus")])
R("PROMO.TRAILER", "Trailer 'The Change'", "promotional (trailer mode)", "game/trailer/trailer_director.gd: _seg_ordinary/_seg_falling/_seg_shape/_seg_run/_seg_survive; --trailer", "launch flag, F12 / T", "Eddie, Marcus, living town", "Greyhaven", [S("7 beats", None, None, "never saves (Game.no_save)")], [], [], "none", "menu", "none", "Esc", "LEDGER", "Shape beat (_seg_shape) now uses the Meshy tripod (42 m, 0.6 speed).", [("game/trailer/trailer_director.gd", "func _seg_shape")])
R("LEGACY.PREVIEW", "Menu 'Watch Preview' reel", "legacy/menu", "game/cinematics/cinematic.gd (mode 'preview')", "menu button only", "none", "CRT_Colossus.glb (old)", [S("7 title cards", 28.0, 68, "staged silhouettes")], [], [], "none", "menu", "none", "skip", "LEDGER", "New Game no longer plays its 'intro' mode.", [("game/cinematics/cinematic.gd", "var mode")])

# ============================================================ verify
ok = True
for r in rows:
    for f, pat in r["verify"]:
        p = os.path.join(ROOT, f)
        hit = os.path.exists(p) and re.search(re.escape(pat), open(p, encoding="utf-8", errors="ignore").read()) is not None
        checks.append((r["id"], f, pat, hit))
        ok = ok and hit
for c in checks:
    print("CHECK %-9s %-4s %s :: %s" % (c[0], "OK" if c[3] else "MISS", c[1], c[2]))

os.makedirs("docs/cinematics/data", exist_ok=True)
os.makedirs("docs/cinematics/audio", exist_ok=True)
json.dump(rows, open("docs/cinematics/data/shots.json", "w"), indent=1)
with open("docs/cinematics/audio/cue_sheet.csv", "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["sequence", "cue", "source_function"])
    for r in rows:
        for c in r["sound"]:
            w.writerow([r["id"], c, r["source"].split(":")[0]])
manifest = {
    "branch": "cinematics/ledger-pilot (off art/meshy-monsters 0aff4cb; nothing merged)",
    "pilot": {"sequence": "C03.02b", "camera_data": "docs/cinematics/data/C03_02b_camera.json", "blend": "docs/cinematics/blender/C03_02b_pilot.blend",
              "hookup": "runtime stays code-driven (world.gd:_tripod_encounter); Blender data is the reference/timing. Markers to compare in a Godot reference scene: lock_on 15.2 s, jump_scare 15.75 s, zoom_end 16.55 s, control_return 17.8 s.",
              "markers": ["step_1 @ 5.93 s", "step_2 @ 11.86 s", "lock_on", "jump_scare", "zoom_end", "control_return"]},
    "entry_points": {"new_game": "MainMenu.tscn -> main_menu.gd:_start -> World.tscn -> world.gd:_opening", "chapter_select": "chapters/chapter_select.gd (dev_chapterN.gd set-ups)", "trailer": "trailer_mode.gd --trailer", "preview": "cinematics/Cinematic.tscn (preview only)"},
    "integration_patch": "none needed for the pilot: the Godot code already runs the sequence; approved sequences would add runtime markers only",
}
json.dump(manifest, open("docs/cinematics/data/hookup_manifest.json", "w"), indent=1)

md = ["# THE VEIL - cinematic shot ledger", "",
      "Branch `cinematics/ledger-pilot` (from `art/meshy-monsters` @ 0aff4cb; nothing merged). Generated by `docs/cinematics/tools/build_ledger.py`, which checks every cited function/flag exists (%d checks, %s)." % (len(checks), "all OK" if ok else "MISSES"),
      "Status: **BUILT** = Blender camera/timing data exported + round-trip checked; **LEDGER** = source-verified row, no Blender/animatic yet (unbuilt). Nothing here is visually verified: owner's visual test only. No renders or videos are produced (project rule).", "",
      "| ID | Title | Class | Status | Entry predicate | Control |", "|---|---|---|---|---|---|"]
for r in rows:
    md.append("| %s | %s | %s | %s | %s | %s |" % (r["id"], r["title"], r["class"], r["status"], r["entry_predicate"].replace("|", "/")[:150], r["control_state"].replace("|", "/")[:90]))
md.append("")
for r in rows:
    md += ["## %s - %s" % (r["id"], r["title"]), "", "- **Class:** %s   **Status:** %s" % (r["class"], r["status"]), "- **Source:** %s" % r["source"], "- **Entry:** %s" % r["entry_predicate"],
           "- **Present:** %s" % r["present"], "- **Assets:** %s" % r["assets"], "- **Dialogue:** %s" % (", ".join(r["dialogue"]) or "-"), "- **Sound:** %s" % (", ".join(r["sound"]) or "-"),
           "- **Control:** %s" % r["control_state"], "- **Exit camera/pose:** %s" % r["exit_camera_pose"], "- **Handoff:** %s" % r["handoff"], "- **Skip/retry/load:** %s" % r["skip_retry_load"]]
    if r["notes"]:
        md.append("- **Notes:** %s" % r["notes"])
    md += ["", "| Shot | s | frames@24 | FOV | Blocking / action |", "|---|---|---|---|---|"]
    for s in r["shots"]:
        md.append("| %s | %s | %s | %s | %s |" % (s["shot"], s["seconds"] if s["seconds"] is not None else "?", s["frames_24"] if s["frames_24"] is not None else "?", s["fov_deg"] if s["fov_deg"] is not None else "-", s["blocking"]))
    md.append("")
open("docs/cinematics/SHOT_LEDGER.md", "w", encoding="utf-8").write("\n".join(md))
print("ROWS", len(rows), "CHECKS", len(checks), "OK" if ok else "MISSES")
sys.exit(0 if ok else 1)
