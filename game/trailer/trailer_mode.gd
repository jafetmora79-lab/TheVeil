extends CanvasLayer
class_name VeilTrailerMode
## THE VEIL - trailer / capture tools. Only when the game is started with `--trailer` (TheVeil_TrailerMode.bat runs
## `TheVeil.exe -- --trailer`); in a normal game none of this exists. It lives on the root, so it survives the
## scene reloads of the jump menu.
##   F1   this help on / off
##   F9   clean screen: every HUD, prompt, marker and overlay hidden (again: back)
##   F8   free camera on / off (the player holds still): WASD move, mouse look, Q / E down / up, Shift faster,
##        mouse wheel speed
##   1-9  (free camera) choose a shot slot      F5 add the camera as the slot's next keyframe
##   F6   play the slot (smooth through its keyframes)      F7 clear the slot      - / + shot length (seconds)
##   F4   slow motion: 1x -> 0.5x -> 0.25x -> 1x
##   F11  jump to a point of the story (the opening, or the start of a chapter)
##   F12  play the trailer ("The Change", about 1:40): start your recorder first; Esc stops it
## Shots are saved in user://trailer_shots.json.

const SHOTS_PATH := "user://trailer_shots.json"
const CHAPTERS := [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

var clean := false
var free_cam := false
var cam: Camera3D
var slot := 1
var shots := {}                         ## "1".."9" -> {"keys": [[px,py,pz, qx,qy,qz,qw], ...], "secs": 6.0}
var speed := 6.0
var playing := false
var _yaw := 0.0
var _pitch := 0.0
var _hidden: Array = []                 ## [CanvasItem/CanvasLayer, was_visible]
var _prev_cam: Camera3D
var _help: Label
var _status: Label
var _menu_open := false


static func wanted() -> bool:
	return OS.get_cmdline_user_args().has("--trailer") or OS.get_cmdline_args().has("--trailer")


static func ensure(tree: SceneTree) -> void:
	if not wanted() or tree.root.get_node_or_null("TrailerMode") != null:
		return
	var t = (load("res://game/trailer/trailer_mode.gd") as GDScript).new()
	t.name = "TrailerMode"
	tree.root.add_child.call_deferred(t)


func _ready() -> void:
	print("THE VEIL: trailer mode on (T or F12 plays the trailer)")
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_help = Label.new()
	_help.position = Vector2(16, 16)
	_help.add_theme_font_size_override("font_size", 14)
	_help.add_theme_color_override("font_color", Color(1, 1, 1))
	_help.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_help.add_theme_constant_override("outline_size", 4)
	_help.text = "TRAILER MODE\nT or F12: PLAY THE TRAILER (start recording first)\nF1 help  F9 clean screen  F8 free camera  F4 slow motion  F11 jump\n" \
		+ "Free camera: WASD / mouse, Q E down up, Shift fast, wheel speed\n1-9 shot slot  F5 add keyframe  F6 play  F7 clear  - + length"
	add_child(_help)
	_status = Label.new()
	_status.position = Vector2(16, 110)
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_status.add_theme_constant_override("outline_size", 4)
	add_child(_status)
	_load_shots()
	_update_status()


func _world() -> Node:
	return get_tree().get_first_node_in_group("veil_world")


func _input(e: InputEvent) -> void:
	if _menu_open:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		var used := true
		match k:
			KEY_F1:
				_help.visible = not _help.visible
			KEY_F9:
				set_clean(not clean)
			KEY_F8:
				set_free_cam(not free_cam)
			KEY_F4:
				Engine.time_scale = 0.5 if is_equal_approx(Engine.time_scale, 1.0) else (0.25 if is_equal_approx(Engine.time_scale, 0.5) else 1.0)
			KEY_F5:
				add_key()
			KEY_F6:
				play_shot()
			KEY_F7:
				shots.erase(str(slot))
				_save_shots()
			KEY_F11:
				_jump_menu()
			KEY_F12, KEY_T:
				_play_trailer()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_shot()["secs"] = maxf(1.0, float(_shot()["secs"]) - 1.0)
				_save_shots()
			KEY_EQUAL, KEY_KP_ADD:
				_shot()["secs"] = float(_shot()["secs"]) + 1.0
				_save_shots()
			_:
				used = false
				if free_cam and k >= KEY_1 and k <= KEY_9:
					slot = k - KEY_0
					used = true
		if used:
			_update_status()
			get_viewport().set_input_as_handled()
		return
	if free_cam and not playing:
		if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var r := (e as InputEventMouseMotion).relative
			_yaw -= r.x * 0.003
			_pitch = clampf(_pitch - r.y * 0.003, -1.5, 1.5)
			get_viewport().set_input_as_handled()
		elif e is InputEventMouseButton and e.pressed:
			var b := (e as InputEventMouseButton).button_index
			if b == MOUSE_BUTTON_WHEEL_UP:
				speed = minf(speed * 1.25, 80.0)
			elif b == MOUSE_BUTTON_WHEEL_DOWN:
				speed = maxf(speed / 1.25, 0.5)
			_update_status()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not free_cam or playing or cam == null:
		return
	var real := delta / maxf(Engine.time_scale, 0.01)        # the camera flies at real speed in slow motion
	var mv := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): mv.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): mv.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): mv.x += 1.0
	if Input.is_physical_key_pressed(KEY_E): mv.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q): mv.y -= 1.0
	var b := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	cam.global_transform = Transform3D(b, cam.global_position + b * mv.limit_length(1.0) * speed * real * (3.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0))


# ------------------------------------------------------------------ clean screen
func set_clean(on: bool) -> void:
	clean = on
	if on:
		_hidden.clear()
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if n == self:
				continue
			_hidden.append([n, (n as CanvasLayer).visible])
			(n as CanvasLayer).visible = false
		_help.visible = false
		_status.visible = false
		var w := _world()
		if w:
			for n in w.find_children("*", "Node3D", true, false):
				if String(n.name).begins_with("Beacon") or String(n.name).contains("Diamond") or n is Label3D and String(n.name).begins_with("Prompt"):
					_hidden.append([n, (n as Node3D).visible])
					(n as Node3D).visible = false
	else:
		for h in _hidden:
			if is_instance_valid(h[0]):
				h[0].visible = h[1]
		_hidden.clear()
		_status.visible = true
	_update_status()


# ------------------------------------------------------------------ free camera
func set_free_cam(on: bool) -> void:
	var w := _world()
	if on:
		_prev_cam = get_viewport().get_camera_3d()
		cam = Camera3D.new()
		cam.name = "TrailerCam"
		cam.far = 900.0
		if _prev_cam:
			cam.fov = _prev_cam.fov
		get_tree().root.add_child(cam)
		if _prev_cam:
			cam.global_transform = _prev_cam.global_transform
			var eu := _prev_cam.global_basis.get_euler()
			_pitch = eu.x
			_yaw = eu.y
		cam.current = true
		if w and w.get("player"):
			w.player.set("controls_enabled", false)
			w.player.set("look_enabled", false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		free_cam = true
	else:
		free_cam = false
		if is_instance_valid(cam):
			cam.queue_free()
		if is_instance_valid(_prev_cam):
			_prev_cam.current = true
		if w and w.get("player"):
			w.player.set("controls_enabled", true)
			w.player.set("look_enabled", true)
	_update_status()


# ------------------------------------------------------------------ shots
func _shot() -> Dictionary:
	var k := str(slot)
	if not shots.has(k):
		shots[k] = {"keys": [], "secs": 6.0}
	return shots[k]


func add_key() -> void:
	if not free_cam or cam == null:
		return
	var p := cam.global_position
	var q := cam.global_basis.get_rotation_quaternion()
	(_shot()["keys"] as Array).append([p.x, p.y, p.z, q.x, q.y, q.z, q.w])
	_save_shots()


func play_shot() -> void:
	var keys: Array = _shot()["keys"]
	if keys.size() < 2 or playing:
		return
	if not free_cam:
		set_free_cam(true)
	playing = true
	var secs := float(_shot()["secs"])
	var t := 0.0
	while t < secs:
		var u := clampf(t / secs, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		cam.global_transform = sample(keys, u)
		await get_tree().process_frame
		t += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	cam.global_transform = sample(keys, 1.0)
	var eu := cam.global_basis.get_euler()
	_pitch = eu.x
	_yaw = eu.y
	playing = false


## The camera along the keyframes at u (0..1): positions on a Catmull-Rom curve, rotations slerped.
static func sample(keys: Array, u: float) -> Transform3D:
	var n := keys.size()
	var f := u * (n - 1)
	var i := clampi(int(floor(f)), 0, n - 2)
	var lt := f - i
	var P := func(j: int) -> Vector3:
		var a: Array = keys[clampi(j, 0, n - 1)]
		return Vector3(a[0], a[1], a[2])
	var Q := func(j: int) -> Quaternion:
		var a: Array = keys[clampi(j, 0, n - 1)]
		return Quaternion(a[3], a[4], a[5], a[6]).normalized()
	var p0: Vector3 = P.call(i - 1)
	var p1: Vector3 = P.call(i)
	var p2: Vector3 = P.call(i + 1)
	var p3: Vector3 = P.call(i + 2)
	var pos := p1.cubic_interpolate(p2, p0, p3, lt)
	var q: Quaternion = (Q.call(i) as Quaternion).slerp(Q.call(i + 1), lt)
	return Transform3D(Basis(q), pos)


func _load_shots() -> void:
	if not FileAccess.file_exists(SHOTS_PATH):
		return
	var f := FileAccess.open(SHOTS_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary:
		shots = d


func _save_shots() -> void:
	var f := FileAccess.open(SHOTS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(shots))


# ------------------------------------------------------------------ jump to a point of the story
func _jump_menu() -> void:
	var panel := VeilChoicePanel.new()
	add_child(panel)
	_menu_open = true
	var opts: Array = ["Play the trailer (start recording first)", "The opening (new game, with the intro)"]
	for c in CHAPTERS:
		if ResourceLoader.exists("res://game/chapters/setups/dev_chapter%d.gd" % c):
			opts.append("Chapter %d" % c)
	opts.append("Cancel")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var i: int = await panel.ask("JUMP TO", opts)
	panel.queue_free()
	_menu_open = false
	if i < 0 or i >= opts.size() - 1:
		return
	if i == 0:
		_play_trailer()
		return
	if free_cam:
		set_free_cam(false)
	if clean:
		set_clean(false)
	Engine.time_scale = 1.0
	get_tree().paused = false
	Game.new_game()
	if i > 1:
		var ch := int(String(opts[i]).split(" ")[1])
		(load("res://game/chapters/setups/dev_chapter%d.gd" % ch)).prepare(Game)
		Game.flags["intro_seen"] = true
	get_tree().change_scene_to_file("res://game/scenes/World.tscn")


func _update_status() -> void:
	if _status == null:
		return
	var s := "slot %d: %d keys, %.0f s" % [slot, (_shot()["keys"] as Array).size(), float(_shot()["secs"])]
	_status.text = "%s   cam %s   speed %.1f   time %.2fx%s" % [s, "FREE" if free_cam else "game", speed, Engine.time_scale,
		"   CLEAN" if clean else ""]


func _play_trailer() -> void:
	if get_tree().root.get_node_or_null("TrailerDirector") != null:
		return
	if free_cam:
		set_free_cam(false)
	if clean:
		set_clean(false)
	load("res://game/trailer/trailer_director.gd").start(get_tree())
