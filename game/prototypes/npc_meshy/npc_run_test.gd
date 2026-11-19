extends Node3D
## THE VEIL - the Meshy characters RUNNING scared (the game's NpcAnimator run + scared mood, and the face that follows it), all eleven side by side.
##   godot --path . --fixed-fps 24 --resolution 960x540 res://game/prototypes/npc_meshy/NpcRunTest.tscn -- frames <out_dir>
const NPC_ANIM := preload("res://game/npc/npc_animator.gd")
const SPEAKERS := ["Eddie", "Marcus", "Ruth", "Lena", "Frank", "Officer", "Cashier", "Noah", "Civilian_B", "Protagonist", "Sarah"]
const DT := 1.0 / 24.0
var out := ""
var cam: Camera3D
var people := []
var side_mode := false
var speakers: Array = SPEAKERS.duplicate()


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "frames" and i + 1 < a.size():
			out = a[i + 1]
		if a[i] == "side":
			side_mode = true
			speakers = ["Eddie", "Ruth", "Marcus", "Protagonist"]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	e.fog_enabled = true
	e.fog_light_color = Color(0.3, 0.32, 0.35)
	e.fog_density = 0.012
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	add_child(sun)
	var fl := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(80, 80)
	fl.mesh = pl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.22, 0.24)
	fm.roughness = 1.0
	fl.material_override = fm
	add_child(fl)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 42.0
	for i in speakers.size():
		var holder := Node3D.new()
		holder.name = speakers[i]
		add_child(holder)
		holder.position = Vector3(0, 0, 16.0 + float(i) * 2.4) if side_mode else Vector3((float(i) - 5.0) * 1.25, 0, 16.0)
		var model := VeilMeshyNpcs.model_for(speakers[i])
		holder.add_child(model)
		var anim: Node = NPC_ANIM.new()
		anim.name = "Animator"
		holder.add_child(anim)
		var f := VeilMeshyNpcs.face_for(model)
		f.name = "VeilFace"
		holder.add_child(f)
		anim.set_mood("scared")
		anim.walk_to([Vector3(holder.position.x, 0, -8.0)], 5.2)
		people.append({"holder": holder, "anim": anim})
	_run.call_deferred()


func _run() -> void:
	var n := 0
	var side := false
	for k in 150:
		# first 3 s: from the front (they run at the camera); then from the side as they pass
		var z0: float = (people[mini(5, people.size() - 1)]["holder"] as Node3D).position.z
		if side_mode:
			var zm: float = (people[1]["holder"] as Node3D).position.z
			cam.fov = 34.0
			cam.position = Vector3(-6.2, 1.25, zm)
			cam.look_at(Vector3(0.0, 0.95, zm), Vector3.UP)
		elif k < 70:
			cam.position = Vector3(0.0, 1.55, z0 - 7.5)
			cam.look_at(Vector3(0.0, 1.0, z0), Vector3.UP)
		else:
			cam.position = Vector3(-9.5, 1.2, z0 + 3.0)
			cam.look_at(Vector3(0.0, 0.95, z0 + 3.0), Vector3.UP)
		await get_tree().process_frame
		if k % 3 == 0 and out != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/run_%03d.png" % [out, n])
			n += 1
	get_tree().quit()
