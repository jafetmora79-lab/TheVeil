extends SceneTree
## The creature movement pass (Hound, Skitter, Shellcrawler, the three mist tentacles, the tripod Colossus), headless:
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/creature_anim_test.gd
## Every clip the game plays exists with its old length; the travel speeds the AI matches playback to are unchanged; looping clips close their seam (no pop when they
## wrap; the old tentacle Search seam was 0.099 rad, now 0.040); one-shots end on the pose the next clip starts from (Detect -> Alert, Coil -> Strike); the strike reach (what the tentacle AI derives its damage range from)
## is within 8 % of what it was.
const MM := "res://game/prototypes/monsters_meshy/"
var fails := 0


func check(n: String, ok: bool, info := "") -> void:
	print("  %s %s %s" % ["ok  " if ok else "FAIL", n, info])
	if not ok:
		fails += 1


func _initialize() -> void:
	call_deferred("_run")


func _model(path: String) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(n)
	return n


func _pose(ap: AnimationPlayer, sk: Skeleton3D, clip: String, t: float) -> Array:
	ap.play(clip)
	ap.seek(t, true)
	ap.advance(0.0)
	sk.force_update_all_bone_transforms()
	var out := []
	for i in sk.get_bone_count():
		out.append([sk.get_bone_pose_rotation(i), sk.get_bone_pose_position(i)])
	return out


func _diff(a: Array, b: Array) -> Array:
	var rot := 0.0
	var pos := 0.0
	for i in a.size():
		rot = maxf(rot, (a[i][0] as Quaternion).angle_to(b[i][0]))
		pos = maxf(pos, (a[i][1] as Vector3).distance_to(b[i][1]))
	return [rot, pos]


func _seam(who: String, ap: AnimationPlayer, sk: Skeleton3D, clip: String, tol_rot := 0.05) -> void:
	var len := ap.get_animation(clip).length
	var d := _diff(_pose(ap, sk, clip, 0.0), _pose(ap, sk, clip, len))
	check("%s %s loops without a pop (seam %.3f rad, %.1f mm)" % [who, clip, d[0], d[1] * 1000.0], d[0] < tol_rot and d[1] < 0.01)


func _run() -> void:
	# ---------------------------------------------------------------- clip lists and lengths (seconds)
	var want := {
		"MON_hound.tscn": {"Idle": 4.17, "Walk": 0.37, "Run": 0.37, "Alert": 1.2, "Sniff": 4.17, "Detect": 1.2, "Attack_Bite": 0.43, "Hit_React": 0.43, "Death": 4.17},     # (the Meshy dog's own four clips: game/prototypes/monsters_meshy/hound_clips.gd)
		"MON_skitter.tscn": {"Idle_Twitch": 4.0, "Crawl": 2.42, "Scuttle_Fast": 0.42, "Alert": 2.0, "Attack_Lunge": 0.63, "Hit_React": 0.5, "Death": 1.5},
		"MON_crab.tscn": {"Idle": 4.0, "Crawl_Sideways": 1.0, "Crawl_Forward": 1.0, "Defend": 1.5, "Attack_Grasp": 1.08, "Hit_React": 0.5, "Death": 2.0},
		"MON_tentacle_thin.tscn": {"Emerge": 2.0, "Search": 4.0, "Coil": 1.5, "Reach": 1.5, "Strike": 1.0, "Retract": 1.5},
		"MON_tentacle_medium.tscn": {"Emerge": 2.0, "Search": 4.0, "Coil": 1.5, "Reach": 1.5, "Strike": 1.0, "Retract": 1.5},
		"MON_tentacle_large.tscn": {"Emerge": 2.0, "Search": 4.0, "Coil": 1.5, "Reach": 1.5, "Strike": 1.0, "Retract": 1.5},
		"MON_tripod.glb": {"Idle": 5.0, "Walk_Heavy": 8.0},
	}
	var models := {}
	for scn in want:
		var m := _model(MM + scn)
		await process_frame
		var aps := m.find_children("*", "AnimationPlayer", true, false)
		var sks := m.find_children("*", "Skeleton3D", true, false)
		check(scn + " has an AnimationPlayer and a skeleton", not aps.is_empty() and not sks.is_empty())
		if aps.is_empty() or sks.is_empty():
			continue
		var ap := aps[0] as AnimationPlayer
		models[scn] = [ap, sks[0]]
		for clip in want[scn]:
			var has := ap.has_animation(clip)
			var ln := ap.get_animation(clip).length if has else 0.0
			check("%s clip %s (%.2f s, expected %.2f)" % [scn, clip, ln, want[scn][clip]], has and absf(ln - float(want[scn][clip])) < 0.06)
	# ---------------------------------------------------------------- the speeds the AI and the scenes match the clips to
	var speeds := {"hound.json": {"walk_speed_mps": 6.82, "run_speed_mps": 6.82}, "skitter.json": {"crawl_speed_mps": 0.472, "scuttle_speed_mps": 2.588},
		"crab.json": {"crawl_sideways_speed_mps": 0.5, "crawl_forward_speed_mps": 0.367}, "tripod.json": {"walk_ground_speed": 0.45, "walk_cycle_s": 8.0}}
	for f in speeds:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MM + f))
		for k in speeds[f]:
			check("%s %s unchanged (%s)" % [f, k, str(d.get(k))], d is Dictionary and absf(float(d.get(k, -1.0)) - float(speeds[f][k])) < 0.002)
	# ---------------------------------------------------------------- seams of the looping clips
	var loops := {"MON_hound.tscn": ["Idle", "Walk", "Run", "Alert", "Sniff"], "MON_skitter.tscn": ["Idle_Twitch", "Crawl", "Scuttle_Fast", "Alert"],
		"MON_crab.tscn": ["Idle", "Crawl_Sideways", "Crawl_Forward"], "MON_tentacle_thin.tscn": ["Search"], "MON_tentacle_medium.tscn": ["Search"],
		"MON_tentacle_large.tscn": ["Search"], "MON_tripod.glb": ["Idle", "Walk_Heavy"]}
	for scn in loops:
		if not models.has(scn):
			continue
		for clip in loops[scn]:
			_seam(scn, models[scn][0], models[scn][1], clip)
	# ---------------------------------------------------------------- one-shots that hand over to the next clip
	var h: Array = models["MON_hound.tscn"]
	var d1 := _diff(_pose(h[0], h[1], "Detect", (h[0] as AnimationPlayer).get_animation("Detect").length), _pose(h[0], h[1], "Alert", 0.0))
	check("hound Detect ends on the Alert pose (%.3f rad, %.1f mm)" % [d1[0], d1[1] * 1000.0], d1[0] < 0.05 and d1[1] < 0.015)
	for scn in ["MON_tentacle_thin.tscn", "MON_tentacle_medium.tscn", "MON_tentacle_large.tscn"]:
		var t: Array = models[scn]
		var d2 := _diff(_pose(t[0], t[1], "Coil", (t[0] as AnimationPlayer).get_animation("Coil").length), _pose(t[0], t[1], "Strike", 0.0))
		check("%s Strike starts on the Coil's loaded pose (%.3f rad)" % [scn, d2[0]], d2[0] < 0.08)
	# ---------------------------------------------------------------- the tentacle strike's reach (the AI measures its damage range from it)
	var old := {"MON_tentacle_thin.tscn": 1.751, "MON_tentacle_medium.tscn": 2.678, "MON_tentacle_large.tscn": 3.744}      # measured the same way (T_10 bone origin) on the previous clips
	for scn in old:
		var t: Array = models[scn]
		var sk: Skeleton3D = t[1]
		var tip := sk.find_bone("T_10")
		var best := 0.0
		var best_t := 0.0
		var ln := (t[0] as AnimationPlayer).get_animation("Strike").length
		var x := 0.0
		while x <= ln:
			_pose(t[0], sk, "Strike", x)
			var p := sk.get_bone_global_pose(tip).origin
			var hz := Vector2(p.x, p.z).length()
			if hz > best:
				best = hz
				best_t = x
			x += ln / 48.0
		check("%s strike reach %.2f m (was %.2f), contact at %.2f s" % [scn, best, float(old[scn]), best_t], absf(best - float(old[scn])) / float(old[scn]) < 0.08 and best_t > 0.4 and best_t < 0.75)
	print("RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
