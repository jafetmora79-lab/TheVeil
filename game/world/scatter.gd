extends Node3D
class_name VeilScatter
## Woods + undergrowth from game/world/scatter.json drawn as MultiMeshInstance3Ds, one per model surface per
## CHUNK x CHUNK m cell, each node placed at its cell centre. Tree trunks get collision: one StaticBody3D per
## model holding the model's own collision shapes at every instance.
## Why chunks: a visibility range is judged per GeometryInstance (from the camera to that one node), so a single
## whole-map MultiMesh at the world origin made every tree of a model vanish at once whenever the road was more
## than view_distance from that point (the countryside gap on the drive). Per-cell nodes cull, and frustum-cull,
## locally.

@export var data_path := "res://game/world/scatter.json"
@export var view_distance := 420.0       ## trees (cells), well inside the 600-700 m camera far planes
@export var detail_distance := 70.0      ## undergrowth / rocks
const CHUNK := 96.0


func _ready() -> void:
	var f := FileAccess.open(data_path, FileAccess.READ)
	if f == null:
		push_error("scatter data missing")
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var y: float = d.get("y", 0.15)
	var by_model := {}
	for it in d["items"]:
		by_model.get_or_add(it[0], []).append(it)
	for m in by_model:
		var ps: PackedScene = load(d["models"][m])
		if ps == null:
			push_error("scatter model failed to load: " + m)
			continue
		var inst := ps.instantiate() as Node3D
		if m.begins_with("VG_Tree") or m in ["VG_TallGrassClump", "VG_Weeds", "VG_DeadVegetation"]:
			for smi in inst.find_children("*", "MeshInstance3D", true, false):
				_make_sway((smi as MeshInstance3D).mesh, 0.0 if m.begins_with("VG_Tree") else 0.5)
		var xs: Array = []
		var cells := {}
		for it in by_model[m]:
			var t := Transform3D(Basis(Vector3.UP, it[3]), Vector3(it[1], y, it[2]))
			xs.append(t)
			var key := Vector2i(floori(it[1] / CHUNK), floori(it[2] / CHUNK))
			cells.get_or_add(key, []).append(t)
		var is_tree: bool = m.begins_with("VG_Tree")
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var rel := _rel(inst, mi)
			for key in cells:
				var centre := Vector3((key.x + 0.5) * CHUNK, y, (key.y + 0.5) * CHUNK)
				var list: Array = cells[key]
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = (mi as MeshInstance3D).mesh
				mm.instance_count = list.size()
				for i in list.size():
					mm.set_instance_transform(i, Transform3D(list[i].basis, list[i].origin - centre) * rel)
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "%s_%s_%d_%d" % [m, mi.name, key.x, key.y]
				mmi.multimesh = mm
				mmi.position = centre
				mmi.visibility_range_end = view_distance if is_tree else detail_distance
				mmi.visibility_range_end_margin = 20.0 if is_tree else 6.0
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.set_meta("cell", [centre.x, centre.z, CHUNK, list.size()])
				add_child(mmi)
		var shapes: Array = []
		for cs in inst.find_children("*", "CollisionShape3D", true, false):
			shapes.append([(cs as CollisionShape3D).shape, _rel(inst, cs)])
		if not shapes.is_empty():
			var sb := StaticBody3D.new()
			sb.name = m + "_Collision"
			add_child(sb)
			for x in xs:
				for s in shapes:
					var c := CollisionShape3D.new()
					c.shape = s[0]
					c.transform = x * s[1]
					sb.add_child(c)
		inst.free()


const SWAY_SHADER := "res://game/world/tree_sway.gdshader"
const FILTERS := ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
static var _sway_shaders := {}


## The trees and the grass move in the wind: each surface's StandardMaterial3D becomes a ShaderMaterial with the same texture (tree_sway.gdshader).
## `bend_k` > 0 overrides the bend for low plants (they lean further, relative to their height).
func _make_sway(mesh: Mesh, bend_k: float) -> void:
	if mesh == null:
		return
	if not RenderingServer.global_shader_parameter_get_list().has(&"veil_wind"):
		RenderingServer.global_shader_parameter_add("veil_wind", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
	var h := maxf(mesh.get_aabb().size.y, 0.5)
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i) as StandardMaterial3D
		if mat == null or mat.albedo_texture == null:
			continue
		var fl: int = clampi(int(mat.texture_filter), 0, 5)
		var both := mat.cull_mode == BaseMaterial3D.CULL_DISABLED
		var key := fl * 2 + (1 if both else 0)
		if not _sway_shaders.has(key):
			var sh := Shader.new()
			sh.code = FileAccess.get_file_as_string(SWAY_SHADER).replace("FILTER_HINT", FILTERS[fl]).replace("cull_back", "cull_disabled" if both else "cull_back")
			_sway_shaders[key] = sh
		var sm := ShaderMaterial.new()
		sm.shader = _sway_shaders[key]
		sm.set_shader_parameter("albedo_tex", mat.albedo_texture)
		sm.set_shader_parameter("tint", mat.albedo_color)
		sm.set_shader_parameter("height", h)
		sm.set_shader_parameter("scissor", mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
		if bend_k > 0.0:
			sm.set_shader_parameter("bend", 0.09)
			sm.set_shader_parameter("flutter", 0.1)
		mesh.surface_set_material(i, sm)


func _process(delta: float) -> void:
	# the wind: steady on a normal evening, much stronger once the Veil is here
	var want := 2.4 if Game.has_flag("p3_mist") else 1.0
	_wind = move_toward(_wind, want, delta * 0.25)
	RenderingServer.global_shader_parameter_set("veil_wind", _wind)


var _wind := 1.0


func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p != root:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
