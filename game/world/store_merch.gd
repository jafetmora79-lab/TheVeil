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

const FOOD_DIR := "res://game/prototypes/food/"
const REACH := 2.6                  ## how far the player can take a product off a shelf
const PICK_R := 0.27                ## ... within this distance of the view line
static var _lib_cache: Dictionary = {}
static var _names = null
static var _layout_cache = null


static func _library() -> Dictionary:
	if _lib_cache.is_empty():
		var scene := (load(LIB) as PackedScene).instantiate()
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			_lib_cache[String(mi.name)] = (mi as MeshInstance3D).mesh
		scene.free()
		for v in _lib_cache.keys():                  # the supermarket's own food models (Blender, game/tools/blender/make_food_models.py) replace the pack's where we made one
			var path: String = FOOD_DIR + "FOOD_" + String(v) + ".glb"
			if ResourceLoader.exists(path):
				var fs := (load(path) as PackedScene).instantiate()
				var fm := fs.find_children("*", "MeshInstance3D", true, false)
				if not fm.is_empty():
					_lib_cache[v] = (fm[0] as MeshInstance3D).mesh
				fs.free()
	return _lib_cache


## What a product off the shelf is in the inventory: every item keeps one of the game's own ids, so food counts, the shelter and the errands all just work.
static func item_of(variant: String) -> String:
	if variant.begins_with("bottle_"):
		return "water_bottle" if variant in ["bottle_water", "bottle_sport", "bottle_tea"] else "cola_bottle"
	if variant.begins_with("candy_bar"):
		return "energy_snack"
	if variant.begins_with("choc_"):
		return "chocolate_bar"
	if variant.begins_with("bag_chips") or variant.begins_with("bag_tortilla") or variant.begins_with("box_snack") or variant.begins_with("box_cookies") or variant.begins_with("box_crackers"):
		return "energy_snack"
	return "canned_food"


## The errand kind an item counts as (the player holds one of each): "snack", "candy", "drink", or "" for anything else.
static func kind_of(item: String) -> String:
	match item:
		"energy_snack": return "snack"
		"chocolate_bar": return "candy"
		"water_bottle", "cola_bottle": return "drink"
	return ""


static func holds_kind(item: String) -> bool:
	var k := kind_of(item)
	if k == "":
		return Game.has_item(item)
	for i in Game.inventory:
		if kind_of(String(i)) == k:
			return true
	return false


static func name_of(variant: String) -> String:
	if _names == null:
		_names = JSON.parse_string(FileAccess.get_file_as_string(FOOD_DIR + "names.json"))
	return String(_names.get(variant, variant.replace("_", " ").capitalize()))


static func _layout() -> Dictionary:
	if _layout_cache == null:
		_layout_cache = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	return _layout_cache


func build(key: String) -> void:
	store_key = key
	meshes = _library()
	var lay: Dictionary = _layout().get(key, {})
	for v in lay.get("static", {}):
		var sm := _mmi("Merch_" + v, v, lay["static"][v])
		if sm != null:
			var ps := PackedVector3Array()
			for r in lay["static"][v]:
				ps.append(Vector3(r[0], r[1], r[2]))
			_pos[v] = ps
			_mm_of[v] = sm
			for i in ps.size():                                         # a 1 m grid of the products: the aim search only looks at the cells near the eye (review note #46: a scan of every product was a hitch)
				var cell := Vector3i(floori(ps[i].x), floori(ps[i].y), floori(ps[i].z))
				if not _cells.has(cell):
					_cells[cell] = []
				(_cells[cell] as Array).append([v, i])
	for gone in Game.world_state.get("merch/" + key + "/_free", []):
		_hide_static(String(gone).get_slice(":", 0), int(String(gone).get_slice(":", 1)))
	_make_picker()
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


## The raid (two hours after the Veil): most essentials are gone and whole shelf runs are empty, a few products
## lie on the floor; the rest stays. Deterministic per instance (a load looks the same) and done only once.
## Interactive pick groups are left alone.
var looted := false
var looted_hidden := 0
var _pos := {}                      ## static variant -> PackedVector3Array of the instances' positions (store space)
var _mm_of := {}                    ## static variant -> its MultiMeshInstance3D
var _cells := {}                    ## Vector3i cell -> [[variant, index], ...]
var _gone := {}                     ## "variant:i" -> true: taken, or raided away (not offered any more)
var _hl: MeshInstance3D
var _picker: Interactable
var _pick_node: Node3D
var _pick_at := ["", -1]
var _tick := 0.0


func loot() -> void:
	if looted:
		return
	looted = true
	for c in get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi == null or not String(mmi.name).begins_with("Merch_"):
			continue
		var v := String(mmi.name).to_lower()
		var essential := v.contains("water") or v.contains("can") or v.contains("soup") or v.contains("med") or v.contains("pill") \
			or v.contains("battery") or v.contains("bottle")
		var gone := 80 if essential else 45
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var h := absi(hash(String(mmi.name) + str(i))) % 100
			var run := absi(hash(String(mmi.name) + str(i / 6))) % 100            # whole runs of six go together
			var t := mm.get_instance_transform(i)
			if _gone.has(String(mmi.name).trim_prefix("Merch_") + ":" + str(i)):
				continue                                                   # already taken off the shelf by the player
			if run < gone - 8 or h < gone - 30:
				mm.set_instance_transform(i, Transform3D(t.basis.scaled(Vector3.ONE * 0.001), t.origin))
				_gone[String(mmi.name).trim_prefix("Merch_") + ":" + str(i)] = true
				looted_hidden += 1
			elif h < gone - 26:
				_gone[String(mmi.name).trim_prefix("Merch_") + ":" + str(i)] = true
				# knocked off: lying on the floor in front of the shelf
				var fwd := t.basis.z.normalized()
				var b := Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, float(h) * 0.7)
				mm.set_instance_transform(i, Transform3D(b * t.basis.orthonormalized(), Vector3(t.origin.x, 0.07, t.origin.z) + fwd * 0.45))


func remaining(gid: String) -> int:
	var mm: MultiMesh = (groups[gid]["mmi"] as MultiMeshInstance3D).multimesh
	return mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count


var _veil_say := 0
var _veil_prompts := false


## After the Veil the supermarket's stock is not takeable (review note #50): it sat out in the mist. Examining it says why (a different reason each time).
func veil_blocked() -> bool:
	return store_key == "supermarket" and Game.has_flag("p3_mist")


func _veil_refusal() -> void:
	_veil_say += 1
	Dialogue.say("store_veil_%d" % ((_veil_say % 3) + 1), false, true)


func _take(gid: String, by: Node) -> void:
	if veil_blocked():
		_veil_refusal()
		return
	var g: Dictionary = groups[gid]
	if store_key == "supermarket" and Game.has_flag("groceries_done"):
		return                                                   # (the shopping is over: review note #31)
	if holds_kind(g["item"]):
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


# ------------------------------------------------------------------ take any product off any shelf
## One pooled interaction follows the view: the product nearest the crosshair (within reach) gets the "[E] Take" box.
func _make_picker() -> void:
	_pick_node = Node3D.new()
	_pick_node.name = "ShelfPick"
	add_child(_pick_node)
	_picker = Interactable.attach(_pick_node, {"kind": "custom", "label": "Product", "prompt_text": ""})
	_picker.used.connect(func(by): _take_shelf())
	_picker.collision_layer = 0                    # off until something is under the crosshair
	_hl = MeshInstance3D.new()                    # the classic highlight on whatever is about to be taken (review note #24)
	_hl.name = "ShelfHighlight"
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(1.0, 0.85, 0.5, 0.45)
	_hl.material_override = hm
	_hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hl.visible = false
	add_child(_hl)


func _process(delta: float) -> void:
	if _picker == null:
		return
	_tick += delta
	if _tick < 0.08:
		return
	_tick = 0.0
	var cam := get_viewport().get_camera_3d()
	if veil_blocked() and not _veil_prompts:
		_veil_prompts = true
		for gid in groups:
			(groups[gid]["it"] as Interactable).prompt_text = "[E] Check " + String(groups[gid]["label"])     # (not "Take": it cannot be taken now)
	if store_key == "supermarket" and Game.has_flag("groceries_done") and not veil_blocked():       # the shopping is over: the shelves are not for taking any more (review note #31)
		_picker.collision_layer = 0
		_hl.visible = false
		return
	if cam == null or not is_visible_in_tree() or cam.global_position.distance_to(global_position) > 60.0:
		return
	var hit := find_product(cam.global_position, -cam.global_transform.basis.z)
	if hit.is_empty():
		_picker.collision_layer = 0
		_pick_at = ["", -1]
		_hl.visible = false
		return
	_pick_at = [hit["variant"], hit["i"]]
	var d: Vector3 = (_dims_of(hit["variant"]))
	_pick_node.position = (hit["pos"] as Vector3) + Vector3(0, d.y * 0.5, 0)
	_picker.prompt_text = ("[E] Check " if veil_blocked() else "[E] Take ") + name_of(hit["variant"])
	_picker.label = name_of(hit["variant"])
	(_picker.get_child(0) as CollisionShape3D).shape = _box(d)
	_picker.collision_layer = 8
	var mm: MultiMesh = (_mm_of[hit["variant"]] as MultiMeshInstance3D).multimesh
	_hl.mesh = meshes[hit["variant"]]
	_hl.transform = Transform3D(mm.get_instance_transform(int(hit["i"])).basis * 1.05, (hit["pos"] as Vector3) + Vector3(0, 0.0, 0))
	_hl.visible = true


static var _dims_cache := {}


func _dims_of(variant: String) -> Vector3:
	if not _dims_cache.has(variant):
		var m: Mesh = meshes.get(variant)
		_dims_cache[variant] = m.get_aabb().size if m else Vector3(0.1, 0.1, 0.1)
	return _dims_cache[variant]


func _box(d: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = d.max(Vector3.ONE * 0.12) + Vector3.ONE * 0.05
	return b


## The visible product nearest the view line within reach: {"variant", "i", "pos"} (store space), or {}.
func find_product(eye_w: Vector3, fwd_w: Vector3) -> Dictionary:
	var eye := to_local(eye_w)
	var fwd := (global_transform.basis.inverse() * fwd_w).normalized()
	var best := {}
	var best_score := INF
	var lo := Vector3i(floori(eye.x - REACH), floori(eye.y - REACH), floori(eye.z - REACH))
	var hi := Vector3i(floori(eye.x + REACH), floori(eye.y + REACH), floori(eye.z + REACH))
	for cx in range(lo.x, hi.x + 1):
		for cy in range(maxi(lo.y, -1), mini(hi.y, 4) + 1):
			for cz in range(lo.z, hi.z + 1):
				var list = _cells.get(Vector3i(cx, cy, cz))
				if list == null:
					continue
				for e in list:
					var v: String = e[0]
					var i: int = e[1]
					var p: Vector3 = (_pos[v] as PackedVector3Array)[i]
					var to: Vector3 = p + Vector3(0, _dims_of(v).y * 0.5, 0) - eye
					var along := to.dot(fwd)
					if along < 0.15 or along > REACH:
						continue
					var off := (to - fwd * along).length()
					if off > PICK_R or _gone.has(v + ":" + str(i)):
						continue
					var score := off + along * 0.03
					if score < best_score:
						best_score = score
						best = {"variant": v, "i": i, "pos": p}
	return best


## Lifts every static product inside `box` (store space) off the shelves: returns [[variant, transform], ...] and hides the originals (they are not offered any more, nothing is saved as taken).
## A shelf unit that the story moves takes its products with it.
func detach_region(box: AABB) -> Array:
	var out: Array = []
	for v in _pos.keys():
		var m: MultiMeshInstance3D = _mm_of.get(v)
		if m == null:
			continue
		var ps: PackedVector3Array = _pos[v]
		for i in ps.size():
			if _gone.has(v + ":" + str(i)) or not box.has_point(ps[i]):
				continue
			out.append([v, m.multimesh.get_instance_transform(i)])
			m.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(ps[i].x, -80.0, ps[i].z)))
			_gone[v + ":" + str(i)] = true
	return out


func _hide_static(v: String, i: int) -> void:
	var m: MultiMeshInstance3D = _mm_of.get(v)
	if m == null or i >= m.multimesh.instance_count:
		return
	var t := m.multimesh.get_instance_transform(i)
	m.multimesh.set_instance_transform(i, Transform3D(t.basis.scaled(Vector3.ONE * 0.001), t.origin))
	_gone[v + ":" + str(i)] = true


func take_product(v: String, i: int) -> String:
	if _gone.has(v + ":" + str(i)) or not _pos.has(v):
		return ""
	if holds_kind(item_of(v)):                                      # one of each kind: a snack, a candy, a drink
		Dialogue.say("merch_have_one", false, true)
		return ""
	_hide_static(v, i)
	var key := "merch/" + store_key + "/_free"
	var l: Array = Game.world_state.get(key, [])
	l.append(v + ":" + str(i))
	Game.world_state[key] = l
	var item := item_of(v)
	Game.add_item(item)
	Sfx.play("pickup", to_global(_pos[v][i]))
	taken.emit("shelf_" + v, item)
	return item


func _take_shelf() -> void:
	if _pick_at[1] < 0:
		return
	if veil_blocked():
		_veil_refusal()
		return
	take_product(String(_pick_at[0]), int(_pick_at[1]))
	_hl.visible = false
	_picker.collision_layer = 0
	_pick_at = ["", -1]
