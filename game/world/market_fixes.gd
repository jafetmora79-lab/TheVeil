extends RefCounted
## The supermarket's fixtures, rebuilt in Blender (review notes #14, #15, #18: "these don't make sense, create them again"). The old wall fridges, chest freezers and produce displays are drawn
## into the pack's one merged furnishing mesh (flat atlas cubes); their triangles are cut out here (by region, market-local) and the new models stand in their place.
## Models: game/prototypes/market_props/MKT_*.glb (game/tools/blender/make_market_props.py). Their colliders are the pack's own (the footprints are the same).

const DIR := "res://game/prototypes/market_props/"
## regions (market-local, x0 x1 y0 y1 z0 z1) cut out of the furnishing mesh
const CUTS := [
	[18.9, 20.2, -0.1, 2.35, 4.2, 14.05],         # the east wall's four fridge units (glass doors, lamps)
	[-20.2, -18.9, -0.1, 2.5, 4.3, 14.15],        # the west wall's produce display (and its signs)
	[-16.9, -15.2, -0.1, 1.4, 6.2, 8.6],          # the two produce tables
	[-16.9, -15.2, -0.1, 1.4, 9.8, 12.2],
	[14.4, 15.6, -0.1, 1.05, 6.3, 8.9],           # the two chest freezers
	[14.4, 15.6, -0.1, 1.05, 9.7, 12.3],
]
const FLOOR := 0.04


static func apply(market: Node3D) -> Dictionary:
	var report := {"cut": 0, "placed": 0}
	var mi := market.get_node_or_null("Furnishing/COM_Supermarket_Furnishing/COM_Supermarket_Furnishing_Mesh") as MeshInstance3D
	if mi == null or mi.mesh == null:
		return report
	report["cut"] = _cut(mi, market)
	var root := Node3D.new()
	root.name = "RebuiltFixtures"
	market.add_child(root)
	var zi := 0
	for z in [5.5, 7.9, 10.3, 12.7]:                                  # east wall: drinks / dairy fridges, fronts to -x
		_place(root, "MKT_WallFridge_%s.glb" % ("drinks" if zi % 2 == 0 else "dairy"), Vector3(19.95, FLOOR, z), -90.0)
		zi += 1
		report["placed"] += 1
	for z in [5.6, 8.0, 10.4, 12.8]:                                  # west wall: the produce display, fronts to +x
		_place(root, "MKT_ProduceWall.glb", Vector3(-19.95, FLOOR, z), 90.0)
		report["placed"] += 1
	for z in [7.4, 11.0]:
		_place(root, "MKT_ProduceIsland.glb", Vector3(-16.05, FLOOR, z), 90.0)
		report["placed"] += 1
	for z in [7.6, 11.0]:                                             # the chest freezers: the FROZEN plate faces the aisle (+x)
		_place(root, "MKT_ChestFreezer.glb", Vector3(15.0, FLOOR, z), 90.0)
		report["placed"] += 1
	return report


static func _place(parent: Node3D, file: String, pos: Vector3, yaw_deg: float) -> void:
	var ps := load(DIR + file) as PackedScene
	if ps == null:
		return
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	for m in n.find_children("*", "MeshInstance3D", true, false):                 # the glass is glass
		var mesh := (m as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat != null and String(mat.resource_name).contains("Glass"):
				var g := StandardMaterial3D.new()
				g.albedo_color = Color(0.6, 0.8, 0.85, 0.16)
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.cull_mode = BaseMaterial3D.CULL_DISABLED
				g.roughness = 0.1
				(m as MeshInstance3D).set_surface_override_material(s, g)
			elif mat is StandardMaterial3D:
				(mat as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


static func _cut(mi: MeshInstance3D, market: Node3D, cuts := CUTS) -> int:
	var src := mi.mesh
	var out := ArrayMesh.new()
	var to_mkt: Transform3D = market.global_transform.affine_inverse() * mi.global_transform
	var removed := 0
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var mat := src.surface_get_material(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx == null or (idx as PackedInt32Array).is_empty():
			idx = PackedInt32Array(range(vs.size()))
		var keep := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			var c: Vector3 = to_mkt * ((vs[idx[t]] + vs[idx[t + 1]] + vs[idx[t + 2]]) / 3.0)
			var inside := false
			for r in cuts:
				if c.x >= r[0] and c.x <= r[1] and c.y >= r[2] and c.y <= r[3] and c.z >= r[4] and c.z <= r[5]:
					inside = true
					break
			if inside:
				removed += 1
			else:
				keep.append(idx[t]); keep.append(idx[t + 1]); keep.append(idx[t + 2])
		arr[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arr)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	mi.mesh = out
	return removed


## The game shop's display case (review note #19: seen from the other side its games were flat strips): cut out, rebuilt with game boxes facing both ways.
const SHOP_CUTS := [[0.9, 2.7, -0.1, 1.15, 2.9, 3.7]]


static func apply_shop(shop: Node3D) -> Dictionary:
	var mi := shop.get_node_or_null("Furnishing/COM_GameShop_Furnishing/COM_GameShop_Furnishing_Mesh") as MeshInstance3D
	if mi == null or mi.mesh == null:
		return {}
	var report := {"cut": _cut(mi, shop, SHOP_CUTS)}
	var root := Node3D.new()
	root.name = "RebuiltFixtures"
	shop.add_child(root)
	_place(root, "MKT_GameCase.glb", Vector3(1.8, FLOOR, 3.3), 0.0)
	return report
