extends Node3D

const Progress = preload("res://opening/progress.gd")
const Player = preload("res://opening/player.gd")
const ROOT := "res://THE_VEIL_ASSETS_V2/"
var progress = Progress.new()
var player: CharacterBody3D
var home: Node3D
var targets: Array[Dictionary] = []
var focused: Dictionary = {}
var hud: Label
var prompt: Label
var subtitle: Label
var title: Label
var subtitle_time := 0.0
var wake_time := 4.5
var drive_camera: Camera3D
var route := PackedVector3Array()
var route_index := 1
var drive_speed := 0.0
var waypoint: Label3D

func _ready() -> void:
	_bind_inputs()
	home = $World/Greyhaven_Residential/Houses/PLAYER_HOME
	# Zone labels are production annotations, not part of the inhabited town.
	$World/Greyhaven_Town/BuildingZones.visible = false
	_lighting()
	player = Player.new()
	add_child(player)
	player.global_transform = home.get_node("Markers/Spawn_WakeUp").global_transform
	player.camera.current = true
	for data in home.get_meta("veil_interactables", []):
		var node: Node3D = home.get_node_or_null(data.node)
		if node == null:
			node = home.find_child(data.node, true, false)
		if node == null:
			push_error("Missing home interaction: " + data.node)
			continue
		var entry: Dictionary = data.duplicate()
		entry.target = node
		entry.closed = node.transform
		entry.open = false
		targets.append(entry)
	_ui()
	_drive_route()
	_add_neighbors()
	waypoint = Label3D.new()
	waypoint.text = "CAR • E to enter\nTemporary seat marker"
	waypoint.font_size = 32
	waypoint.pixel_size = 0.006
	waypoint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(waypoint)
	waypoint.global_position = home.get_node("Markers/Sedan_Driveway").global_position + Vector3.UP * 1.5
	# Override conflicting 6:47 baked clock with a readable in-world time label.
	var clock := Label3D.new()
	clock.text = "FRIDAY  6:42 PM"
	clock.font_size = 32
	clock.pixel_size = 0.002
	clock.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	home.add_child(clock)
	clock.position = Vector3(2.475, 1.27, 5.5)
	home.get_node("Furniture/AlarmClock_01").visible = false
	_say("6:42 already. Something to eat, then maybe that horror game.", 7)

func _bind_inputs() -> void:
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"interact": KEY_E, "sprint": KEY_SHIFT, "restart": KEY_R, "pause": KEY_ESCAPE}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)

func _lighting() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("8799ac")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9c5d2")
	settings.ambient_light_energy = 0.65
	settings.fog_enabled = false
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -45, 0)
	sun.light_color = Color("ffd3a2")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = _label(layer, Vector2(24, 20), 21)
	prompt = _label(layer, Vector2(24, 510), 22)
	subtitle = _label(layer, Vector2(24, 570), 20)
	title = _label(layer, Vector2(380, 240), 36)
	title.text = "THE VEIL\nFriday • 6:42 PM"
	var cross := _label(layer, Vector2(571, 317), 20)
	cross.text = "·"

func _label(parent: Node, pos: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size.x = 1104 - pos.x
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	if event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not progress.driving and not progress.complete:
		if progress.departed and player.global_position.distance_to(route[0]) < 3.0:
			_begin_drive()
		elif not focused.is_empty():
			_interact(focused)

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		prompt.text = "PAUSED • Esc to resume • R restart"
		return
	wake_time -= delta
	title.visible = wake_time > 0 or progress.complete
	subtitle_time -= delta
	subtitle.visible = subtitle_time > 0
	hud.text = "FRIDAY • 6:42 PM    |    Keys: %s\n%s\nWASD move • Mouse look • E interact • Shift walk faster • Esc pause • R restart" % ["yes" if progress.has_keys else "no", progress.objective()]
	if progress.driving:
		_drive(delta)
		return
	if progress.complete:
		prompt.text = "R to replay the opening"
		return
	_focus()
	if progress.departed and player.global_position.distance_to(route[0]) < 3.0:
		prompt.text = "E • Enter car (temporary seat; sedan asset absent)"
	elif not focused.is_empty():
		prompt.text = "E • " + _target_name(focused)
	else:
		prompt.text = ""
	if player.global_position.y < -5:
		player.global_transform = home.get_node("Markers/Spawn_WakeUp").global_transform
		player.velocity = Vector3.ZERO

func _focus() -> void:
	focused = {}
	var best := 0.78
	var camera: Camera3D = player.camera
	for entry in targets:
		var node: Node3D = entry.target
		if not is_instance_valid(node) or not node.visible:
			continue
		# Metadata position remains stable even when a door swings.
		var point := home.to_global(Vector3(entry.pos[0], entry.pos[1], entry.pos[2]))
		if entry.node.contains("Door"):
			point.y += 0.85
		var offset := point - camera.global_position
		if offset.length() > 2.5:
			continue
		var score := (-camera.global_basis.z).dot(offset.normalized())
		if score <= best:
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, point)
		query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		# Allow the target's own carcass, but never an intervening room wall.
		if not hit.is_empty() and hit.position.distance_to(point) > 0.7:
			continue
		best = score
		focused = entry

func _target_name(entry: Dictionary) -> String:
	if entry.node.contains("CarKeys"):
		return "Take car keys"
	if entry.node.contains("ApplianceDoor_Fridge"):
		return "Check fridge" if not progress.fridge_checked else "Close fridge" if entry.open else "Open fridge"
	if entry.node == "INT_Door_Front":
		return "Leave home" if not entry.open else "Close front door"
	return str(entry.node).get_file().trim_prefix("INT_").replace("_", " ")

func _interact(entry: Dictionary) -> void:
	if entry.get("busy", false):
		return
	if entry.node.contains("CarKeys"):
		progress.has_keys = true
		entry.target.visible = false
		_say("Keys. Now I can head out." if progress.fridge_checked else "Got my keys. I should check what is left in the fridge.")
		return
	if entry.node == "INT_Door_Front" and not progress.can_leave():
		_say("I should check the fridge first." if not progress.fridge_checked else "I need my car keys. They are on the coat rack.")
		return
	if entry.node.contains("ApplianceDoor_Fridge") and not progress.fridge_checked:
		progress.fridge_checked = true
		_say("Nearly empty. Dinner will have to wait. I need to get some groceries.", 7)
	if entry.node == "INT_Door_Front" and not entry.open:
		progress.departed = true
		_say("Groceries first. There is still time to pick up a game.")
	var kind: String = entry.veil_interact
	if kind == "switch":
		var light := home.get_node_or_null("Lights/Ceiling_" + str(entry.get("room", "")))
		if light != null:
			light.light_energy = 0.7 if light.light_energy == 0 else 0.0
		return
	if kind not in ["hinge", "slide", "toggle"]:
		return
	entry.open = not entry.open
	var target: Node3D = entry.target
	var closed: Transform3D = entry.closed
	var axis := Vector3.UP
	if entry.get("axis", "y") == "x": axis = Vector3.RIGHT
	if entry.get("axis", "y") == "z": axis = Vector3.BACK
	entry.busy = true
	var tween := create_tween()
	tween.finished.connect(func(): entry.busy = false)
	if kind == "slide":
		tween.tween_property(target, "position", closed.origin + axis * float(entry.get("distance", 0.3)) * float(entry.open), 0.4)
	else:
		tween.tween_property(target, "rotation", closed.basis.get_euler() + axis * deg_to_rad(float(entry.get("open_deg", 90))) * float(entry.open), 0.4)

func _say(line: String, duration := 5.0) -> void:
	subtitle.text = line
	subtitle_time = duration

func _drive_route() -> void:
	var journey := $World/Greyhaven_Town/Journey
	var start: Vector3 = journey.get_node("2_SEDAN_ON_DRIVEWAY").global_position
	var maple: Vector3 = journey.get_node("3_DRIVE_MAPLE_TO_OAK").global_position
	var main: Vector3 = journey.get_node("4_OAK_TO_MAIN").global_position
	var parking: Vector3 = journey.get_node("5_SUPERMARKET_PARKING").global_position
	# Right-angle road segments, never a straight chord through lots.
	route = PackedVector3Array([start, Vector3(start.x, start.y, maple.z), maple, main, Vector3(parking.x, main.y, main.z), parking])

func _begin_drive() -> void:
	progress.driving = true
	player.enabled = false
	waypoint.visible = false
	drive_camera = Camera3D.new()
	add_child(drive_camera)
	drive_camera.global_position = route[0] + Vector3.UP * 1.2
	drive_camera.look_at(route[1] + Vector3.UP * 1.2)
	drive_camera.current = true
	_say("Supermarket parking, via Maple Avenue, Oak Street and Main Street.", 7)

func _drive(delta: float) -> void:
	var accelerating := Input.is_action_pressed("forward")
	var braking := Input.is_action_pressed("back")
	drive_speed = move_toward(drive_speed, 8.0 if accelerating and not braking else 0.0, (8.0 if braking else 3.0) * delta)
	var target := route[route_index] + Vector3.UP * 1.2
	drive_camera.global_position = drive_camera.global_position.move_toward(target, drive_speed * delta)
	if drive_camera.global_position.distance_to(target) > 0.05:
		drive_camera.look_at(target)
	prompt.text = "W accelerate • S brake • %.0f km/h • Road segment %d/%d" % [drive_speed * 3.6, route_index, route.size() - 1]
	if drive_camera.global_position.distance_to(target) < 0.05:
		route_index += 1
		if route_index >= route.size():
			progress.driving = false
			progress.complete = true
			title.text = "SUPERMARKET PARKING\nOpening prototype complete"
			_say("Made it. Groceries, then a game.\nThe next scene is not implemented. R to replay.", 60)

func _add_neighbors() -> void:
	# Existing named cast used only as visual placeholders, without new story claims.
	var placements := [["Civilians/CHR_Ruth.glb", Vector3(10, 0.15, -98)], ["Civilians/CHR_Sarah.glb", Vector3(6.8, 0.15, -48)], ["Commercial_NPCs/CHR_Eddie.glb", Vector3(22, 0.15, -9)]]
	for placement in placements:
		var scene: PackedScene = load(ROOT + "06_Characters/" + placement[0])
		var neighbor := scene.instantiate()
		add_child(neighbor)
		neighbor.position = placement[1]
