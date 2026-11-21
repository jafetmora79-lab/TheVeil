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
## Places the story builds out in the woods (the closed district, the station, the fields and road of the finale): no forest grows there.
## Rect2(x, z, width, depth) in world metres.
const STORY_CLEAR := [Rect2(-147.0, 26.0, 44.0, 84.0),        # the closed public-works district (chapter 14)
	Rect2(-92.0, -40.0, 24.0, 24.0),                         # the maintenance station and its yard
	Rect2(-100.0, -26.0, 26.0, 38.0),                        # the road past the mill-worker house
	Rect2(-130.0, -6.0, 32.0, 40.0),                         # the fields the Colossus crosses (finale)
	Rect2(-110.0, 24.0, 22.0, 40.0),                         # the escape across the fence and the safe spot (chapter 15)
	Rect2(-150.0, -118.0, 72.0, 78.0)]                       # the campsite, the farm field and the fields beyond the town
var _tree_chunks := {}                   ## chunk -> the trees in it (so a giant foot can knock some down)
var _models := {}                        ## model name -> scene path


func _ready() -> void:
	var f := FileAccess.open(data_path, FileAccess.READ)
	if f == null:
		push_error("scatter data missing")
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var y: float = d.get("y", 0.15)
	_models = d.get("models", {})
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
		var xs_entries: Array = []
		var cells := {}
		var cell_entries := {}
		var is_tree: bool = m.begins_with("VG_Tree")
		for it in by_model[m]:
			var t := Transform3D(Basis(Vector3.UP, it[3]), Vector3(it[1], y, it[2]))
			var e := {"model": m, "x": float(it[1]), "z": float(it[2]), "yaw": float(it[3]), "hides": [], "cols": [], "alive": true}
			if it.size() < 5:                         # (the deep-forest fill has a 5th field: no collision, the world edge keeps the player out)
				xs.append(t)
				xs_entries.append(e)
			var key := Vector2i(floori(it[1] / CHUNK), floori(it[2] / CHUNK))
			cells.get_or_add(key, []).append(t)
			cell_entries.get_or_add(key, []).append(e)
			if is_tree:
				_tree_chunks.get_or_add(key, []).append(e)
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
				if is_tree:
					var ce: Array = cell_entries[key]
					for i in list.size():
						(ce[i]["hides"] as Array).append([mm, i])
		var shapes: Array = []
		for cs in inst.find_children("*", "CollisionShape3D", true, false):
			shapes.append([(cs as CollisionShape3D).shape, _rel(inst, cs)])
		if not shapes.is_empty():
			var sb := StaticBody3D.new()
			sb.name = m + "_Collision"
			add_child(sb)
			for xi in xs.size():
				for s in shapes:
					var c := CollisionShape3D.new()
					c.shape = s[0]
					c.transform = xs[xi] * s[1]
					sb.add_child(c)
					(xs_entries[xi]["cols"] as Array).append(c)
		inst.free()
	for r in STORY_CLEAR:
		clear_rect(r)


const SWAY_SHADER := "res://game/world/tree_sway.gdshader"
const FILTERS := ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
static var _sway_shaders := {}
static var _wind_added := false


## The trees and the grass move in the wind: each surface's StandardMaterial3D becomes a ShaderMaterial with the same texture (tree_sway.gdshader).
## `bend_k` > 0 overrides the bend for low plants (they lean further, relative to their height).
func _make_sway(mesh: Mesh, bend_k: float) -> void:
	if mesh == null:
		return
	if not _wind_added:                                       # (once: the list of globals can only be read in the editor)
		_wind_added = true
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


## A giant foot comes down at `centre`: every tree whose trunk stands within `radius` is taken out of the forest (its instance is
## scaled to nothing and its collision switched off). Returns what was removed ({model, scene, pos, yaw}) so the caller can lay the trunk down.
func knock_trees(centre: Vector3, radius: float) -> Array:
	var out: Array = []
	var k0 := Vector2i(floori((centre.x - radius) / CHUNK), floori((centre.z - radius) / CHUNK))
	var k1 := Vector2i(floori((centre.x + radius) / CHUNK), floori((centre.z + radius) / CHUNK))
	for kx in range(k0.x, k1.x + 1):
		for kz in range(k0.y, k1.y + 1):
			for e in _tree_chunks.get(Vector2i(kx, kz), []):
				if not e["alive"] or Vector2(e["x"] - centre.x, e["z"] - centre.z).length() > radius:
					continue
				e["alive"] = false
				for h in e["hides"]:
					(h[0] as MultiMesh).set_instance_transform(h[1], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				for c in e["cols"]:
					if is_instance_valid(c):
						(c as CollisionShape3D).set_deferred("disabled", true)
				out.append({"model": e["model"], "scene": _models.get(e["model"], ""), "pos": Vector3(e["x"], centre.y, e["z"]), "yaw": e["yaw"]})
	return out


## Takes every tree standing inside `r` (x, z, width, depth) out of the forest (instances hidden, collision off). Returns how many.
func clear_rect(r: Rect2) -> int:
	var n := 0
	for key in _tree_chunks:
		for e in _tree_chunks[key]:
			if not e["alive"] or not r.has_point(Vector2(e["x"], e["z"])):
				continue
			e["alive"] = false
			n += 1
			for h in e["hides"]:
				(h[0] as MultiMesh).set_instance_transform(h[1], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			for c in e["cols"]:
				if is_instance_valid(c):
					(c as CollisionShape3D).set_deferred("disabled", true)
	return n
