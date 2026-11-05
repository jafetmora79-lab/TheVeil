extends Node
class_name VeilGoldenPeek
## THE VEIL - a hidden, optional Easter egg (not part of the story). Isolated: world.gd only adds this node.
##
## In the woods before Greyhaven (on foot, off the driving route, before the town arrival), after 60 s of cumulative
## wandering, a golden face peeks out from behind a tree 20+ m away, roughly where the player is already looking (it
## is placed only while that spot is out of view). Only its nose, mouth and buck teeth show. Within 10 m: control is
## held, the view snaps to it, it launches at the camera (0.2 s), the supplied sound starts at impact (its first 3 s
## only), its picture fills the screen and fades into white (0.8 s), the white holds briefly and clears (~1.3 s in
## all). Control comes back, nothing else changes (no damage, no items, no story, no position change); once the
## sound has finished, the protagonist mutters one line (a subtitle). Once per playthrough (flags in the save).
## If the player walks away first, it slips back behind the tree once nobody is looking.

const PEEK_TEX := preload("res://game/easter_egg/golden_peek.png")
const SIDE_TEX := preload("res://game/easter_egg/golden_side.png")
const SCARE := preload("res://game/easter_egg/golden_scare.ogg")
const WORLD_DATA := "res://game/world/world_data.json"
const NEED_S := 60.0
const TRIGGER_M := 10.0
const LUNGE_S := 0.2
const FLASH_IN_S := 0.8
const HOLD_S := 0.12
const FLASH_OUT_S := 0.38
const LINE_ID := "egg_golden_reaction"

var world: Node
var route: Array = []
var peek: Sprite3D
var report := {"woods_time": 0.0, "placed": false, "triggered": false, "lunge_s": 0.0, "flash_s": 0.0, "audio_at_impact": false,
	"line_at": -1.0, "audio_end": -1.0, "withdrawn": 0}
var _tick := 0.0
var _running := false
var _away_t := 0.0
var _audio: AudioStreamPlayer
var _layer: CanvasLayer
var _clock := 0.0                                      ## game time (the scare is timed on it)


func setup(w: Node) -> void:
	world = w
	var f := FileAccess.open(WORLD_DATA, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary:
		for p in d.get("route", []):
			route.append(Vector2(float(p[0]), float(p[1])))
	if not Dialogue.data.has(LINE_ID):
		Dialogue.data[LINE_ID] = {"source": "Easter egg (implementation)", "lines": [
			{"speaker": "", "text": "Damn... I really gotta stop eating gas station gummies. I should just get back to my car.", "time": 4.2}]}


func st() -> Dictionary:
	if not Game.world_state.has("easter_egg"):
		Game.world_state["easter_egg"] = {"woods_time": 0.0}
	return Game.world_state["easter_egg"]


func done() -> bool:
	return Game.has_flag("egg_golden_seen")


## The opening only: on foot, before the town (the arrival shot / the town core), not in a cinematic.
func _in_opening() -> bool:
	if Game.has_flag("arrival_shot") or Game.has_flag("reached_town") or Game.has_flag("p3_mist"):
		return false
	var p = world.player
	return (p != null and p.visible and p.controls_enabled and not world.in_car and not world.conversing
		and not (world.get("_cine") and is_instance_valid(world.get("_cine"))))


func route_distance(p: Vector3) -> float:
	var best := INF
	var q := Vector2(p.x, p.z)
	for i in route.size() - 1:
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * t))
	return best


## Trees (their trunk collision) around a point: [{"pos": trunk centre at ground, "r": trunk radius}]
func trees_near(at: Vector3, radius: float) -> Array:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	q.shape = sh
	q.transform = Transform3D(Basis(), at + Vector3(0, 1.0, 0))
	q.collision_mask = 1
	var out := []
	for r in space.intersect_shape(q, 64):
		var body := r["collider"] as CollisionObject3D
		if body == null or not String(body.name).begins_with("VG_Tree"):
			continue
		var owner := body.shape_find_owner(int(r["shape"]))
		var xf: Transform3D = body.global_transform * body.shape_owner_get_transform(owner)
		var s := body.shape_owner_get_shape(owner, 0)
		var rad := 0.3
		if s is CylinderShape3D:
			rad = (s as CylinderShape3D).radius
		elif s is CapsuleShape3D:
			rad = (s as CapsuleShape3D).radius
		out.append({"pos": Vector3(xf.origin.x, at.y, xf.origin.z), "r": rad})
	return out


func in_woods(p: Vector3) -> bool:
	return trees_near(p, 14.0).size() >= 3 and route_distance(p) > 8.0


func _process(delta: float) -> void:
	_clock += delta
	if world == null or done() or _running:
		return
	if peek != null:
		_watch_peek(delta)
		return
	if not _in_opening():
		return
	var p: Vector3 = world.player.global_position
	if not in_woods(p):
		return
	st()["woods_time"] = float(st().get("woods_time", 0.0)) + delta
	report["woods_time"] = st()["woods_time"]
	_tick -= delta
	if float(st()["woods_time"]) >= NEED_S and _tick <= 0.0:
		_tick = 0.5
		_try_place()


## A tree 20-45 m away, roughly ahead of the player (so it is naturally seen), with a clear line of sight to its
## side - and the spot itself out of the camera's view at the moment of placing (no pop-in in plain sight).
func _try_place() -> void:
	if done() or peek != null:
		return
	var cam: Camera3D = world.player.camera
	var p: Vector3 = world.player.global_position
	var fwd := -cam.global_transform.basis.z * Vector3(1, 0, 1)
	fwd = fwd.normalized()
	var best: Dictionary = {}
	var best_score := -INF
	for t in trees_near(p, 45.0):
		var tp: Vector3 = t["pos"]
		var d := Vector2(tp.x - p.x, tp.z - p.z).length()
		if d < 20.0 or d > 45.0:
			continue
		var dir := (tp - p) * Vector3(1, 0, 1)
		var ang := fwd.dot(dir.normalized())
		if ang < 0.2:                                  # roughly ahead (within ~78 degrees), where the player looks
			continue
		var side: Vector3 = dir.normalized().cross(Vector3.UP).normalized()
		var at: Vector3 = _peek_spot(tp, float(t["r"]), side, p)
		if not _clear_view(cam.global_position, at):
			continue
		if cam.is_position_in_frustum(at):             # never appear while being looked at
			continue
		var score := ang - absf(d - 28.0) * 0.02
		if score > best_score:
			best_score = score
			best = {"tree": tp, "r": t["r"], "side": side, "at": at}
	if best.is_empty():
		return
	peek = Sprite3D.new()
	peek.name = "GoldenPeek"
	peek.texture = PEEK_TEX
	peek.pixel_size = 0.0036
	peek.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	peek.shaded = true
	peek.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	peek.modulate = Color(0.78, 0.74, 0.62)
	peek.flip_h = false
	world.add_child(peek)
	peek.global_position = best["at"]
	peek.set_meta("tree", best["tree"])
	peek.set_meta("side", best["side"])
	report["placed"] = true
	report["tree"] = best["tree"]
	report["tree_distance"] = Vector2(best["tree"].x - p.x, best["tree"].z - p.z).length()


## Behind the trunk (seen from the player), shifted to one side so the cheek stays hidden and only the nose, lips
## and teeth come out past the bark. The picture's nose points right: it peeks out on the trunk's right.
func _peek_spot(tree: Vector3, r: float, side: Vector3, from: Vector3) -> Vector3:
	var away := (tree - from) * Vector3(1, 0, 1)
	away = away.normalized()
	var right := -side                                 # the player's right when facing the tree
	return tree + away * (r + 0.12) + right * (r + 0.05) + Vector3(0, 1.62, 0)


func _clear_view(eye: Vector3, at: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, at + (eye - at).normalized() * 1.2, 1, [world.player.get_rid()])
	return space.intersect_ray(q).is_empty()


## While it waits: the 10 m trigger; or, if the player leaves, it withdraws behind the tree when unseen.
func _watch_peek(delta: float) -> void:
	var p: Vector3 = world.player.global_position
	var tree: Vector3 = peek.get_meta("tree")
	var d := Vector2(tree.x - p.x, tree.z - p.z).length()
	if d <= TRIGGER_M and _in_opening():
		_scare()
		return
	var cam: Camera3D = world.player.camera
	var seen := cam.is_position_in_frustum(peek.global_position)
	if d > 60.0 or not _in_opening():
		_away_t += delta
		if _away_t > 2.0 and not seen:
			peek.queue_free()                          # quietly gone behind the tree
			peek = null
			report["withdrawn"] += 1
			_away_t = 0.0
	else:
		_away_t = 0.0


func _scare() -> void:
	_running = true
	report["triggered"] = true
	Game.set_flag("egg_golden_seen")                   # once per playthrough (saved)
	var player = world.player
	var cam: Camera3D = player.camera
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	var keep_pos: Vector3 = player.global_position
	# the view snaps toward it (fast)
	var eye := cam.global_position
	var v := (peek.global_position - eye).normalized()
	var yaw1 := atan2(-v.x, -v.z)
	var pitch1 := asin(clampf(v.y, -1.0, 1.0))
	var yaw0: float = player.rotation.y
	var pitch0: float = cam.rotation.x
	var t := 0.0
	while t < 0.18:
		t += get_process_delta_time()
		var k := smoothstep(0.0, 1.0, minf(t / 0.18, 1.0))
		player.set_yaw_pitch(lerp_angle(yaw0, yaw1, k), lerpf(pitch0, pitch1, k))
		await get_tree().process_frame
	player.set_yaw_pitch(yaw1, pitch1)
	# the lunge: the whole figure, out from behind the trunk and straight into the lens
	peek.texture = SIDE_TEX
	peek.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	peek.shaded = false
	peek.modulate = Color(1, 1, 1)
	peek.pixel_size = 0.0028
	var from := peek.global_position + Vector3(0, -0.6, 0)
	var to := cam.global_position - cam.global_transform.basis.z * 0.35
	var t0 := _clock
	t = 0.0
	while t < LUNGE_S:
		t += get_process_delta_time()
		var k := minf(t / LUNGE_S, 1.0)
		var e := k * k * k                             # accelerating: it attacks the camera
		peek.global_position = from.lerp(to, e)
		peek.pixel_size = lerpf(0.0028, 0.0011, e)
		await get_tree().process_frame
	report["lunge_s"] = _clock - t0
	# impact: the sound starts now; its picture fills the screen and fades into white
	_audio = AudioStreamPlayer.new()
	_audio.stream = SCARE
	_audio.volume_db = -3.0
	add_child(_audio)
	_audio.play()
	report["audio_at_impact"] = _audio.playing
	var impact := _clock
	peek.queue_free()
	peek = null
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	var img := TextureRect.new()
	img.texture = SIDE_TEX
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(img)
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(white)
	var tw := create_tween()
	tw.tween_property(white, "color:a", 1.0, FLASH_IN_S)
	tw.parallel().tween_property(img, "modulate:a", 0.0, FLASH_IN_S)
	tw.tween_interval(HOLD_S)
	tw.tween_property(white, "color:a", 0.0, FLASH_OUT_S)
	await tw.finished
	report["flash_s"] = _clock - impact
	_layer.queue_free()
	# gameplay back exactly as it was (same place; nothing taken, nothing hurt)
	player.global_position = keep_pos
	player.controls_enabled = true
	# the line: once the sound is over (never on top of it), as a subtitle; the player can move meanwhile
	while _clock - impact < SCARE.get_length():
		await get_tree().process_frame
	report["audio_end"] = _clock - impact
	_audio.queue_free()
	await get_tree().create_timer(0.4).timeout
	if not Game.has_flag("egg_golden_reaction"):
		Game.set_flag("egg_golden_reaction")
		report["line_at"] = _clock - impact
		Dialogue.say(LINE_ID, false, true)
	_running = false
