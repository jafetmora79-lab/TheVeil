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


func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p and p != root:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
