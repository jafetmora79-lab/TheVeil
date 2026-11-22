extends RefCounted
## One of the supermarket's shelf aisles (a gondola) made movable for the story (review note: "move the products aisle next to the door to close the door"). The building bakes its gondolas into one
## furnishing mesh with one collision; this cuts the chosen gondola out of both (triangles whose centre lies in its box), lifts its products off the shelves (StoreMerch.detach_region) and returns a
## real prop: the same gondola model, its products as MultiMeshes and a box collider, standing exactly where the original stood. Done once per session.
const GONDOLA := preload("res://THE_VEIL_ASSETS_V2/04_Commercial/Shared_Props/COM_Gondola_Shelf.glb")
const LENGTH := 4.24
const FURN_MESH := "Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Mesh"
const FURN_COL := "Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Col"


## center: market-local floor point of the gondola (x -11.5 + 3k, z 10.0 in the supermarket plan); yaw_deg 90 = long side along z.
static func detach(market: Node3D, center: Vector3, yaw_deg: float) -> Node3D:
	if market.has_meta("aisle_prop") and is_instance_valid(market.get_meta("aisle_prop")):
		return market.get_meta("aisle_prop")
	var half := Vector3(0.62, 1.0, LENGTH * 0.5 + 0.1)              # long axis along z at 90 degrees
	var box := AABB(center + Vector3(-half.x, -0.1, -half.z), Vector3(half.x * 2.0, 2.2, half.z * 2.0))
	_cut_mesh(market, box)
	_cut_collision(market, box)
	var prop := Node3D.new()
	prop.name = "C8_Aisle"
	market.add_child(prop)
	prop.position = center
	prop.rotation_degrees.y = yaw_deg
	var g := GONDOLA.instantiate() as Node3D
	prop.add_child(g)
	for co in g.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0                  # the box below is the only collider
		(co as CollisionObject3D).collision_mask = 0
	var body := StaticBody3D.new()
	body.name = "AisleBody"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LENGTH, 1.8, 1.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	prop.add_child(body)
	var merch := market.get_node_or_null("Merchandise")
	if merch != null and merch.has_method("detach_region"):
		var by: Dictionary = {}
		for r in merch.detach_region(box):
			if not by.has(r[0]):
				by[r[0]] = []
			by[r[0]].append(r[1])
		var inv := prop.global_transform.affine_inverse()
		for v in by.keys():
			var mesh: Mesh = merch.meshes.get(v)
			if mesh == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			var arr: Array = by[v]
			mm.instance_count = arr.size()
			for i in arr.size():
				mm.set_instance_transform(i, inv * merch.global_transform * (arr[i] as Transform3D))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			prop.add_child(mmi)
	market.set_meta("aisle_prop", prop)
	return prop


static func _cut_mesh(market: Node3D, box: AABB) -> void:
	var mi := market.get_node_or_null(FURN_MESH) as MeshInstance3D
	if mi == null or not (mi.mesh is ArrayMesh):
		return
	var src := mi.mesh as ArrayMesh
	var to_market := market.global_transform.affine_inverse() * mi.global_transform
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(v.size())
			for i in v.size():
				idx[i] = i
		var keep := PackedInt32Array()
		for t in idx.size() / 3:
			var a := to_market * v[idx[t * 3]]
			var b := to_market * v[idx[t * 3 + 1]]
			var c := to_market * v[idx[t * 3 + 2]]
			if box.has_point((a + b + c) / 3.0):
				continue
			keep.append(idx[t * 3])
			keep.append(idx[t * 3 + 1])
			keep.append(idx[t * 3 + 2])
		arr[Mesh.ARRAY_INDEX] = keep
		if keep.is_empty():
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	mi.mesh = out


static func _cut_collision(market: Node3D, box: AABB) -> void:
	var col := market.get_node_or_null(FURN_COL) as StaticBody3D
	if col == null:
		return
	for c in col.get_children():
		var cs := c as CollisionShape3D
		if cs == null or not (cs.shape is ConcavePolygonShape3D):
			continue
		var to_market := market.global_transform.affine_inverse() * cs.global_transform
		var f := (cs.shape as ConcavePolygonShape3D).get_faces()
		var keep := PackedVector3Array()
		for t in f.size() / 3:
			var cen := (to_market * f[t * 3] + to_market * f[t * 3 + 1] + to_market * f[t * 3 + 2]) / 3.0
			if box.has_point(cen):
				continue
			keep.append(f[t * 3])
			keep.append(f[t * 3 + 1])
			keep.append(f[t * 3 + 2])
		var ns := ConcavePolygonShape3D.new()
		ns.set_faces(keep)
		cs.shape = ns
