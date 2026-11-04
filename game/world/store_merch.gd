extends Node3D
class_name StoreMerch
## THE VEIL - store merchandise (Pack 04 Merchandise): products are separate meshes, drawn as one MultiMesh per
## variant per store, so thousands of products cost a few dozen draw calls and no physics bodies or scripts.
## Only "pick groups" are interactive: one Interactable per group; taking one removes exactly one instance
## (the one nearest the player) and leaves the rest on the shelf. Taken counts are saved in Game.world_state.

signal taken(group_id: String, item_id: String)

const LIB := "res://THE_VEIL_ASSETS_V2/04_Commercial/Merchandise/COM_Merch_Library.glb"
const LAYOUT := "res://THE_VEIL_ASSETS_V2/04_Commercial/Merchandise/MERCH_LAYOUT.json"
const VIEW_RANGE := 42.0            ## products are only drawn near the store

var store_key := ""
var meshes := {}                    ## variant -> Mesh
var groups := {}                    ## group id -> {"mmi", "it", "item", "label", "normal", "count"}
var instance_count := 0
var mmi_count := 0

static var _lib_cache: Dictionary = {}
static var _layout_cache = null


static func _library() -> Dictionary:
	if _lib_cache.is_empty():
		var scene := (load(LIB) as PackedScene).instantiate()
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			_lib_cache[String(mi.name)] = (mi as MeshInstance3D).mesh
		scene.free()
	return _lib_cache


static func _layout() -> Dictionary:
	if _layout_cache == null:
		_layout_cache = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	return _layout_cache


func build(key: String) -> void:
	store_key = key
	meshes = _library()
	var lay: Dictionary = _layout().get(key, {})
	for v in lay.get("static", {}):
		_mmi("Merch_" + v, v, lay["static"][v])
	for g in lay.get("groups", []):
		var mmi := _mmi("Pick_" + g["id"], g["variant"], g["inst"])
		var area := Node3D.new()
		area.name = "PickArea_" + g["id"]
		add_child(area)
		var c: Array = g["center"]
		area.position = Vector3(c[0], c[1], c[2])
		area.rotation.y = float(g["yaw"])
		var it := Interactable.attach(area, {"kind": "custom", "label": g["label"], "prompt_text": "[E] Take " + g["label"]})
		var cs := it.get_child(0) as CollisionShape3D
		var sz: Array = g["size"]
		(cs.shape as BoxShape3D).size = Vector3(sz[0], sz[1], sz[2])
		cs.position = Vector3.ZERO
		var gid: String = g["id"]
		it.used.connect(func(by): _take(gid, by))
		var n: Array = g["normal"]
		groups[gid] = {"mmi": mmi, "it": it, "item": g["item"], "label": g["label"], "normal": Vector3(n[0], n[1], n[2]),
			"count": g["inst"].size()}
		var st: Dictionary = Game.world_state.get("merch/" + key + "/" + gid, {})
		for i in int(st.get("n", 0)):
			_remove_one(gid, Vector3.INF)


func _mmi(nm: String, variant: String, recs: Array) -> MultiMeshInstance3D:
	var mesh: Mesh = meshes.get(variant)
	if mesh == null:
		push_warning("merch variant missing: " + variant)
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = recs.size()
	for i in recs.size():
		var r: Array = recs[i]
		var b := Basis(Vector3.UP, float(r[3])) * Basis(Vector3.RIGHT, float(r[4]))
		mm.set_instance_transform(i, Transform3D(b, Vector3(r[0], r[1], r[2])))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = VIEW_RANGE
	mmi.visibility_range_end_margin = 4.0
	add_child(mmi)
	instance_count += recs.size()
	mmi_count += 1
	return mmi


## Remove the visible instance nearest `near` (store-space world position) by swapping it to the end.
func _remove_one(gid: String, near: Vector3) -> bool:
	var g: Dictionary = groups[gid]
	var mm: MultiMesh = (g["mmi"] as MultiMeshInstance3D).multimesh
	var n := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
	if n <= 0:
		return false
	var best := n - 1
	if near != Vector3.INF:
		var local := to_local(near)
		var bd := INF
		for i in n:
			var d := mm.get_instance_transform(i).origin.distance_squared_to(local)
			if d < bd:
				bd = d
				best = i
	var last := mm.get_instance_transform(n - 1)
	mm.set_instance_transform(n - 1, mm.get_instance_transform(best))
	mm.set_instance_transform(best, last)
	mm.visible_instance_count = n - 1
	if n - 1 == 0:
		(g["it"] as Interactable).prompt_text = ""
	return true


func remaining(gid: String) -> int:
	var mm: MultiMesh = (groups[gid]["mmi"] as MultiMeshInstance3D).multimesh
	return mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count


func _take(gid: String, by: Node) -> void:
	var g: Dictionary = groups[gid]
	if Game.has_item(g["item"]):
		Dialogue.say("merch_have_one", false, true)
		return
	var cam := get_viewport().get_camera_3d()
	if not _remove_one(gid, cam.global_position if cam else Vector3.INF):
		return
	var key := "merch/" + store_key + "/" + gid
	var st: Dictionary = Game.world_state.get(key, {})
	Game.world_state[key] = {"n": int(st.get("n", 0)) + 1}
	Game.add_item(g["item"])
	Sfx.play("pickup", (g["it"] as Node3D).global_position)
	taken.emit(gid, g["item"])


func set_glow(gid: String, mat: Material) -> void:
	if groups.has(gid):
		(groups[gid]["mmi"] as MultiMeshInstance3D).material_overlay = mat
