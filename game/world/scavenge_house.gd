extends Node
class_name VeilScavengeHouse
## THE VEIL - an explorable ("scavenge") house. Most Greyhaven houses stay closed; the few listed in
## game/data/scavenge_houses.json are opened up by this node:
##   - safety: only single-storey houses without stairs / basement levels are accepted (anything else stays shut);
##   - the baked furnishing batch (closed, merged, one collision) is removed and the articulated Pack 03 pieces are
##     placed exactly where build_residential.furnish_instances put them, so cabinet doors, drawers, the fridge
##     and the oven really open;
##   - the house doors open (interior doors swing into the room they serve, the front door inward);
##   - loot is placed INSIDE a container (cabinet, drawer, medicine cabinet) and can only be picked up while that
##     container is open. Pickups use the normal Interactable (inventory + story flag + saved "taken" state).
## Container/door states are saved through Interactable.state_key ("scav/<house>/...").

signal looted(loot_id: String)

const FURN := "res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/%s.glb"

var world: Node
var house: Node3D
var spec: Dictionary
var moving: Dictionary
var ok := false
var doors := {}          # door node name -> Interactable
var parts := {}          # "<piece>#<n>/<part>" and "<piece>/<part>" (first instance) -> Interactable
var loot := {}           # loot id -> Interactable (pickup)
var _loot_container := {}  # loot id -> Interactable (container part)
var _loot_box := {}        # loot id -> BoxShape3D for drawers (grown to the drawer top so the ray finds the item)
var _containers: Array = []  # [{it, model, room}] storage a find can sit in (cabinets, fridges, drawers - no ovens, lids)
var _items: Array = []       # today's loot models (freed together on a new day)

## Furniture whose doors / drawers hold supplies: kitchen storage, bedroom drawers, bathroom cabinets, desks.
const LOOT_PIECES := ["RES_Counter_Sink", "RES_Counter_Base_1.2", "RES_Counter_Base_0.6", "RES_Counter_Corner",
	"RES_WallCabinet_0.8", "RES_WallCabinet_0.4", "RES_KitchenIsland", "RES_Fridge_Retro", "RES_Fridge_TopFreezer",
	"RES_MedicineCabinet", "RES_BathSink_Vanity", "RES_Nightstand", "RES_Dresser", "RES_Dresser_Mirror",
	"RES_SideTable_Drawer", "RES_Desk", "RES_Wardrobe"]


static func load_specs() -> Dictionary:
	var f := FileAccess.open("res://game/data/scavenge_houses.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else {}


## True when the house can be explored safely (no upper floors, no basement).
static func is_safe(h: Node3D) -> bool:
	var info: Dictionary = h.get_meta("veil_house", {})
	if int(info.get("stairs", 0)) != 0:
		return false
	for r in info.get("rooms", []):
		if int(r.get("level", 0)) != 0:
			return false
	return true


func setup(w: Node, h: Node3D, s: Dictionary, all: Dictionary) -> bool:
	world = w
	house = h
	spec = s
	moving = all.get("moving_parts", {})
	name = "Scavenge_" + h.name
	if not is_safe(h):
		push_warning("scavenge house %s has stairs / a basement: left closed" % h.name)
		return false
	_open_house_doors()
	_furnish()
	_day = survival_day()
	_place_loot()
	ok = true
	return true


## The survival day (nights slept at the shelter): "daily" houses get new supplies in their containers each day.
var _day := 0


static func survival_day() -> int:
	return (Game.world_state.get("shelter_nights", {}) as Dictionary).size()


func _process(_d: float) -> void:
	if ok and spec.get("daily", false) and survival_day() != _day:
		_day = survival_day()
		for item in _items:                              # yesterday's (taken ones stay taken: their own saved keys)
			if is_instance_valid(item):
				(item as Node).queue_free()
		_items.clear()
		loot.clear()
		_loot_container.clear()
		_place_loot()
	for id in loot:
		var it: Interactable = loot[id]
		if it.taken:
			continue
		var c: Interactable = _loot_container[id]
		it.collision_layer = 8 if c.is_open else 0      # nothing to grab through a closed door or drawer


# ------------------------------------------------------------------ house doors
func _open_house_doors() -> void:
	for e in house.get_meta("veil_interactables", []):
		var n := String(e.get("node", ""))
		if e.get("veil_interact", "") != "hinge" or not n.begins_with("INT_Door_"):
			continue
		var d := house.find_child(n, true, false) as Node3D
		if d == null or d.get_node_or_null("Interact"):
			continue
		var deg := float(e.get("open_deg", 90.0))
		var into: Variant = _door_room_center(n)
		if into != null:
			deg = world._toward_deg(d, deg, house.global_transform * (into as Vector3))
		doors[n] = Interactable.attach(d, {"kind": "hinge", "label": world._label_for(n), "open_deg": deg,
			"hinge_axis": Vector3.UP, "state_key": "scav/%s/%s" % [house.name, n]})


## Centre (house-local) of the room a door opens into: the first listed room (bath, bedroom, hall), or the
## inside room for an exterior door.
func _door_room_center(door: String) -> Variant:
	var info: Dictionary = house.get_meta("veil_house", {})
	var rooms := {}
	for r in info.get("rooms", []):
		var rc: Array = r["rect"]
		rooms[r["id"]] = Vector3((rc[0] + rc[2]) * 0.5, float(r.get("floor_y", 0.6)) + 1.0, (rc[1] + rc[3]) * 0.5)
	for dd in info.get("doors", []):
		if dd.get("name", "") != door:
			continue
		var pair: Array = dd.get("rooms", [])
		if pair.is_empty():
			return null
		return rooms.get(String(pair[1]) if pair[0] == "OUT" and pair.size() > 1 else String(pair[0]))
	return null


# ------------------------------------------------------------------ furniture
func _furnish() -> void:
	var baked := house.get_node_or_null("Furnishing")
	if baked:
		baked.queue_free()                    # closed batch + its merged collision; replaced below piece by piece
	var holder := Node3D.new()
	holder.name = "ScavengeFurniture"
	house.add_child(holder)
	var counts := {}
	for p in spec.get("pieces", []):
		var model := String(p["model"])
		var ps := load(FURN % model) as PackedScene
		if ps == null:
			push_warning("missing furniture " + model)
			continue
		counts[model] = int(counts.get(model, 0)) + 1
		var n := ps.instantiate() as Node3D
		n.name = "%s_%02d" % [model.trim_prefix("RES_").replace(".", "_"), counts[model]]
		holder.add_child(n)
		var pos: Array = p["pos"]
		n.transform = Transform3D(Basis(Vector3.UP, float(p.get("yaw", 0.0))), Vector3(pos[0], pos[1], pos[2]))
		var mv: Dictionary = moving.get(model, {})
		for part in mv:
			var node := n.find_child(part, true, false) as Node3D
			if node == null:
				continue
			var e: Dictionary = mv[part]
			var cfg := {"label": world._label_for(part), "state_key": "scav/%s/%s/%s" % [house.name, n.name, part]}
			match String(e.get("veil_interact", "")):
				"hinge":
					var ax: Vector3 = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}.get(e.get("axis", "y"), Vector3.UP)
					cfg.merge({"kind": "hinge", "open_deg": world._outward_deg(node, float(e.get("open_deg", 90.0)), ax), "hinge_axis": ax})
				"slide", "lift":
					var sax := Vector3(0, 1, 0) if e.get("veil_interact") == "lift" else Vector3(0, 0, 1)
					cfg.merge({"kind": "slide", "slide_axis": sax, "slide_dist": float(e.get("distance", 0.3))})
				_:
					continue
			var it := Interactable.attach(node, cfg)
			if model in LOOT_PIECES and String(e.get("veil_interact", "")) != "lift":
				_containers.append({"it": it, "model": model, "room": String(p.get("room", ""))})
			parts["%s#%d/%s" % [model, counts[model], part]] = it
			if counts[model] == 1:
				parts["%s/%s" % [model, part]] = it


# ------------------------------------------------------------------ loot inside containers
## Today's loot, decided from the house, the day and the loot list alone (so a load, re-entering the house or opening
## a menu always rebuilds the same arrangement; taken finds stay taken through their saved keys):
##   - non-daily houses (story houses) and one-time / story finds: exactly where the spec puts them;
##   - daily houses, the first day: each supply in a container of the right kind in THIS house (food and water in the
##     kitchen, medicine in the bathroom or a nightstand, the rest in drawers), varied per house;
##   - daily houses, each later day: about half of them get one new find, in a varied container; the rest stay empty.
## Only what is available is created: there is never a visible bottle or can without its working pickup.
func _plan() -> Array:
	var out: Array = []
	var entries: Array = spec.get("loot", [])
	var daily: bool = spec.get("daily", false)
	var used: Array = []
	var fresh: Array = []
	for l in entries:
		var fixed: bool = not daily or l.get("once", false) or String(l.get("flag", "")) != ""
		if fixed:
			var c: Interactable = parts.get("%s/%s" % [l["piece"], l["part"]])
			if c:
				used.append(c)
				out.append({"l": l, "id": String(l["id"]), "c": c, "key": "scav/%s/loot_%s" % [house.name, l["id"]]})
		else:
			fresh.append(l)
	if fresh.is_empty():
		return out
	if _day <= 0:
		for l in fresh:
			var c := _pick_container(String(l["item"]), "%s/%s" % [house.name, l["id"]], used)
			if c == null:
				c = parts.get("%s/%s" % [l["piece"], l["part"]])
			if c:
				used.append(c)
				out.append({"l": l, "id": String(l["id"]), "c": c, "key": "scav/%s/loot_%s" % [house.name, l["id"]]})
	elif absi(("%s/day%d" % [house.name, _day]).hash()) % 100 < 55:
		var l: Dictionary = fresh[absi(("%s/what%d" % [house.name, _day]).hash()) % fresh.size()]
		var c := _pick_container(String(l["item"]), "%s/where%d" % [house.name, _day], used)
		if c == null:
			c = parts.get("%s/%s" % [l["piece"], l["part"]])
		if c:
			out.append({"l": l, "id": "%s_d%d" % [l["id"], _day], "c": c,
				"key": "scav/%s/loot_%s_d%d" % [house.name, l["id"], _day]})
	return out


func _pick_container(item: String, seed_text: String, used: Array) -> Interactable:
	var res := Game.shelter_resource(item)
	var good: Array = []
	for e in _containers:
		var c: Interactable = e["it"]
		if c in used or not is_instance_valid(c):
			continue
		var room := String(e["room"])
		var model := String(e["model"])
		var ok_here := false
		match res:
			"food", "water":
				ok_here = room == "KIT" or model.begins_with("RES_Fridge") or model.begins_with("RES_Counter") or model.begins_with("RES_WallCabinet")
			"medical":
				ok_here = model == "RES_MedicineCabinet" or model == "RES_BathSink_Vanity" or model == "RES_Nightstand"
			_:
				ok_here = model in ["RES_Nightstand", "RES_Dresser", "RES_Dresser_Mirror", "RES_SideTable_Drawer", "RES_Desk", "RES_Wardrobe"]
		if ok_here:
			good.append(c)
	if good.is_empty():
		return null
	return good[absi(seed_text.hash()) % good.size()]


func _place_loot() -> void:
	for e in _plan():
		var l: Dictionary = e["l"]
		var id := String(e["id"])
		var c: Interactable = e["c"]
		var part := c.get_parent() as Node3D             # the door leaf or drawer the Interactable sits on
		var piece := part.get_parent() as Node3D         # the piece's glTF root (door/drawer parent)
		var item := (load(String(l["model"])) as PackedScene).instantiate() as Node3D
		item.name = "Loot_" + id
		var a := Interactable.aabb_of(part)              # part-local box of the door / drawer
		if c.kind == "slide":
			# drawer: the item rides in the drawer box, on its floor
			part.add_child(item)
			item.position = Vector3(a.get_center().x, a.position.y + 0.02, a.get_center().z)
		else:
			# hinged door: the item stands on the cabinet floor / shelf behind the closed door, set back from it
			piece.add_child(item)
			var closed: AABB = c._base * a                   # piece-local, closed position (before any restored opening)
			var cab := String(piece.name).contains("MedicineCabinet")
			var back := 0.06 if cab else 0.24
			item.position = Vector3(closed.get_center().x, closed.position.y + 0.03, closed.position.z - back)
			if cab:
				item.position.z = maxf(closed.position.z - back, 0.02)
		var key := String(e["key"])
		_items.append(item)
		var it := Interactable.attach(item, {"kind": "pickup", "label": String(l.get("label", id)), "item_id": String(l["item"]),
			"story_flag": String(l.get("flag", "")), "state_key": key})
		if c.kind == "slide":
			# grow the pickup box up to the drawer's top so the player's ray meets the item before the drawer box
			var cs := it.get_child(0) as CollisionShape3D
			var bs := cs.shape as BoxShape3D
			var top := a.end.y - item.position.y + 0.04
			bs.size.y = maxf(bs.size.y, top)
			cs.position.y = bs.size.y * 0.5
		if c.kind != "slide":
			# cabinets have a solid collision box: stretch the pickup box forward to the (open) door plane so the
			# player's ray meets the item at the cabinet front, where one reaches in
			var closed_front: AABB = c._base * Interactable.aabb_of(part)
			var front := closed_front.end.z + 0.03 - item.position.z      # piece-local +z is the cabinet front
			var cs2 := it.get_child(0) as CollisionShape3D
			var bs2 := cs2.shape as BoxShape3D
			if front > bs2.size.z * 0.5:
				var back := cs2.position.z - bs2.size.z * 0.5
				bs2.size.z = front - back
				cs2.position.z = back + bs2.size.z * 0.5
		it.container = c
		for co in piece.find_children("*", "CollisionObject3D", true, false):
			it.los_ignore.append((co as CollisionObject3D).get_rid())
		it.collision_layer = 0
		it.used.connect(func(_b): looted.emit(id))
		loot[id] = it
		_loot_container[id] = c
