extends Node
class_name VeilStruggle
## THE VEIL - first-person monster struggles (one shared controller for three creatures).
## A creature AI (game/enemies/hound_ai.gd) offers an attack through on_attack; now and then (cooldown, chance,
## never in story scenes, menus, the car, or when the player is badly hurt) the attack becomes a struggle instead:
##   hound   - it has the player's leg: the view drops to it, LEFT CLICK repeatedly to push it away
##   skitter - it leaps onto the player's chest: close to the camera, LEFT CLICK to throw it off
##   crab    - its claws catch the player and pull them in: LEFT CLICK to break the grip
## Success: the creature is thrown / pushed / let go, recovers (Hound, Crab: then hunts again; Skitter: hisses and
## zigzags away) - a moment to run, never a kill. Failure: extra damage (never a killing blow here), then the same
## release. Movement and look always come back; nothing of it is saved (a load simply never resumes one).

const SND := "res://game/audio/encounters/%s.wav"
const STYLE := {
	"hound": {"title": "THE HOUND HAS YOUR LEG!", "hint": "[LEFT CLICK REPEATEDLY]  PUSH IT AWAY", "time": 5.0,
		"start": ["hound_leg_bite", "hound_stinger"], "loop": "hound_struggle_loop", "win": ["hound_pushed_off", "hound_head_shake"],
		"after": "hound_chase_restart", "damage": 22.0, "recover": 2.6, "mode": "back", "anim": "Attack_Bite", "react": "Hit_React"},
	"skitter": {"title": "GET IT OFF!", "hint": "[LEFT CLICK REPEATEDLY]  THROW THE SKITTER", "time": 4.5,
		"start": ["res://game/encounters/skitter_hiss.wav", "skitter_stinger"], "loop": "skitter_on_player", "win": ["skitter_throw_off", "res://game/encounters/skitter_hiss.wav"],
		"after": "skitter_zigzag_retreat", "damage": 16.0, "recover": 3.2, "mode": "flee", "anim": "Attack_Lunge", "react": "Hit_React"},
	"crab": {"title": "BREAK FREE!", "hint": "[LEFT CLICK REPEATEDLY]  ESCAPE ITS GRIP", "time": 5.5,
		"start": ["crab_claw_grab", "crab_stinger"], "loop": "crab_grip_loop", "win": ["crab_release", "crab_step_back"],
		"after": "crab_pursuit", "damage": 28.0, "recover": 2.4, "mode": "back", "anim": "Attack_Grasp", "react": "Defend"},
}
const CHANCE := 0.35            ## of an eligible attack
const COOLDOWN := 40.0          ## seconds between struggles (any creature)
const PER_CLICK := 0.085        ## ~12 clicks in the allowed time; held buttons count once
const DECAY := 0.10             ## per second

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
var _music: AudioStreamPlayer


func setup(w: Node) -> void:
	world = w
	player = w.player
	_build_ui()


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if not active:
		return
	if _ai == null or not is_instance_valid(_ai) or not is_instance_valid(_ai.body) or player.get("health") <= 0.0:
		_finish(false, true)                       # the creature is gone or the player died: let go cleanly
		return
	_t -= delta
	_prog = maxf(_prog - DECAY * delta, 0.0)
	_bar.size.x = 260.0 * _prog
	_pose(delta)
	if _prog >= 1.0:
		_finish(true)
	elif _t <= 0.0:
		_finish(false)


func _input(e: InputEvent) -> void:
	if active and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_prog = minf(_prog + PER_CLICK, 1.0)          # a press, never a held button (no echo for mouse buttons)
		get_viewport().set_input_as_handled()


## Called by the creature AI at the moment it would bite. True = this attack is a struggle now.
func try_start(ai: Node) -> bool:
	if active or _cool > 0.0 or randf() > CHANCE or get_tree().paused:
		return false
	var kind := String(ai.get_meta("struggle_kind", ""))
	if not STYLE.has(kind) or not _player_free() or float(player.get("health")) < 30.0:
		return false
	active = true
	_ai = ai
	_kind = kind
	_prog = 0.0
	_t = float(STYLE[kind]["time"])
	ai.hold = true
	ai.body.velocity = Vector3.ZERO
	player.set("controls_enabled", false)
	player.set("look_enabled", false)
	player.set("velocity", Vector3.ZERO)
	_title.text = String(STYLE[kind]["title"])
	_hint.text = String(STYLE[kind]["hint"])
	_ui.visible = true
	_anim(ai, String(STYLE[kind]["anim"]), true)
	ai.body.collision_layer = 0                  # held against the player: it must not shove them anywhere
	for s in STYLE[kind]["start"]:
		_one(String(s), -2.0)
	_loop.stream = _stream(String(STYLE[kind]["loop"]), true)
	_loop.play()
	_music.stream = _stream("struggle_underscore_8s_loop", true)
	_music.volume_db = -10.0
	_music.play()
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


## Each frame: the creature kept where the struggle shows it and the view aimed at it.
func _pose(delta: float) -> void:
	var body: Node3D = _ai.body
	var cam: Camera3D = player.get("camera")
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	match _kind:
		"hound":
			# jaws on the lower leg: the body in front, head down at the player's shin; the view drops to it
			var want := player.global_position + fwd * 1.25
			body.global_position = body.global_position.lerp(Vector3(want.x, body.global_position.y, want.z), minf(delta * 8.0, 1.0))
			body.rotation.y = atan2(-fwd.x, -fwd.z) + sin(Time.get_ticks_msec() * 0.018) * 0.12   # head shaking
			_aim(player.rotation.y, -0.62, delta)
		"skitter":
			# on the chest, face to face: close in front of the camera, tilted up, legs around the view
			var at := cam.global_position + fwd * 0.4 + Vector3(0, -0.5, 0)
			body.global_position = at + Vector3(randf_range(-0.015, 0.015), randf_range(-0.015, 0.015), 0)
			body.rotation = Vector3(-1.05, atan2(-fwd.x, -fwd.z), sin(Time.get_ticks_msec() * 0.03) * 0.15)
			_aim(player.rotation.y, -0.18, delta)
		"crab":
			# caught and pulled in: the view drawn toward the body, the claws closed in front
			var want2 := player.global_position + fwd * 1.2
			body.global_position = body.global_position.lerp(Vector3(want2.x, body.global_position.y, want2.z), minf(delta * 6.0, 1.0))
			body.rotation.y = atan2(-fwd.x, -fwd.z)
			player.global_position += (body.global_position - player.global_position) * Vector3(1, 0, 1) * delta * 0.15
			_aim(player.rotation.y, -0.22, delta)


func _aim(yaw: float, pitch: float, delta: float) -> void:
	var head := player.get("head") as Node3D
	var p0 := head.rotation.x if head else 0.0
	player.set_yaw_pitch(yaw, lerpf(p0, pitch, minf(delta * 6.0, 1.0)))


func _finish(won: bool, cancelled := false) -> void:
	active = false
	_cool = COOLDOWN + randf_range(0.0, 20.0)
	_ui.visible = false
	_loop.stop()
	_music.stop()
	var st: Dictionary = STYLE.get(_kind, {})
	var ai := _ai
	_ai = null
	if not won and not cancelled and float(player.get("health")) > 0.0:
		# never a killing blow here: the existing damage / death rules are left to the ordinary attacks
		var hp := float(player.get("health"))
		player.damage(minf(float(st.get("damage", 15.0)), maxf(hp - 5.0, 0.0)), ai.body.global_position if ai and is_instance_valid(ai) else player.global_position)
	if ai and is_instance_valid(ai) and is_instance_valid(ai.body):
		var body: Node3D = ai.body
		var fwd := -player.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		if _kind == "skitter":
			# thrown down in front: lands on its feet on the ground, rears up, hisses, then zigzags off
			var land := player.global_position + fwd * 2.4
			var space := body.get_world_3d().direct_space_state
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(land + Vector3(0, 2.0, 0), land - Vector3(0, 3.0, 0), 1))
			if hit:
				land.y = (hit["position"] as Vector3).y
			body.rotation = Vector3(0, atan2(-fwd.x, -fwd.z), 0)
			var tw := body.create_tween()
			tw.tween_property(body, "global_position", land, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			body.global_position += fwd * (0.9 if won else 0.4)    # pushed / let go, a step back
		_anim(ai, String(st.get("react", "Hit_React")), false)
		body.collision_layer = 1
		if won:
			for s in st.get("win", []):
				_one(String(s), 0.0)
		ai.recoil(float(st.get("recover", 2.5)) * (1.0 if won else 0.7), String(st.get("mode", "back")))
		get_tree().create_timer(1.2).timeout.connect(func(): _one(String(st.get("after", "")), -4.0))
	player.set("controls_enabled", true)
	player.set("look_enabled", true)
	player.set_yaw_pitch(player.rotation.y, 0.0)    # the view level again
	_kind = ""


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


func _stream(id: String, loop: bool) -> AudioStream:
	var s := load(SND % id) as AudioStream
	var w := s as AudioStreamWAV
	if w and loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return s


## A one-shot near the listener. An id is a file in the encounter pack, or a full res:// path (the approved
## Skitter hiss from game/encounters/ is used as is).
func _one(id: String, db: float) -> void:
	var path := id if id.begins_with("res://") else SND % id
	if id == "" or not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
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
	_music = AudioStreamPlayer.new()
	add_child(_music)
