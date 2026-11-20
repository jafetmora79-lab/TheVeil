extends Node3D
## THE VEIL - the Meshy tripod bonecage creature standing in for the Colossus. A re-staging of the title reel's Colossus shot ("THE MIST HAS A SHAPE") with the Meshy protagonist, Eddie and Marcus standing in front of it
## (Marcus is played by the bearded_man model for now). Uses the real Greyhaven sets and the real Colossus rig; the characters run under the game's NpcAnimator.
##   godot --path . --fixed-fps 24 --resolution 960x540 res://game/prototypes/npc_meshy/ColossusScene.tscn -- frames <out_dir>
## (needs a window; the PNG frames are assembled into a GIF afterwards)
const CORE := preload("res://game/world/Greyhaven_Core.tscn")
const COMMERCIAL := preload("res://THE_VEIL_ASSETS_V2/04_Commercial/Godot_Scenes/Greyhaven_Commercial.tscn")
const COLOSSUS := preload("res://game/prototypes/monsters_meshy/MON_tripod.glb")
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
const DT := 1.0 / 24.0
const START := Vector3(25.0, 0.15, -21.8)                # where the title reel places the Colossus
const GROUP := Vector3(19.0, 0.15, -10.3)              # the three of them, a few metres in front of the camera's first position

var out := ""
var camera: Camera3D
var stage: Node3D
var colossus: Node3D
var eye: VeilTripodEye
var scan: Node3D
var cast := {}                                         # name -> {"holder", "anim", "face"}
var caption: Label
var small: Label
var fade: ColorRect


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "frames" and i + 1 < a.size():
			out = a[i + 1]
	stage = Node3D.new()
	add_child(stage)
	stage.add_child(CORE.instantiate())
	stage.add_child(COMMERCIAL.instantiate())
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.far = 110.0
	add_child(camera)
	camera.make_current()
	var env := stage.get_node_or_null("Greyhaven_Core/Environment/WorldEnvironment") as WorldEnvironment
	if env and env.environment:
		env.environment = env.environment.duplicate()
		env.environment.fog_density = 0.018
	_overlay()
	_cast()
	colossus = COLOSSUS.instantiate() as Node3D
	add_child(colossus)
	colossus.position = START
	eye = VeilTripodEye.new()
	colossus.add_child(eye)
	colossus.look_at(Vector3(16, 0, -8), Vector3.UP)
	var players := colossus.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap := players[0] as AnimationPlayer
		for nm in ["Walk_Heavy", "Idle"]:
			if ap.has_animation(nm):
				ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
				ap.play(nm)
				break
	_run.call_deferred()


func _overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.018, 0.027, 0.38)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	caption.anchor_left = 0.06
	caption.anchor_top = 0.72
	caption.anchor_right = 0.94
	caption.anchor_bottom = 0.84
	layer.add_child(caption)
	small = Label.new()
	small.add_theme_font_size_override("font_size", 17)
	small.add_theme_color_override("font_color", Color(0.8, 0.81, 0.77))
	small.anchor_left = 0.06
	small.anchor_top = 0.85
	small.anchor_right = 0.94
	small.anchor_bottom = 0.93
	layer.add_child(small)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)


func _person(nm: String, model: Node3D, face: Node, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = nm
	add_child(holder)
	holder.position = at
	holder.add_child(model)
	var anim: Node = NPC_ANIM.new()
	anim.name = "Animator"
	holder.add_child(anim)
	holder.look_at(Vector3(START.x, at.y, START.z), Vector3.UP)           # facing the Colossus (a character faces -Z)
	cast[nm] = {"holder": holder, "anim": anim, "face": face}


func _cast() -> void:
	var f := (Vector3(START.x, 0, START.z) - Vector3(GROUP.x, 0, GROUP.z)).normalized()
	var r := f.cross(Vector3.UP)
	# the protagonist (Meshy, with face expressions), Eddie and Marcus (bearded_man) side by side
	var pm := (load("res://game/prototypes/protagonist_meshy/face/CHR_Protagonist_FaceTex.glb") as PackedScene).instantiate() as Node3D
	VeilSarahMeshyProto.psx_look(pm)
	var pf := VeilProtagonistFaceTex.new()
	pm.add_child(pf)
	pf.setup(pm)
	_person("Protagonist", pm, pf, GROUP)
	var em := VeilNpcFaceTex.instantiate("eddie")
	_person("Eddie", em, em.get_node("FaceTex"), GROUP - r * 1.05 - f * 0.9)
	var mm := VeilNpcFaceTex.instantiate("bearded_man")
	_person("Marcus", mm, mm.get_node("FaceTex"), GROUP + r * 1.0 - f * 0.55)
	var target := Node3D.new()                                              # what they look at: the Colossus's head
	add_child(target)
	target.name = "ColossusHead"
	target.position = START + Vector3(0, 9.0, 0)
	for nm in cast:
		cast[nm]["anim"].look_target = target
		cast[nm]["anim"].max_pitch = 0.5


func _set_look() -> void:
	(get_node("ColossusHead") as Node3D).global_position = eye.eye_world_pos()


func _frame(i: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/col_%03d.png" % [out, i])


func _head(nm: String) -> Vector3:
	return (cast[nm]["holder"] as Node3D).global_position + Vector3(0, 1.62, 0)


func _run() -> void:
	var f := (Vector3(START.x, 0, START.z) - Vector3(GROUP.x, 0, GROUP.z)).normalized()
	var r := f.cross(Vector3.UP)
	scan = Node3D.new()
	add_child(scan)
	eye.target = scan
	var shots := [
		# 1: the three of them with their backs to us, the creature coming; its eye sweeps over the street looking for them
		{"dur": 4.4, "from": Vector3(17, 1.65, -7), "to": Vector3(16, 1.65, -8), "title": "THE MIST HAS A SHAPE", "sub": "And it remembers you."},
		# 2: from the side: the eye finds the protagonist, meets his eyes, the beam, GET BACK INSIDE THE STORE, they run
		{"dur": 7.0, "from": GROUP + f * 5.0 + r * 15.0 + Vector3(0, 2.3, 0), "to": GROUP + f * 4.0 + r * 13.0 + Vector3(0, 2.3, 0), "fov": 62.0, "title": "", "sub": ""},
	]
	var n := 0
	var t_all := 0.0
	var run_away := false
	for si in shots.size():
		var s: Dictionary = shots[si]
		caption.text = s["title"]
		small.text = s["sub"]
		var t := 0.0
		while t < s["dur"]:
			var u := clampf(t / s["dur"], 0.0, 1.0)
			var e := u * u * (3.0 - 2.0 * u)
			camera.position = (s["from"] as Vector3).lerp(s["to"] as Vector3, e)
			var gp := GROUP + Vector3(0, 1.6, 0)
			var lk := colossus.global_position + Vector3(0, 5.5, 0)
			if si == 1:
				lk = gp.lerp(eye.eye_world_pos(), 0.5)
			camera.look_at(lk, Vector3.UP)
			camera.fov = float(s.get("fov", 68.0))
			if not run_away:
				colossus.global_position = START + (Vector3(GROUP.x, 0.15, GROUP.z) - START).normalized() * 0.72 * t_all
			_set_look()
			if si == 0:
				# scanning: the eye sweeps slowly along the three of them
				scan.global_position = GROUP + r * (2.4 * sin(t * 1.1)) + Vector3(0, 1.5, 0)
			else:
				var sw := clampf(t / 1.4, 0.0, 1.0)                    # the sweep slows and settles on the protagonist's face
				scan.global_position = (GROUP + r * (2.4 * sin(4.4 * 1.1 + t * 1.1) * (1.0 - sw)) + Vector3(0, 1.5, 0)).lerp(_head("Protagonist"), sw)
				if t >= 0.3 and t < 0.3 + DT:
					cast["Protagonist"]["face"].expression = "scared"
					cast["Protagonist"]["anim"].set_mood("scared")
					cast["Eddie"]["face"].expression = "scared"
					cast["Eddie"]["anim"].set_mood("scared")
					cast["Marcus"]["face"].expression = "worried"
				if t >= 1.6 and t < 1.6 + DT:
					eye.beam_on = true                                   # it has found his eyes
				if t >= 2.9 and t < 2.9 + DT:
					caption.text = "GET BACK INSIDE THE STORE"
					caption.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
					cast["Marcus"]["face"].expression = "scared"
					cast["Marcus"]["anim"].set_mood("scared")
				if t >= 3.5 and t < 3.5 + DT:
					for nm in cast:
						var h: Node3D = cast[nm]["holder"]
						var away := h.global_position - f * 14.0 + r * (0.6 if nm == "Eddie" else -0.6 if nm == "Marcus" else 0.0)
						cast[nm]["anim"].walk_to([away], 4.8)
				if t >= 5.2:
					eye.beam_on = false
			var a := 1.0 - clampf(t / 0.6, 0.0, 1.0) if si == 0 else 0.0
			if u > 0.93:
				a = maxf(a, (u - 0.93) / 0.07)
			fade.color.a = a
			caption.modulate.a = minf(1.0, t / 0.6) if si == 0 or t > 2.9 else (0.0 if si == 1 else 1.0)
			small.modulate.a = caption.modulate.a
			await get_tree().process_frame
			if n % 2 == 0 and out != "":
				await _frame(n / 2)
			n += 1
			t += DT
			t_all += DT
	get_tree().quit()
