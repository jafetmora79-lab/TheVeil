extends Node3D
## Optional, skippable scene-based title sequence. It never touches story flags or saves.
## Intro: a quiet dusk outside the existing player home, then the original wake-up.
## Preview: actual Greyhaven sets and existing creature rigs, staged for a short mood reel.

const CORE := preload("res://game/world/Greyhaven_Core.tscn")
const HOUSES := preload("res://game/world/Greyhaven_Houses.tscn")
const COMMERCIAL := preload("res://THE_VEIL_ASSETS_V2/04_Commercial/Godot_Scenes/Greyhaven_Commercial.tscn")
const HOUND := preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Hounds/CRT_Hound.glb")
const SKITTER := preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Skitter/CRT_Skitter.glb")
const COLOSSUS := preload("res://THE_VEIL_ASSETS_V2/07_Creatures/Colossus/CRT_Colossus.glb")

var mode := "intro"
var camera: Camera3D
var screen: ColorRect
var caption: Label
var small: Label
var skip: Button
var elapsed := 0.0
var shot := -1
var finished := false
var stage: Node3D
var creature: Node3D
var cue: AudioStreamPlayer
var tracks: Array[Dictionary] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	stage = Node3D.new()
	stage.name = "ExistingGreyhaven"
	add_child(stage)
	stage.add_child(CORE.instantiate())
	if mode == "intro":
		stage.add_child(HOUSES.instantiate())
	else:
		stage.add_child(COMMERCIAL.instantiate())
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.far = 110.0
	add_child(camera)
	camera.make_current()
	cue = AudioStreamPlayer.new()
	cue.volume_db = -18.0
	add_child(cue)
	_make_overlay()
	if mode == "intro":
		# The street and the real PLAYER_HOME (56, 0.15, 508.5); no mist or monster yet.
		tracks = [
			{"duration": 4.0, "from": Vector3(45, 2.3, 501), "to": Vector3(49, 2.1, 504), "look": Vector3(56, 2.2, 508.5), "title": "GREYHAVEN", "sub": "FRIDAY  ·  6:42 PM"},
			{"duration": 4.2, "from": Vector3(50, 1.8, 507), "to": Vector3(53, 1.8, 507), "look": Vector3(56, 2.0, 508.5), "title": "THE VEIL", "sub": "It was an ordinary evening."},
			{"duration": 2.2, "from": Vector3(53, 1.8, 507), "to": Vector3(53, 1.8, 507), "look": Vector3(56, 2.0, 508.5), "title": "", "sub": ""},
		]
	else:
		# The actual shop and supermarket placements from Greyhaven_Commercial.tscn.
		# The creatures are shown only here, as staged silhouettes; the story is untouched.
		tracks = [
			{"duration": 4.0, "from": Vector3(0, 2.0, 13), "to": Vector3(5, 1.7, 12), "look": Vector3(14, 2.1, 7), "title": "AN ORDINARY NIGHT", "sub": "One last stop before heading home."},
			{"duration": 4.0, "from": Vector3(7, 1.8, 11), "to": Vector3(10, 1.8, 10), "look": Vector3(14, 2.0, 7), "title": "THEN THE TOWN WENT QUIET", "sub": "Greyhaven is disappearing."},
			{"duration": 4.2, "from": Vector3(27, 1.8, -18), "to": Vector3(28, 1.7, -20), "look": Vector3(33, 2.0, -27), "title": "FIND SHELTER", "sub": "Keep the others close."},
			{"duration": 3.8, "from": Vector3(24, 1.5, -17), "to": Vector3(23, 1.45, -18), "look": Vector3(27, 0.8, -21), "title": "STAY OUT OF SIGHT", "sub": "Something moves beyond the streetlights.", "creature": "hound"},
			{"duration": 3.8, "from": Vector3(27, 1.6, -18), "to": Vector3(27.5, 1.6, -19), "look": Vector3(33, 1.7, -27), "title": "SURVIVE THE NIGHT", "sub": "Scavenge. Return. Hold on.", "creature": "skitter"},
			{"duration": 4.2, "from": Vector3(17, 1.65, -7), "to": Vector3(16, 1.65, -8), "look": Vector3(22, 4.0, -16), "title": "THE MIST HAS A SHAPE", "sub": "And it remembers you.", "creature": "colossus"},
			{"duration": 5.0, "from": Vector3(5, 1.8, 11), "to": Vector3(5, 1.8, 11), "look": Vector3(14, 2.1, 7), "title": "THE VEIL", "sub": "A survival horror game set in Greyhaven."},
		]
	_next_shot()


func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(frame)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.018, 0.027, 0.42)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)
	caption = VeilUI.label("", 36, Color(0.96, 0.92, 0.82))
	caption.anchor_left = 0.07
	caption.anchor_top = 0.70
	caption.anchor_right = 0.94
	caption.anchor_bottom = 0.82
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(caption)
	small = VeilUI.label("", 17, Color(0.8, 0.81, 0.77))
	small.anchor_left = 0.07
	small.anchor_top = 0.83
	small.anchor_right = 0.94
	small.anchor_bottom = 0.92
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(small)
	skip = VeilUI.button("SKIP  ·  Esc / Space / Enter")
	skip.anchor_left = 0.72
	skip.anchor_top = 0.02
	skip.anchor_right = 0.98
	skip.anchor_bottom = 0.09
	skip.pressed.connect(_finish)
	frame.add_child(skip)
	screen = ColorRect.new()
	screen.color = Color.BLACK
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			_finish()


func _process(delta: float) -> void:
	if finished or shot < 0:
		return
	elapsed += delta
	var beat: Dictionary = tracks[shot]
	var duration: float = beat["duration"]
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	camera.position = (beat["from"] as Vector3).lerp(beat["to"] as Vector3, eased)
	camera.look_at(beat["look"])
	# Black at each cut, then breathe into the scene; conceal loading and geometry pops.
	var opacity := 1.0 - clampf(elapsed / 0.8, 0.0, 1.0)
	if t > 0.83:
		opacity = maxf(opacity, (t - 0.83) / 0.17)
	screen.color.a = opacity
	caption.modulate.a = minf(1.0, elapsed / 0.8)
	small.modulate.a = caption.modulate.a
	if elapsed >= duration:
		_next_shot()


func _next_shot() -> void:
	shot += 1
	if shot >= tracks.size():
		_finish()
		return
	elapsed = 0.0
	var beat: Dictionary = tracks[shot]
	caption.text = beat["title"]
	small.text = beat["sub"]
	if is_instance_valid(creature):
		creature.queue_free()
	creature = null
	match beat.get("creature", ""):
		"hound": _place_creature(HOUND, Vector3(27, 0.15, -21), Vector3(23, 0, -18))
		"skitter": _place_creature(SKITTER, Vector3(31, 0.15, -23), Vector3(27, 0, -18))
		"colossus": _place_creature(COLOSSUS, Vector3(22, 0.15, -16), Vector3(16, 0, -8))
	if cue:
		cue.stop()
		var audio_path := ""
		match beat.get("creature", ""):
			"hound": audio_path = "res://game/audio/encounters/hound_head_shake.wav"
			"skitter": audio_path = "res://game/audio/encounters/skitter_hiss.wav"
			"colossus": audio_path = "res://game/audio/music/colossus_appearance.wav"
		if audio_path != "":
			cue.stream = load(audio_path)
			cue.play()
	var env := stage.get_node_or_null("Greyhaven_Core/Environment/WorldEnvironment") as WorldEnvironment
	if env and env.environment:
		# Duplicate the resource so the actual game's evening lighting is never changed.
		if not env.environment.resource_local_to_scene:
			env.environment = env.environment.duplicate()
		env.environment.fog_density = 0.004 if mode == "intro" or shot == 0 else 0.018


func _place_creature(packed: PackedScene, at: Vector3, toward: Vector3) -> void:
	creature = packed.instantiate() as Node3D
	stage.add_child(creature)
	creature.position = at
	creature.look_at(toward, Vector3.UP)
	# Play an existing embedded clip if this particular rig contains it.
	var players := creature.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var anim := players[0] as AnimationPlayer
		for name in ["Walk_Heavy", "Crawl", "Idle_Twitch", "Idle"]:
			if anim.has_animation(name):
				anim.play(name)
				break


func _finish() -> void:
	if finished:
		return
	finished = true
	set_process(false)
	get_tree().change_scene_to_file("res://game/scenes/World.tscn" if mode == "intro" else "res://game/scenes/MainMenu.tscn")
