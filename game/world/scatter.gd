extends Node3D
class_name VeilScatter
## Woods + undergrowth from game/world/scatter.json drawn with one MultiMeshInstance3D per model surface
## (instead of thousands of nodes or baked chunk meshes). Tree trunks get collision: one StaticBody3D per
## model holding the model's own collision shapes at every instance.

@export var data_path := "res://game/world/scatter.json"
@export var view_distance := 260.0


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
		for it in by_model[m]:
			xs.append(Transform3D(Basis(Vector3.UP, it[3]), Vector3(it[1], y, it[2])))
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var rel := _rel(inst, mi)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = (mi as MeshInstance3D).mesh
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, xs[i] * rel)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = m + "_" + mi.name
			mmi.multimesh = mm
			mmi.visibility_range_end = view_distance if m.begins_with("VG_Tree") else 70.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
