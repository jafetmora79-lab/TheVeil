extends RefCounted
## The gas station and the two clothing stores, furnished and lootable (review notes #42 / #43: "give inside assets to this place and make it lootable ... find a few bullets and food and
## water", "stuff inside like a clothing store and the one next to it also clothing store"). The pack buildings have an empty shell inside; props from Blender
## (game/tools/blender/make_store_props.py, plus the supermarket's drinks fridge) are placed along the walls, and a few finds sit on shelf tops, counters and tables as ordinary pickups
## (saved through their state keys, so a taken item stays taken). Placements are checked against the physics world: a prop that would land in something solid is nudged or skipped.
const DIR := "res://game/prototypes/store_props/"
const FRIDGE := "res://game/prototypes/market_props/MKT_WallFridge_drinks.glb"

## node under Commercial -> {"props": [[file, Vector3 (building-local), yaw degrees]], "loot": [[item, Vector3 (building-local)]]}
const SPEC := {
	"GAS_STATION": {
		"props": [["ST_Shelf.glb", Vector3(-4.8, 0, 4.3), 0], ["ST_Shelf.glb", Vector3(-3.2, 0, 4.3), 0], ["ST_Shelf.glb", Vector3(-1.6, 0, 4.3), 0],
			["ST_Shelf.glb", Vector3(-4.8, 0, 6.3), 0], ["ST_Shelf.glb", Vector3(-3.2, 0, 6.3), 0], ["ST_Shelf.glb", Vector3(-1.6, 0, 6.3), 0],
			["ST_Counter.glb", Vector3(-1.0, 0, 2.2), 180], ["FRIDGE", Vector3(-6.95, 0, 3.0), 90], ["FRIDGE", Vector3(-6.95, 0, 5.5), 90]],
		"loot": [["handgun_rounds", Vector3(-1.0, 1.1, 2.2)], ["energy_snack", Vector3(-0.55, 1.1, 2.2)], ["canned_food", Vector3(-4.8, 1.6, 4.3)], ["water_bottle", Vector3(-3.2, 1.6, 4.3)],
			["handgun_round", Vector3(-1.6, 1.6, 6.3)], ["cola_bottle", Vector3(-3.2, 1.6, 6.3)], ["chocolate_bar", Vector3(-4.8, 1.6, 6.3)]],
	},
	"STOREFRONT_A": {
		"props": [["ST_ClothesRack.glb", Vector3(-3.8, 0, 3.2), 0], ["ST_ClothesRack.glb", Vector3(-1.6, 0, 3.2), 0], ["ST_ClothesRack.glb", Vector3(0.6, 0, 3.2), 0],
			["ST_ClothesRack.glb", Vector3(-3.8, 0, 5.4), 0], ["ST_ClothesRack.glb", Vector3(-1.6, 0, 5.4), 0], ["ST_FoldTable.glb", Vector3(3.2, 0, 4.0), 0],
			["ST_FoldTable.glb", Vector3(2.4, 0, 6.2), 0], ["ST_Counter.glb", Vector3(1.0, 0, 1.8), 180], ["ST_ShoeShelf.glb", Vector3(-5.7, 0, 6.5), 90]],
		"loot": [["painkillers", Vector3(1.0, 1.1, 1.8)], ["batteries", Vector3(3.2, 0.95, 4.0)], ["duct_tape", Vector3(2.4, 0.95, 6.2)]],
	},
	"STOREFRONT_B": {
		"props": [["ST_ClothesRack.glb", Vector3(-5.5, 0, 3.2), 0], ["ST_ClothesRack.glb", Vector3(-3.3, 0, 3.2), 0], ["ST_ClothesRack.glb", Vector3(-1.1, 0, 3.2), 0],
			["ST_ClothesRack.glb", Vector3(1.1, 0, 3.2), 0], ["ST_ClothesRack.glb", Vector3(-5.5, 0, 5.6), 0], ["ST_ClothesRack.glb", Vector3(-3.3, 0, 5.6), 0],
			["ST_ClothesRack.glb", Vector3(-1.1, 0, 5.6), 0], ["ST_FoldTable.glb", Vector3(4.2, 0, 4.0), 0], ["ST_FoldTable.glb", Vector3(5.4, 0, 6.2), 0],
			["ST_Counter.glb", Vector3(3.0, 0, 1.8), 180], ["ST_ShoeShelf.glb", Vector3(-9.2, 0, 6.5), 90]],
		"loot": [["water_bottle", Vector3(3.0, 1.1, 1.8)], ["painkillers", Vector3(4.2, 0.95, 4.0)], ["energy_snack", Vector3(5.4, 0.95, 6.2)]],
	},
}


static func apply(world: Node) -> Dictionary:
	var report := {"props": 0, "skipped": 0, "loot": 0}
	var com := world.get_node_or_null("Commercial")
	if com == null:
		return report
	for bname in SPEC:
		var b := com.get_node_or_null(bname) as Node3D
		if b == null or b.get_node_or_null("StoreInterior") != null:
			continue
		var holder := Node3D.new()
		holder.name = "StoreInterior"
		b.add_child(holder)
		var spec: Dictionary = SPEC[bname]
		for p in spec["props"]:
			var path: String = FRIDGE if String(p[0]) == "FRIDGE" else DIR + String(p[0])
			var ps := load(path) as PackedScene
			if ps == null:
				continue
			var pos: Vector3 = _free_spot(world, b, p[1], float(p[2]))
			if not pos.is_finite():
				report["skipped"] += 1
				continue
			var n := ps.instantiate() as Node3D
			n.position = pos
			n.rotation_degrees.y = float(p[2])
			holder.add_child(n)
			_glass(n)
			report["props"] += 1
		var i := 0
		for l in spec["loot"]:
			var id: String = l[0]
			var model := String(Game.item_info(id).get("model", ""))
			if model == "" or not ResourceLoader.exists(model):
				continue
			var node := Node3D.new()
			node.name = "Loot_%s_%d" % [id, i]
			holder.add_child(node)
			node.position = l[1]
			node.add_child((load(model) as PackedScene).instantiate())
			Interactable.attach(node, {"kind": "pickup", "label": String(Game.item_info(id).get("name", id)), "item_id": id, "state_key": "storeloot/%s/%d" % [bname, i]})
			report["loot"] += 1
			i += 1
	return report


## The prop's spot, or a nearby one (0.4 m steps, up to 1.2 m) where a 1.2 x 1.2 m footprint touches nothing solid; INF if there is none.
static func _free_spot(world: Node, b: Node3D, want: Vector3, yaw: float) -> Vector3:
	var space := (world as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 0.7)
	q.shape = box
	q.collision_mask = 1
	for r in [0.0, 0.4, 0.8, 1.2]:
		for k in (1 if r == 0.0 else 8):
			var a := TAU * k / 8.0
			var p: Vector3 = want + Vector3(cos(a), 0, sin(a)) * r
			q.transform = b.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), p + Vector3(0, 0.75, 0))
			if space.intersect_shape(q, 1).is_empty():
				return p
	return Vector3.INF


static func _glass(n: Node3D) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mesh := (m as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat != null and String(mat.resource_name).contains("Glass"):
				var g := StandardMaterial3D.new()
				g.albedo_color = Color(0.6, 0.8, 0.85, 0.16)
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.cull_mode = BaseMaterial3D.CULL_DISABLED
				(m as MeshInstance3D).set_surface_override_material(s, g)
