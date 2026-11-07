extends Node
class_name VeilStruggle
## THE VEIL - first-person monster struggles (one shared controller for three creatures).
## A creature AI (game/enemies/hound_ai.gd) offers an attack through on_attack; now and then (cooldown, chance,
## never in story scenes, menus, the car, or when the player is badly hurt) the attack becomes a struggle instead:
##   hound   - it has the player's leg: the view drops to it, LEFT CLICK repeatedly to push it away
##   skitter - it leaps onto the player's chest: close to the camera, LEFT CLICK to throw it off
##   crab    - its claws catch the player and pull them in: LEFT CLICK to break the grip
## The view turns to the creature where it stands. Success: Hound - pushed off, it shakes its head, steps back, hunts
## again; Skitter - thrown down, it lands, hisses, runs; Crab - the claw lets go, it backs off, recovers, hunts again -
## a moment to run, never a kill. Failure: extra damage (never a killing blow here), then the same
## release. Movement and look always come back; nothing of it is saved (a load simply never resumes one).

const SCREECH := "res://game/encounters/skitter_hiss.wav"   ## the approved Skitter screech, as it is
## "start" / "win": [seconds from that moment, sound]; a sound is a bank id (Sfx.bank) or a full res:// path.
const STYLE := {
	"hound": {"title": "THE HOUND HAS YOUR LEG!", "hint": "[LEFT CLICK REPEATEDLY]  PUSH IT AWAY", "time": 5.0,
		"start": [[0.0, "hs_lunge"], [0.28, "hs_impact"], [0.4, "hs_grip"]], "hold": "hs_hold",
		"win": [[0.0, "hs_pushed"], [0.0, "pl_push"], [0.15, "hs_yelp"], [0.7, "hs_shake"]],
		"damage": 22.0, "recover": 3.0, "anim": "Attack_Bite", "react": "Hit_React", "reach": 1.35, "pitch": -1.0},
	"skitter": {"title": "GET IT OFF!", "hint": "[LEFT CLICK REPEATEDLY]  THROW THE SKITTER", "time": 4.5,
		"start": [[0.0, SCREECH], [0.0, "ss_rush"], [0.3, "ss_impact"]], "hold": "ss_hold",
		"win": [[0.0, "ss_thrown"], [0.0, "pl_push"]],
		"damage": 16.0, "recover": 3.2, "anim": "Attack_Lunge", "react": "Hit_React", "reach": 0.4, "pitch": -0.18},
	"crab": {"title": "BREAK FREE!", "hint": "CLICK REPEATEDLY — BREAK FREE", "time": 5.5,
		"start": [[0.0, "cs_snap"], [0.2, "cs_grab"]], "hold": "cs_hold",
		"win": [[0.0, "cs_forced"], [0.0, "pl_escape"], [0.35, "cs_release"], [0.6, "cs_back"]],
		"damage": 28.0, "recover": 3.0, "anim": "Attack_Grasp", "react": "Defend", "reach": 1.7, "pitch": -0.8},
}
const CHANCE := 0.35            ## of an eligible attack
const COOLDOWN := 40.0          ## seconds between struggles (any creature)
const FORCED_COOLDOWN := 9.0    ## a creature that always grabs: this long after the last struggle
const PER_CLICK := 0.085        ## ~12 clicks in the allowed time; held buttons count once
const DECAY := 0.10             ## per second
const INTRO := 0.32             ## the creature closes the last stretch; nothing jumps into place
const GRASP_FREEZE := 0.55      ## the Crab's claws stay shut at this point of Attack_Grasp

var world: Node
var player: Node3D
var active := false
var _cool := 20.0
var _ai: Node = null
var _kind := ""
var _prog := 0.0
var _t := 0.0
var _ui: CanvasLayer
var _bar: ColorRect
var _title: Label
var _hint: Label
var _loop: AudioStreamPlayer
var _grip: AudioStreamPlayer
var _dir := Vector3.FORWARD     ## from the player to the creature, on the ground; the view turns to it
var _yaw := 0.0
var _reach := 1.0               ## how far from the player the creature's origin ends up (walls respected)
var _from := Vector3.ZERO
var _age := 0.0
var _frozen := false
var _seq := 0                   ## sounds still queued from an earlier moment are dropped when this moves on
var _effort_t := 0.0
var _hiss_t := 1.0
var _relax := 0.0
var _since := 999.0               ## seconds since the last struggle ended


func setup(w: Node) -> void:
	world = w
	player = w.player
	_build_ui()


func _exit_tree() -> void:
	if active:
		Sfx.struggle_end(false)                   # a scene change mid-struggle: nothing keeps playing


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	_since += delta
	if _relax > 0.0:
		_relax -= delta
		_aim(player.rotation.y, 0.0, delta * 2.0)
		if _relax <= 0.0:
			player.set("controls_enabled", true)
			player.set("look_enabled", true)
	if not active:
		return
	if _ai == null or not is_instance_valid(_ai) or not is_instance_valid(_ai.body) or player.get("health") <= 0.0:
		_finish(false, true)                       # the creature is gone or the player died: let go cleanly
		return
	_t -= delta
	_age += delta
	_effort_t -= delta
	_prog = maxf(_prog - DECAY * delta, 0.0)
	_bar.size.x = 260.0 * _prog
	_loop.pitch_scale = lerpf(1.0, 1.06, _prog)
	if _kind == "skitter":
		_hiss_t -= delta
		if _hiss_t <= 0.0:
			_hiss_t = randf_range(0.9, 1.7)
			_one("ss_hiss", -4.0)
	_pose(delta)
	if _prog >= 1.0:
		_finish(true)
	elif _t <= 0.0:
		_finish(false)


func _input(e: InputEvent) -> void:
	if active and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_prog = minf(_prog + PER_CLICK, 1.0)          # a press, never a held button (no echo for mouse buttons)
		if _effort_t <= 0.0:
			_effort_t = 0.22
			_one("pl_effort", -6.0)
		get_viewport().set_input_as_handled()


## Called by the creature AI at the moment it would bite. True = this attack is a struggle now.
func try_start(ai: Node) -> bool:
	var forced := bool(ai.get_meta("struggle_force", false))   # (the car-part guard: a grab is always a struggle)
	if active or get_tree().paused or ((_since < FORCED_COOLDOWN) if forced else (_cool > 0.0)) or (not forced and randf() > CHANCE):
		return false
	var kind := String(ai.get_meta("struggle_kind", ""))
	if not STYLE.has(kind) or not _player_free() or float(player.get("health")) < 30.0:
		return false
	active = true
	_ai = ai
	_kind = kind
	_prog = 0.0
	_age = 0.0
	_frozen = false
	_relax = 0.0
	_seq += 1
	_t = float(STYLE[kind]["time"])
	ai.hold = true
	ai.body.velocity = Vector3.ZERO
	ai.voice.quiet()
	player.set("controls_enabled", false)
	player.set("look_enabled", false)
	player.set("velocity", Vector3.ZERO)
	# the view turns to the creature where it is: nothing is moved round to the front of the camera
	var to: Vector3 = (ai.body.global_position - player.global_position) * Vector3(1, 0, 1)
	_dir = to.normalized() if to.length() > 0.05 else -player.global_transform.basis.z
	_yaw = atan2(-_dir.x, -_dir.z)
	_from = ai.body.global_position
	_reach = _clear(_dir, float(STYLE[kind]["reach"]), ai.body)
	_title.text = String(STYLE[kind]["title"])
	_hint.text = String(STYLE[kind]["hint"])
	_ui.visible = true
	_anim(ai, String(STYLE[kind]["anim"]), true)
	ai.body.collision_layer = 0                  # held against the player: it must not shove them anywhere
	_queue(STYLE[kind]["start"], -2.0)
	_loop.stream = Sfx.bank(String(STYLE[kind]["hold"]))
	_loop.pitch_scale = 1.0
	_loop.play()
	_grip.stream = Sfx.bank("pl_grip")
	_grip.play()
	Sfx.struggle_begin()
	_shake(0.35)
	return true


## Nothing else may be happening: no story camera, conversation, car, menu or locked control.
func _player_free() -> bool:
	if world.get("in_car") or world.get("conversing") or world.get("_encounter_running"):
		return false
	var cine = world.get("_cine")
	if cine and is_instance_valid(cine):
		return false
	if world.hud.is_paused() or world.hud.inv_panel.visible or Dialogue.is_busy():
		return false
	return bool(player.get("controls_enabled")) and player.visible


## Free ground from the player towards dir, up to want: a wall behind the creature keeps it (and its contact) clear.
func _clear(dir: Vector3, want: float, body: Node3D) -> float:
	var from := player.global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (want + 0.7), 1, [player.get_rid(), (body as CollisionObject3D).get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return want
	return clampf(from.distance_to(hit["position"]) - 0.7, minf(0.35, want), want)


## Each frame: the creature brought to its hold on the player, the view turned and aimed at it. The camera only turns,
## it stays at eye height inside the player's capsule, so it cannot go through a floor or a wall.
func _pose(delta: float) -> void:
	var body: Node3D = _ai.body
	var cam: Camera3D = player.get("camera")
	var fwd := _dir
	var k := minf(_age / INTRO, 1.0)
	var face := atan2(-fwd.x, -fwd.z)
	match _kind:
		"hound":
			# jaws on the lower leg: the body in front, head down at the shin; the view drops to it
			var want := player.global_position + fwd * _reach
			want.y = body.global_position.y
			body.global_position = _from.lerp(want, k) if k < 1.0 else want
			body.global_position.y = want.y
			body.rotation.y = face + sin(Time.get_ticks_msec() * 0.018) * 0.12   # head shaking
		"skitter":
			# the leap ends on the chest, face to face: legs round the view, tilted up, shaking
			var at := cam.global_position + fwd * _reach + Vector3(0, -0.5, 0)
			if k < 1.0:
				body.global_position = _from.lerp(at, k) + Vector3.UP * sin(PI * k) * 0.3
				body.rotation = Vector3(-1.05 * k, face, 0)
			else:
				body.global_position = at + Vector3(randf_range(-0.015, 0.015), randf_range(-0.015, 0.015), 0)
				body.rotation = Vector3(-1.05, face, sin(Time.get_ticks_msec() * 0.03) * 0.15)
		"crab":
			# the claw reaches the player and shuts on them: the shell stays at arm's length
			var want2 := player.global_position + fwd * _reach
			want2.y = body.global_position.y
			body.global_position = _from.lerp(want2, k) if k < 1.0 else want2
			body.global_position.y = want2.y
			body.rotation.y = lerp_angle(body.rotation.y, face, minf(delta * 8.0, 1.0))
			var ap: AnimationPlayer = _ai.anim
			if ap and not _frozen and ap.current_animation != "" and ap.current_animation_position >= ap.current_animation_length * GRASP_FREEZE:
				_frozen = true
				ap.speed_scale = 0.0
	_aim(_yaw, float(STYLE[_kind]["pitch"]), delta)


func _aim(yaw: float, pitch: float, delta: float) -> void:
	var head := player.get("head") as Node3D
	var p0 := head.rotation.x if head else 0.0
	var k := minf(delta * 7.0, 1.0)
	player.set_yaw_pitch(lerp_angle(player.rotation.y, yaw, k), lerpf(p0, pitch, k))


func _finish(won: bool, cancelled := false) -> void:
	active = false
	_cool = COOLDOWN + randf_range(0.0, 20.0)
	_since = 0.0
	_ui.visible = false
	_loop.stop()
	_grip.stop()
	_seq += 1
	Sfx.struggle_end(won and not cancelled)
	var kind := _kind
	var st: Dictionary = STYLE.get(kind, {})
	var ai := _ai
	_ai = null
	_kind = ""
	if not won and not cancelled and float(player.get("health")) > 0.0:
		# never a killing blow here: the existing damage / death rules are left to the ordinary attacks
		var hp := float(player.get("health"))
		player.damage(minf(float(st.get("damage", 15.0)), maxf(hp - 5.0, 0.0)), ai.body.global_position if ai and is_instance_valid(ai) else player.global_position)
		_one("pl_grunt", -4.0)
	if ai and is_instance_valid(ai) and is_instance_valid(ai.body):
		_unloop(ai, String(st.get("anim", "")))
		if won:
			_queue(st.get("win", []), 0.0)
		if kind == "skitter":
			_throw(ai, st, won)
		else:
			_release(ai, st, won)
	if cancelled:
		player.set("controls_enabled", true)
		player.set("look_enabled", true)
		player.set_yaw_pitch(player.rotation.y, 0.0)
	else:
		_relax = 0.3                              # the view comes back level, then control


## Hound, Crab: it lets go and is shoved / backs a step (a short move, no jump), then the AI takes it through
## shaking it off, stepping back and hunting again.
func _release(ai: Node, st: Dictionary, won: bool) -> void:
	var body: Node3D = ai.body
	var push := _clear(_dir, _reach + (0.7 if won else 0.35), body)
	var tw := body.create_tween()
	var to := player.global_position + _dir * maxf(push, _reach)
	to.y = body.global_position.y
	tw.tween_property(body, "global_position", to, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim(ai, String(st.get("react", "Hit_React")), false)
	await tw.finished
	if not is_instance_valid(ai) or not is_instance_valid(body):
		return
	body.collision_layer = 1
	ai.recoil(float(st.get("recover", 2.5)) * (1.0 if won else 0.7), "back")


## Skitter: thrown down in an arc, it lands on its feet, hisses, then runs.
func _throw(ai: Node, st: Dictionary, won: bool) -> void:
	var body: Node3D = ai.body
	var d := _clear(_dir, 2.4, body)
	var land := player.global_position + _dir * d
	var hit := body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(land + Vector3(0, 2.0, 0), land - Vector3(0, 3.0, 0), 1, [(body as CollisionObject3D).get_rid(), player.get_rid()]))
	if hit:
		land.y = (hit["position"] as Vector3).y
	var from := body.global_position
	var tw := body.create_tween().set_parallel()
	tw.tween_method(func(t: float): body.global_position = from.lerp(land, t) + Vector3.UP * sin(PI * t) * 0.3, 0.0, 1.0, 0.32)
	tw.tween_property(body, "rotation", Vector3(0, atan2(-_dir.x, -_dir.z), 0), 0.28)
	await tw.finished
	if not is_instance_valid(ai) or not is_instance_valid(body):
		return
	_one("ss_ground", -2.0)
	_anim(ai, String(st.get("react", "Hit_React")), false)
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(ai) or not is_instance_valid(body):
		return
	_one("ss_threat", 0.0)
	_anim(ai, "Alert", false)
	await get_tree().create_timer(0.85).timeout
	if not is_instance_valid(ai) or not is_instance_valid(body):
		return
	body.collision_layer = 1
	ai.voice.resume()
	ai.recoil(float(st.get("recover", 2.5)) * (1.0 if won else 0.7), "flee")


# ------------------------------------------------------------------ helpers
func _anim(ai: Node, clip: String, loop: bool) -> void:
	if ai == null or not is_instance_valid(ai):
		return
	var ap: AnimationPlayer = ai.anim
	if ap and ap.has_animation(clip):
		var a := ap.get_animation(clip)
		if loop and a.loop_mode == Animation.LOOP_NONE:
			a.loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = 1.0
		ap.play(clip, 0.1)


func _unloop(ai: Node, clip: String) -> void:
	var ap: AnimationPlayer = ai.anim
	if ap and ap.has_animation(clip):
		ap.get_animation(clip).loop_mode = Animation.LOOP_NONE


## [[delay, sound], ...]: each plays after its delay, unless the moment has passed (_seq moved on is a new moment).
func _queue(lines: Array, db: float) -> void:
	var seq := _seq
	for l in lines:
		if float(l[0]) <= 0.0:
			_one(String(l[1]), db)
		else:
			get_tree().create_timer(float(l[0])).timeout.connect(_queued.bind(seq, String(l[1]), db))


func _queued(seq: int, id: String, db: float) -> void:
	if seq == _seq:
		_one(id, db)


## A one-shot close to the listener: a bank id, or a full res:// path (the approved Skitter screech).
func _one(id: String, db: float) -> void:
	var s: AudioStream = (load(id) as AudioStream) if id.begins_with("res://") else Sfx.bank(id)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _shake(amount: float) -> void:
	if world.has_method("_shake"):
		var cam := get_viewport().get_camera_3d()
		if cam:
			world._shake(cam, amount, 0.02)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	_ui.visible = false
	add_child(_ui)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(c)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.position.y = 120
	c.add_child(v)
	_title = VeilUI.label("", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_hint = VeilUI.label("", 16, VeilUI.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0.6)
	frame.custom_minimum_size = Vector2(264, 14)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	_bar = ColorRect.new()
	_bar.color = Color(0.86, 0.3, 0.26)
	_bar.position = Vector2(2, 2)
	_bar.size = Vector2(0, 10)
	frame.add_child(_bar)
	_loop = AudioStreamPlayer.new()
	_loop.volume_db = -4.0
	add_child(_loop)
	_grip = AudioStreamPlayer.new()
	_grip.volume_db = -8.0
	add_child(_grip)
