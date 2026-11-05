extends Node3D


const RUSTLE:= preload("res://game/easter_egg/tree_rustle.wav")
const INTERVAL:= 2.0
var targets: Array = []
var leaves: Array = []
var audio: AudioStreamPlayer3D
var age:= 0.0
var pulse_age:= 10.0
var next_pulse:= 0.0
var pulses:= 0
var active:= true
var restored:= false
var rng:= RandomNumberGenerator.new()

func setup(w: Node, at: Vector3, model: String) -> void :
	global_position = at
	rng.randomize()


	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/world/scatter.json"))
	var chosen: Array = []
	var nearest:= 2.0
	for item in data["items"]:
		if item[0] != model: continue
		var d:= Vector2(float(item[1]) - at.x, float(item[2]) - at.z).length()
		if d < nearest:
			nearest = d
			chosen = item
	if not chosen.is_empty():
		var cell:= Vector2i(floori(float(chosen[1]) / 96.0), floori(float(chosen[2]) / 96.0))
		var index:= 0
		for item in data["items"]:
			if item[0] != model: continue
			var item_cell:= Vector2i(floori(float(item[1]) / 96.0), floori(float(item[2]) / 96.0))
			if item_cell != cell: continue
			if item == chosen: break
			index += 1
		var scene: Node3D = load(data["models"][model]).instantiate()
		for mesh in scene.find_children("*", "MeshInstance3D", true, false):
			var relative: Transform3D = mesh.transform
			var parent:= mesh.get_parent()
			while parent != null and parent != scene:
				relative = parent.transform * relative
				parent = parent.get_parent()
			var name_to_find:= "%s_%s_%d_%d" % [model, mesh.name, cell.x, cell.y]
			var matches:= w.find_children(name_to_find, "MultiMeshInstance3D", true, false)
			for node in matches:
				var base:= Transform3D(Basis(Vector3.UP, float(chosen[3])), Vector3(float(chosen[1]), float(data.get("y", 0.15)), float(chosen[2])))
				var original: Transform3D = node.global_transform.affine_inverse() * base * relative
				targets.append({"node": node, "index": index, "original": original, "applied": original})
		scene.free()
	audio = AudioStreamPlayer3D.new()
	audio.stream = RUSTLE
	audio.volume_db = 0.0
	audio.unit_size = 22.0
	audio.max_distance = 65.0
	add_child(audio)
	audio.position.y = 3.0

func _process(delta: float) -> void :
	age += delta
	if active:
		if age >= next_pulse:
			next_pulse += INTERVAL
			pulse_age = 0.0
			pulses += 1
			audio.play()
			_drop_leaves()
		pulse_age += delta
		var envelope:= maxf(0.0, 1.0 - pulse_age / 0.65)
		var sway:= sin(pulse_age * 42.0) * 0.025 * envelope
		var tilt:= Basis(Vector3.FORWARD, sway) * Basis(Vector3.RIGHT, sway * 0.5)
		for target in targets:
			var n: MultiMeshInstance3D = target.node
			var original: Transform3D = n.global_transform * target.original
			var bent:= Transform3D(tilt * original.basis, global_position + tilt * (original.origin - global_position))
			target.applied = n.global_transform.affine_inverse() * bent
			n.multimesh.set_instance_transform(target.index, target.applied)
	for i in range(leaves.size() - 1, -1, -1):
		var leaf: Dictionary = leaves[i]
		leaf.age += delta
		var mesh: MeshInstance3D = leaf.node
		mesh.position += (leaf.velocity + Vector3(sin(leaf.age * 7.0 + leaf.phase) * 0.45, 0, 0)) * delta
		mesh.rotate_y(delta * 3.0)
		mesh.rotate_z(delta * 2.0)
		if leaf.age > 4.0:
			mesh.queue_free()
			leaves.remove_at(i)
	if not active and leaves.is_empty(): queue_free()

func _drop_leaves() -> void :
	for i in 6:
		var leaf:= MeshInstance3D.new()
		var quad:= QuadMesh.new()
		quad.size = Vector2(0.13, 0.23)
		leaf.mesh = quad
		var mat:= StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.42, 0.12) if i % 2 == 0 else Color(0.48, 0.32, 0.09)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		leaf.material_override = mat
		add_child(leaf)
		leaf.position = Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(4.0, 6.0), rng.randf_range(-1.5, 1.5))
		leaves.append({"node": leaf, "age": 0.0, "phase": rng.randf() * TAU, 
			"velocity": Vector3(rng.randf_range(-0.3, 0.3), -1.6, rng.randf_range(-0.3, 0.3))})

func stop() -> void :
	active = false
	if is_instance_valid(audio): audio.stop()
	_restore()

func _restore() -> void :
	for target in targets:
		if is_instance_valid(target.node):
			target.applied = target.original
			target.node.multimesh.set_instance_transform(target.index, target.original)
	restored = true

func _exit_tree() -> void :
	_restore()
