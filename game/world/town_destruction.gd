extends Node
class_name VeilTownDestruction
## THE VEIL - the town after the two hours in the stock room (p3_two_hours_later): some houses stand broken.
## Nine houses that are not explorable, not lootable and not used by any scene swap to damaged models built from
## their own house type (game/tools/build_destroyed_houses.gd -> game/world/destroyed/<HOUSE>.glb):
##   colossus      HOUSE_14      crushed from above, walls splayed, a three-toed print in the yard
##   skitter       HOUSE_18, EXT_HOUSE_12   panes gone, torn roof, dark inside; a Skitter moves behind the glass
##   tentacle      HOUSE_09      the garage wall burst open, the door on the drive, the ground ruptured, a dead tentacle
##   hound         EXT_HOUSE_19  front door broken in and flat in the hall, claw marks, a few stains, furniture tipped
##   shellcrawler  HOUSE_17      a corner caved in, the foundation cracked, scrapes on the drive, the fence flattened
##   evacuation    HOUSE_11, EXT_HOUSE_29, EXT_HOUSE_02   door left open, boards on a window, belongings, a car left
## The original house is never deleted or moved: it is hidden (and its collision switched off) and the damaged
## model stands on the same spot with the house's own materials (restored by name) and collision built from the
## damaged meshes. Rubble that would land on a road, sidewalk or near anything the player can use is left out.
## Pure function of the story flag: nothing is saved, nothing duplicates on a reload, nothing before the skip.

const DIR := "res://game/world/destroyed/"
const FLAG := "p3_two_hours_later"
const TARGETS := {
	"HOUSE_14": "colossus", "HOUSE_18": "skitter", "EXT_HOUSE_12": "skitter", "HOUSE_09": "tentacle",
	"EXT_HOUSE_19": "hound", "HOUSE_17": "shellcrawler", "HOUSE_11": "evacuation", "EXT_HOUSE_29": "evacuation",
	"EXT_HOUSE_02": "evacuation"}
## the kinds whose furniture is part of the damaged model (crushed / sagged / dark); the others keep the original
const OWN_FURNITURE := ["colossus", "shellcrawler", "skitter"]
const ABN := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Abandoned_Props/"
const CORR := "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Corruption/"
const SKITTER := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_Skitter.tscn"
const TENTACLE := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Large.tscn"
const CAR := "res://THE_VEIL_ASSETS_V2/05_Vehicles/Abandoned_Variants/VEH_Sedan_Dusty.glb"
const MARKS := ["Print_", "Claw_", "Stain_", "Crack_", "Scrape_", "Residue"]

var world: Node
var applied := false
var report := {}                       ## tests: per house what was done
var skitters: Array = []               ## [{node, a, b, t, wait}]
var _t := 0.0


func setup(w: Node) -> void:
	world = w
	for i in 2:
		await get_tree().process_frame
	if Game.has_flag(FLAG):
		apply()


func _process(delta: float) -> void:
	if world == null:
		return
	if not applied:
		_t -= delta
		if _t <= 0.0:
			_t = 0.5
			if Game.has_flag(FLAG):
				apply()
		return
	_skitter_tick(delta)


func apply() -> void:
	if applied:
		return
	applied = true
	var hn := world.get_node_or_null("Residential/Houses")
	if hn == null:
		return
	var avoid := _avoid_points()
	for id in TARGETS:
		var h := hn.get_node_or_null(String(id)) as Node3D
		if h == null or h.get_node_or_null("Destroyed") != null:
			continue
		var r := _swap(h, String(TARGETS[id]), avoid)
		report[id] = r


# ------------------------------------------------------------------ the swap
func _swap(h: Node3D, kind: String, avoid: Array) -> Dictionary:
	var r := {"kind": kind}
	var path := DIR + String(h.name) + ".glb"
	if not ResourceLoader.exists(path):
		r["missing"] = true
		return r
	# the house's own materials, by name (doors and furniture included)
	var mats := {}
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for i in m.get_surface_count():
			var mt := m.surface_get_material(i)
			if mt and not mats.has(String(mt.resource_name)):
				mats[String(mt.resource_name)] = mt
	var meta: Dictionary = h.get_meta("veil_house", {})
	var ext := h.find_child("*_Exterior", true, false) as MeshInstance3D
	var box: AABB = (h.global_transform.affine_inverse() * ext.global_transform) * ext.mesh.get_aabb() if ext else AABB()
	# hide the intact house (kept, untouched in place) and switch its collision off
	var hide: Array = [h.get_node_or_null("House")]
	if kind in OWN_FURNITURE:
		hide.append(h.get_node_or_null("Furnishing"))
	for n in hide:
		if n == null:
			continue
		(n as Node3D).visible = false
		for co in (n as Node).find_children("*", "CollisionObject3D", true, false):
			(co as CollisionObject3D).collision_layer = 0
			(co as CollisionObject3D).collision_mask = 0
	var d := (load(path) as PackedScene).instantiate() as Node3D
	d.name = "Destroyed"
	h.add_child(d)
	var body := StaticBody3D.new()
	body.name = "DestroyedCol"
	body.collision_layer = 1
	body.collision_mask = 0
	h.add_child(body)
	var dropped := 0
	var meshes := 0
	for mi in d.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		var nm := String(m3.name)
		for i in m3.mesh.get_surface_count():
			var mt := m3.mesh.surface_get_material(i)
			if mt and mats.has(String(mt.resource_name)):
				m3.set_surface_override_material(i, mats[String(mt.resource_name)])
		if MARKS.any(func(k): return nm.begins_with(k)):
			m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue                                     # stains, prints, scrapes: no collision
		if nm.begins_with("Debris") or nm.begins_with("Board"):
			if _bad_spot(m3.global_position, avoid):
				m3.queue_free()                          # never on a road / sidewalk or by something to use
				dropped += 1
				continue
			var cs := CollisionShape3D.new()
			cs.shape = m3.mesh.create_convex_shape(true, true)
			cs.transform = h.global_transform.affine_inverse() * m3.global_transform
			body.add_child(cs)
			continue
		var tm := m3.mesh.create_trimesh_shape()
		if tm:
			var cs2 := CollisionShape3D.new()
			cs2.shape = tm
			cs2.transform = h.global_transform.affine_inverse() * m3.global_transform
			body.add_child(cs2)
			meshes += 1
	r["dropped_debris"] = dropped
	r["collision_meshes"] = meshes
	match kind:
		"colossus": _dress_colossus(h, box, r)
		"skitter": _dress_skitter(h, box, meta, r)
		"tentacle": _dress_tentacle(h, meta, box, r)
		"hound": _dress_hound(h, meta, r)
		"shellcrawler": _dress_shellcrawler(h, box, r)
		"evacuation": _dress_evacuation(h, meta, box, r)
	return r


## Everything the player must reach or walk: interactables, quest / supply props.
func _avoid_points() -> Array:
	var out: Array = []
	for it in world.find_children("*", "Interactable", true, false):
		out.append((it as Node3D).global_position)
	for n in world.find_children("EXP_*", "Node3D", true, false):
		out.append((n as Node3D).global_position)
	return out


func _bad_spot(p: Vector3, avoid: Array) -> bool:
	if _paved(p):
		return true
	for a in avoid:
		if Vector2(p.x - a.x, p.z - a.z).length() < 2.2:
			return true
	return false


func _paved(p: Vector3) -> bool:
	var h := _ray_down(p)
	if h.is_empty():
		return false
	var n := String((h["collider"] as Node).name)
	return n.begins_with("RD_") or n.begins_with("SW_")


func _ray_down(p: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = (world.get_world_3d() as World3D).direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p - Vector3.UP * 3.0, 1)
	var ex: Array[RID] = [world.player.get_rid()]
	q.exclude = ex
	return space.intersect_ray(q)


## A prop from the asset packs, on the ground at house-local `at` (never on a road / sidewalk).
func _prop(h: Node3D, path: String, at: Vector3, yaw := 0.0, scale := 1.0, allow_paved := false) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var g: Vector3 = h.global_transform * at
	if not allow_paved and _paved(g):
		return null
	var hit := _ray_down(g + Vector3.UP * 1.0)
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.name = "Dress_" + path.get_file().get_basename()
	h.add_child(n)
	n.global_transform = Transform3D(Basis(Vector3.UP, h.global_rotation.y + yaw).scaled(Vector3.ONE * scale),
		Vector3(g.x, (hit["position"] as Vector3).y + 0.01 if hit else g.y, g.z))
	for co in n.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0          # dressing: nothing to snag on
	return n


func _door_center(meta: Dictionary, name: String) -> Vector3:
	for dd in meta.get("doors", []):
		if String(dd.get("name", "")) == name:
			var c: Array = dd["center"]
			return Vector3(c[0], c[1], c[2])
	return Vector3.INF


# ------------------------------------------------------------------ dressing per kind
func _dress_colossus(h: Node3D, box: AABB, r: Dictionary) -> void:
	var px := Vector3(box.position.x - 3.0, 0.0, box.get_center().z - 1.0)
	_prop(h, CORR + "CORR_Ground_Discoloration.glb", px, 0.3, 1.6)
	_prop(h, CORR + "CORR_Asphalt_Cracks_A.glb", Vector3(box.get_center().x, 0.0, box.position.z - 3.5), 0.2, 1.0, true)
	_prop(h, CORR + "CORR_Asphalt_Cracks_B.glb", Vector3(box.position.x - 1.0, 0.0, box.position.z - 2.5), 1.1, 1.0, true)
	r["dressed"] = true


func _dress_skitter(h: Node3D, box: AABB, meta: Dictionary, r: Dictionary) -> void:
	_prop(h, CORR + "CORR_Organic_Growth.glb", Vector3(box.position.x + 1.0, 0.0, box.position.z + 0.6), 0.0, 1.0)
	_prop(h, CORR + "CORR_Withered_Grass_Patch.glb", Vector3(box.get_center().x, 0.0, box.position.z - 1.5), 0.6, 1.2)
	# one Skitter inside, moving now and then behind the broken front panes (a look only: no AI, no collision)
	var room := Rect2()
	for rm in meta.get("rooms", []):
		if String(rm.get("type", "")) == "living":
			var a: Array = rm["rect"]
			room = Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1])
	if room.size == Vector2.ZERO:
		return
	var floor_y := 0.6
	for rm in meta.get("rooms", []):
		if String(rm.get("type", "")) == "living":
			floor_y = float(rm.get("floor_y", 0.6))
	var a0 := Vector3(room.position.x + 0.8, floor_y, room.position.y + 0.7)
	var b0 := Vector3(room.end.x - 0.8, floor_y, room.position.y + 0.9)
	var sk := (load(SKITTER) as PackedScene).instantiate() as Node3D
	sk.name = "Dress_Skitter"
	h.add_child(sk)
	for co in sk.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
		(co as CollisionObject3D).collision_mask = 0
	if sk is CollisionObject3D:
		(sk as CollisionObject3D).collision_layer = 0
		(sk as CollisionObject3D).collision_mask = 0
	sk.set_physics_process(false)
	sk.position = a0
	VeilCreatureLook.apply_skitter(sk, (h.global_transform * a0).y)
	sk.scale = sk.scale * 0.8
	skitters.append({"node": sk, "a": a0, "b": b0, "t": 0.0, "wait": randf_range(1.0, 4.0), "to_b": true})
	r["skitters"] = 1


func _skitter_tick(delta: float) -> void:
	var p: Vector3 = world.player.global_position
	for s in skitters:
		var sk: Node3D = s["node"]
		if not is_instance_valid(sk):
			continue
		if sk.global_position.distance_to(p) > 70.0:
			continue                                     # nobody to see it: nothing to do
		if float(s["wait"]) > 0.0:
			s["wait"] = float(s["wait"]) - delta
			VeilCreatureLook.skitter_anim(sk, "idle")
			continue
		var to: Vector3 = s["b"] if s["to_b"] else s["a"]
		var step := sk.position.move_toward(to, 0.9 * delta)
		var dir := to - sk.position
		if dir.length() > 0.02:
			sk.rotation.y = atan2(dir.x, dir.z)
		sk.position = step
		VeilCreatureLook.skitter_anim(sk, "crawl", 0.9)
		if sk.position.distance_to(to) < 0.03:
			s["to_b"] = not s["to_b"]
			s["wait"] = randf_range(2.5, 7.0)              # a long still spell: a shape that moved, then didn't


func _dress_tentacle(h: Node3D, meta: Dictionary, box: AABB, r: Dictionary) -> void:
	var gd := _door_center(meta, "INT_GarageDoor_Garage")
	var c := gd + Vector3(0, 1.2, 0) if gd.is_finite() else Vector3(box.end.x - 2.5, 1.2, box.position.z)
	var root_l := Vector3(c.x, 0.0, c.z - 3.4)
	var root_g: Vector3 = h.global_transform * root_l
	var hit := _ray_down(root_g + Vector3.UP)
	if hit:
		root_g.y = (hit["position"] as Vector3).y
	VeilTentacleMound.make(h, root_g, hash(h.name), 1.0)
	_prop(h, CORR + "CORR_Asphalt_Cracks_B.glb", Vector3(c.x - 1.0, 0.0, c.z - 5.0), 0.4, 1.0, true)
	_prop(h, CORR + "CORR_Organic_Growth_Small.glb", Vector3(c.x + 1.4, 0.0, c.z - 0.6), 0.0, 1.0)
	# the tentacle that did it: still, half out of the ground, its end through the hole (no animation, no AI)
	var t := (load(TENTACLE) as PackedScene).instantiate() as Node3D
	t.name = "Dress_DeadTentacle"
	t.set("autoplay", "")
	h.add_child(t)
	var ap := t.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.stop()
	t.set_process(false)
	var mats = t.get("_mats")
	if mats is Array:
		for m in mats:
			if m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter("mist_level", -50.0)
				(m as ShaderMaterial).set_shader_parameter("fade_height", 0.05)
	var dir := ((h.global_transform * c) - root_g).normalized()
	var y := dir
	var x := y.cross(Vector3.UP).normalized()
	var z := x.cross(y).normalized()
	t.global_transform = Transform3D(Basis(x, y, z).scaled(Vector3.ONE * 0.55), root_g - dir * 0.6)
	var po := VeilTentaclePoser.attach(t)
	if po:
		po.straight = true
		po.set_split(4, 0.0, 0.0, 0.08, 0.12)
		po.apply()
	for co in t.find_children("*", "CollisionObject3D", true, false):
		(co as CollisionObject3D).collision_layer = 0
	r["tentacle"] = true


func _dress_hound(h: Node3D, meta: Dictionary, r: Dictionary) -> void:
	var fd := _door_center(meta, "INT_Door_Front")
	if not fd.is_finite():
		return
	_prop(h, ABN + "ABN_DisplacedFurniture.tscn", Vector3(fd.x + 0.4, fd.y, fd.z + 2.4), 0.7)
	_prop(h, ABN + "ABN_ScatteredPapers.glb", Vector3(fd.x - 0.6, fd.y, fd.z - 1.2), 0.2)
	r["dressed"] = true


func _dress_shellcrawler(h: Node3D, box: AABB, r: Dictionary) -> void:
	var corner := Vector3(box.end.x, 0.0, box.position.z)
	_prop(h, CORR + "CORR_Asphalt_Cracks_A.glb", corner + Vector3(-1.0, 0.0, -4.0), 0.9, 1.0, true)
	r["fences_down"] = _knock_fences(h, 10.0, 3)


func _dress_evacuation(h: Node3D, meta: Dictionary, box: AABB, r: Dictionary) -> void:
	var fd := _door_center(meta, "INT_Door_Front")
	if not fd.is_finite():
		fd = Vector3(box.get_center().x, 0.6, box.position.z)
	_prop(h, ABN + "ABN_PersonalBelongings.tscn", Vector3(fd.x + 1.0, 0.0, fd.z - 2.2), 0.4)
	_prop(h, ABN + "ABN_EmptyBarricade.tscn", Vector3(fd.x - 1.8, 0.0, fd.z - 1.4), 0.2)
	_prop(h, ABN + "ABN_ScatteredPapers.glb", Vector3(fd.x + 0.2, 0.0, fd.z - 3.4), 1.0)
	_prop(h, "res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Abandoned_Props/ABN_FallenBicycle.glb", Vector3(fd.x - 2.6, 0.0, fd.z - 3.6), 0.9)
	r["fences_down"] = _knock_fences(h, 9.0, 2)
	if String(h.name) == "EXT_HOUSE_02":
		r["car"] = _left_car(h)


## The nearest fence panels (not hedges), pushed over flat where they stood.
func _knock_fences(h: Node3D, within: float, n: int) -> int:
	var c := h.global_position
	var near: Array = []
	for f in world.find_children("FN_*", "Node3D", true, false):
		var nm := String(f.name)
		if nm.contains("Hedge") or nm.contains("Post") or String(f.get_parent().name).begins_with("FN_"):
			continue
		var d := (f as Node3D).global_position.distance_to(c)
		if d < within:
			near.append([d, f])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var k := 0
	for e in near.slice(0, n):
		var f: Node3D = e[1]
		f.rotate_object_local(Vector3.RIGHT, -1.45 if k % 2 == 0 else 1.45)
		f.position.y += 0.08
		k += 1
	return k


## A car left on the house's own driveway (never on the road).
func _left_car(h: Node3D) -> bool:
	if not ResourceLoader.exists(CAR):
		return false
	var best: Node3D = null
	var bd := 16.0
	for dw in world.find_children("RD_Driveway*", "Node3D", true, false):
		if String(dw.get_parent().name).begins_with("RD_"):
			continue
		var d := (dw as Node3D).global_position.distance_to(h.global_position)
		if d < bd:
			bd = d
			best = dw
	if best == null:
		return false
	var a: AABB = best.global_transform * Interactable.aabb_of(best)
	var car := (load(CAR) as PackedScene).instantiate() as Node3D
	car.name = "Dress_LeftCar"
	h.add_child(car)
	var along_z := a.size.z >= a.size.x
	var at := a.get_center()
	at.y = a.end.y
	car.global_transform = Transform3D(Basis(Vector3.UP, 0.0 if along_z else PI * 0.5) * Basis(Vector3.UP, 0.12), at)
	var cb := Interactable.aabb_of(car)
	var body := StaticBody3D.new()
	body.name = "LeftCarCol"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = cb.size * Vector3(0.9, 0.8, 0.95)
	cs.shape = bs
	cs.position = cb.get_center()
	body.add_child(cs)
	car.add_child(body)
	return true
