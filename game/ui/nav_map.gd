extends CanvasLayer
class_name VeilNavMap
## THE VEIL - Greyhaven's town map (M) and light navigation help.
##   * the way back to the current shelter (HUD marker fallback, as before);
##   * M: a worn municipal street map drawn from the playable town itself - every road piece and every building at
##     its real footprint - in two views (the town; Maple Ave and the subdivision up north), the player, the story
##     objective (red), the chosen search destination (amber), the landmarks found so far, and every house with
##     its exploration state, all from what actually happened:
##        unexplored  /  X - reached its front door and there is no way in (only the houses the game opens for
##        exploring can be entered)  /  check - a supply was taken inside  /  searched, nothing found  /  a small
##        amber dot - supplies may have returned (the house's real daily refill has put something back since).
##     Click a house: its status, MARK AS DESTINATION / CLEAR (one at a time; its own amber marker on screen,
##     never the story's). Eddie hands the map over in the supermarket (once, in a quiet moment); if he cannot,
##     it is simply there by Chapter 11. M or Esc closes it; the player cannot move while it is open.
## State: flags map_acquired / map_tutorial_done, world_state "map_houses" and "map_dest". Secrets are never shown.

const VIEWS := {"town": Rect2(-172.0, -136.0, 380.0, 218.0), "north": Rect2(24.0, 372.0, 322.0, 192.0)}
const WEST_ROADS := [
	[Vector2(-24, 0), Vector2(-46, 0), Vector2(-60, 2), Vector2(-92, 5), Vector2(-104, 2)],
	[Vector2(-92, 8), Vector2(-100, 2), Vector2(-108, -16), Vector2(-113, -36), Vector2(-104, -70), Vector2(-96, -88)],
	[Vector2(-104, 2), Vector2(-114, 18), Vector2(-121, 31), Vector2(-125, 60)],
	[Vector2(-88, 0), Vector2(-82, -12), Vector2(-80, -24)]]
## name, world x/z (or a node path to read it from), the flag that reveals it ("" = known from the start)
const PLACES := [["Home", "Residential/Houses/PLAYER_HOME", ""], ["Video Game Shop", "Commercial/GAME_SHOP", ""],
	["Supermarket", "Commercial/SUPERMARKET", ""], ["Mill-Worker House", Vector2(-92, 14), "ch10_started"],
	["Farmhouses", Vector2(-100, -95), "ch11_started"], ["Maintenance Station", Vector2(-80, -28), "ch12_started"],
	["Old District", Vector2(-125, 50), "ch13_started"]]
const INK := Color(0.2, 0.18, 0.15)
const LIGHT := Color(0.94, 0.91, 0.82)
## The town seen from above (orthographic captures of the real 3D town, pixelated): one per view, drawn under
## everything else. Without one the old paper sheet is drawn.
const MAP_TEX := {"town": "res://game/ui/map/greyhaven_town.png", "north": "res://game/ui/map/greyhaven_north.png"}
var _tex := {}
var ink := INK                         ## the marking colour of the sheet being drawn (light over the aerial view)
const PAPER := Color(0.66, 0.62, 0.51)
const ROAD := Color(0.36, 0.34, 0.3)
const AMBER := Color(0.85, 0.55, 0.12)
const STORY := Color(0.62, 0.12, 0.08)

var world: Node
var panel: Control
var dest_mark: Control
var open := false
var view := "town"
var _held := {}
var _route: Array = []
var _roads: Array = []                 ## Rect2 (world x/z) of every road piece
var _junctions: Array = []             ## intersection centres (world x/z)
## street names where the town's own signs put them (the Oak / Main sign at the crossroads; Maple Ave up north)
const STREETS := [["MAIN ST", Vector2(78.0, 0.0), "town"], ["OAK ST", Vector2(0.0, -48.0), "town"], ["MAIN ST", Vector2(-60.0, 0.0), "town"],
	["MAPLE AVE", Vector2(110.0, 509.0), "north"]]
var _blocks: Array = []                ## [Rect2, label] shops and other buildings
var houses := {}                       ## zone -> {rect: Rect2, door: Vector3, node}
var _hover := ""
var selected := ""
var _btn_mark: Button
var _btn_view: Button
var _in := ""                          ## the house the player is in
var _got_here := 0
var _counts := {}
var _t := 0.0
var _said_x := {}
var _idle := 0.0
var _giving := false


func setup(w: Node) -> void:
	world = w
	layer = 30
	var f := FileAccess.open("res://game/world/world_data.json", FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary:
		for p in d.get("route", []):
			_route.append(Vector2(float(p[0]), float(p[1])))
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	panel.draw.connect(_draw_map)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for k in MAP_TEX:
		if ResourceLoader.exists(MAP_TEX[k]):
			_tex[k] = load(MAP_TEX[k])
	panel.gui_input.connect(_on_map_input)
	add_child(panel)
	_btn_mark = VeilUI.button("MARK AS DESTINATION")
	_btn_mark.custom_minimum_size = Vector2(250, 34)
	_btn_mark.pressed.connect(_toggle_dest)
	panel.add_child(_btn_mark)
	_btn_view = VeilUI.button("MAPLE AVE")
	_btn_view.custom_minimum_size = Vector2(150, 34)
	_btn_view.pressed.connect(func():
		view = "north" if view == "town" else "town"
		_layout())
	panel.add_child(_btn_view)
	dest_mark = Control.new()
	dest_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dest_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dest_mark.draw.connect(_draw_dest)
	add_child(dest_mark)
	world.hud.marker_fallback = shelter_marker
	world.hud.marker_override = map_dest_marker          # the search destination on the same yellow diamond
	dest_mark.visible = false                             # (no second, separate marker)
	Game.inventory_changed.connect(_on_inventory)
	_collect.call_deferred()


## The town as it is built: road pieces, buildings, houses (their entrances from the house data).
func _collect() -> void:
	for i in 3:
		await get_tree().process_frame
	for n in world.find_children("RD_*", "Node3D", true, false):
		var par := n.get_parent()
		if par and String(par.name).begins_with("RD_"):
			continue
		if n is MeshInstance3D or n is CollisionObject3D:
			continue
		var a: AABB = (n as Node3D).global_transform * Interactable.aabb_of(n as Node3D)
		if a.size.x > 0.5 and a.size.z > 0.5:
			_roads.append(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
			if String(n.name).contains("Intersection"):
				_junctions.append(Vector2(a.get_center().x, a.get_center().z))
	var hn := world.get_node_or_null("Residential/Houses")
	if hn:
		for h in hn.get_children():
			if not (h is Node3D) or not h.visible:
				continue
			var a: AABB = (h as Node3D).global_transform * Interactable.aabb_of(h as Node3D)
			var door := Vector3(a.get_center().x, a.position.y, a.end.z)
			var info: Dictionary = h.get_meta("veil_house", {})
			for dd in info.get("doors", []):
				if dd.get("exterior", false) and String(dd.get("name", "")) == "INT_Door_Front":
					var c: Array = dd["center"]
					door = (h as Node3D).global_transform * Vector3(c[0], c[1], c[2])
			houses[String(h.name)] = {"rect": Rect2(a.position.x, a.position.z, a.size.x, a.size.z), "door": door, "node": h}
	var cn := world.get_node_or_null("Commercial")
	if cn:
		for b in cn.get_children():
			if b is Node3D:
				var a: AABB = (b as Node3D).global_transform * Interactable.aabb_of(b as Node3D)
				var lbl: String = {"SUPERMARKET": "Supermarket", "GAME_SHOP": "Game Haven"}.get(String(b.name), "")
				_blocks.append([Rect2(a.position.x, a.position.z, a.size.x, a.size.z), lbl])
	var gas := world.find_child("TOWN_GasForecourt_001", true, false) as Node3D
	if gas:
		var a: AABB = gas.global_transform * Interactable.aabb_of(gas)
		_blocks.append([Rect2(a.position.x, a.position.z, a.size.x, a.size.z), "Gas Station"])
	var dz := String(Game.world_state.get("map_dest", ""))
	if dz != "" and not dz.begins_with("part:") and (not houses.has(dz) or _state(dz).get("x", false)):
		Game.world_state.erase("map_dest")          # never restore a destination that no longer makes sense


# ------------------------------------------------------------------ the shelter
## The group's current safe place: [door position, name], or [] when there is none.
func shelter() -> Array:
	if Game.has_flag("ch15_set_out") or Game.has_flag("chapter_15_complete"):
		return []
	if Game.has_flag("ch15_started"):
		return [Vector3(-80.0, 1.2, -24.0), "REFUGE"]                      # the old maintenance station, by the road
	if Game.has_flag("ch10_started") and not Game.has_flag("ch14_evac_started"):
		var h: Node3D = world.get_node_or_null("Residential/Houses/MILL_HOUSE")
		return [h.global_transform * Vector3(0.6, 1.4, 0.4), "SHELTER"] if h else []
	if Game.has_flag("c5_started") and not Game.has_flag("ch9_supermarket_lost") and world.market:
		return [world.market.global_transform * Vector3(0.0, 1.3, -0.9), "SHELTER"]
	return []


## HUD marker fallback: the way back to the shelter, when no story destination is set and the player is out.
func shelter_marker() -> Array:
	var s := shelter()
	if s.is_empty() or world.player == null:
		return []
	if world.player.global_position.distance_to(s[0]) < 25.0:
		return []
	return s


# ------------------------------------------------------------------ house exploration state
func _state(z: String) -> Dictionary:
	var all: Dictionary = Game.world_state.get("map_houses", {})
	if not all.has(z):
		all[z] = {}
		Game.world_state["map_houses"] = all
	return all[z]


func _scav(z: String) -> Node:
	if world.expedition and world.expedition.houses.has(z):
		return world.expedition.houses[z]
	var c5 = world.phase4.chapter5 if world.phase4 else null
	if z == "HOUSE_04" and c5 and c5.get("scav"):
		return c5.scav
	return null


## Can the player actually get inside (the houses the game opens; the survivor's house from Chapter 5)?
func accessible(z: String) -> bool:
	if _scav(z) != null:
		return true
	return z == "HOUSE_05" and Game.has_flag("c5_started")


func status(z: String) -> String:
	var s := _state(z)
	if s.get("l", false):
		return "looted"
	if s.get("x", false) and not accessible(z):
		return "no_way_in"
	if s.get("e", false):
		return "empty"
	if s.get("v", false):
		return "visited"
	return "unexplored"


## Supplies may have returned: looted on an earlier day, and the house's real refill has something untaken now.
func returned(z: String) -> bool:
	var s := _state(z)
	var h = _scav(z)
	if not s.get("l", false) or h == null:
		return false
	var day: int = (Game.world_state.get("shelter_nights", {}) as Dictionary).size()
	if day <= int(s.get("ld", -1)):
		return false
	for id in h.loot:
		if is_instance_valid(h.loot[id]) and not h.loot[id].taken:
			return true
	return false


func _supply_counts() -> Dictionary:
	var c := {}
	for id in Game.inventory:
		if Game.shelter_resource(String(id)) != "" or Game.item_info(String(id)).has("rounds"):
			c[id] = int(c.get(id, 0)) + 1
	return c


func _on_inventory() -> void:
	var now := _supply_counts()
	var gained := false
	for k in now:
		if int(now[k]) > int(_counts.get(k, 0)):
			gained = true
	_counts = now
	if not gained or _in == "":
		return
	var s := _state(_in)
	_got_here += 1
	s["l"] = true
	s["e"] = false
	s["ld"] = (Game.world_state.get("shelter_nights", {}) as Dictionary).size()
	if not Game.has_flag("map_first_loot"):
		Game.set_flag("map_first_loot")
		world.hud.location_caption("HOUSE SCAVENGED", 2.5)
		_hint("Marked on your map. Might be worth checking again after another night.", 6.0)


func _track() -> void:
	var p: Vector3 = world.player.global_position
	var here := ""
	for z in houses:
		var r: Rect2 = houses[z]["rect"]
		if not r.grow(8.0).has_point(Vector2(p.x, p.z)):
			continue
		var inside := _inside(z, p)
		if inside and accessible(z):
			here = z
		var door: Vector3 = houses[z]["door"]
		if not accessible(z) and not inside and Vector2(p.x - door.x, p.z - door.z).length() < 2.6 and world.player.visible:
			var s := _state(z)
			if not s.get("x", false):
				s["x"] = true                            # reached its front door: no way in (kept if it opens later)
				if not _said_x.has(z):
					_said_x[z] = true
					_hint("No way in here. Marked on the map.", 3.0)
				if String(Game.world_state.get("map_dest", "")) == z:
					Game.world_state.erase("map_dest")
	if here != _in:
		if _in != "":
			var ls := _state(_in)
			if _got_here == 0 and not ls.get("l", false):
				ls["e"] = true                           # went in, came out with nothing
		_in = here
		_got_here = 0
		if here != "":
			_state(here)["v"] = true
			if String(Game.world_state.get("map_dest", "")) == here:
				Game.world_state.erase("map_dest")
				_hint("Search the cabinets, drawers and the fridge.", 4.0)


## Inside the house's actual rooms (its room plan, house-local), not merely within its outline (porch, steps).
func _inside(z: String, p: Vector3) -> bool:
	var h: Node3D = houses[z]["node"]
	var lp := h.to_local(p)
	var info: Dictionary = h.get_meta("veil_house", {})
	var rooms: Array = info.get("rooms", [])
	if rooms.is_empty():
		return (houses[z]["rect"] as Rect2).grow(-1.5).has_point(Vector2(p.x, p.z))
	for rm in rooms:
		var rc: Array = rm["rect"]
		if lp.x > float(rc[0]) and lp.x < float(rc[2]) and lp.z > float(rc[1]) and lp.z < float(rc[3]) \
				and absf(lp.y - float(rm.get("floor_y", 0.6))) < 2.5:
			return true
	return false


func _hint(t: String, hold: float) -> void:
	world.hud.set_hint(t)
	get_tree().create_timer(hold).timeout.connect(func():
		if is_instance_valid(world) and world.hud.hint.text == t:
			world.hud.set_hint(""))


# ------------------------------------------------------------------ getting the map (Eddie, once)
func _maybe_give(delta: float) -> void:
	if Game.has_flag("map_acquired") or _giving:
		return
	if Game.has_flag("ch10_started"):
		_acquired("The old town map is in your pack now.")    # Eddie could not hand it over: it is simply there
		return
	var ex = world.expedition
	if not Game.has_flag("c5_started") or ex == null or ex.shelter() != "supermarket" or not ex.in_store() or ex.active() or ex.emergency():
		_idle = 0.0
		return
	var e: Node3D = world.eddie
	var calm: bool = can_open() and not Dialogue.is_busy() and e != null and e.visible \
		and e.global_position.distance_to(world.player.global_position) < 7.0
	_idle = _idle + delta if calm else 0.0
	if _idle > 12.0:                                   # a quiet moment, not right after a story beat
		_giving = true
		var ok: bool = await world.converse(["map_intro"], [e]) if world.has_method("converse") else false
		if not ok:
			Dialogue.say("map_intro", false, true)
		while Dialogue.is_busy() or world.conversing:
			await get_tree().process_frame
		_acquired("")
		_giving = false


func _acquired(extra: String) -> void:
	Game.set_flag("map_acquired")
	world.hud.location_caption("TOWN MAP ACQUIRED", 2.5)
	_hint((extra + " " if extra != "" else "") + "Press M for the map. Click a house to mark it as your next search.", 7.0)


# ------------------------------------------------------------------ the map
func can_open() -> bool:
	var p = world.player
	if p == null or not p.visible or not p.controls_enabled or world.in_car or world.conversing:
		return false
	if Dialogue.confirm_mode or world._choice_open() or world.hud.is_paused() or world.hud.inv_panel.visible:
		return false
	if world.get("_cine") and is_instance_valid(world.get("_cine")) or world.get("_encounter_running") == true:
		return false
	return true


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k := (e as InputEventKey).physical_keycode
	if open and (k == KEY_M or k == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
	elif not open and k == KEY_M and can_open():
		if not Game.has_flag("map_acquired"):
			_hint("You don't have a map of the town yet.", 2.5)
		else:
			show_map()
		get_viewport().set_input_as_handled()


func show_map() -> void:
	open = true
	var p = world.player
	_held = {"controls": p.controls_enabled, "look": p.look_enabled}
	p.controls_enabled = false
	p.look_enabled = false
	p.velocity = Vector3.ZERO
	var pp: Vector3 = p.global_position
	view = "north" if VIEWS["north"].grow(30.0).has_point(Vector2(pp.x, pp.z)) else "town"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.visible = true
	_layout()
	if not Game.has_flag("map_tutorial_done"):
		Game.set_flag("map_tutorial_done")
		_hint("Click a house, then MARK AS DESTINATION. Check = supplies found there. X = no way in.", 8.0)


func close() -> void:
	open = false
	panel.visible = false
	var p = world.player
	if p:
		p.controls_enabled = bool(_held.get("controls", true))
		p.look_enabled = bool(_held.get("look", true))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func places() -> Array:
	var out := []
	for pl in PLACES:
		if String(pl[2]) != "" and not Game.has_flag(String(pl[2])):
			continue
		var at: Variant = pl[1]
		if at is String:
			var n := world.get_node_or_null(at) as Node3D
			if n == null:
				continue
			at = Vector2(n.global_position.x, n.global_position.z)
		out.append([pl[0], at])
	return out


func _map_rect() -> Rect2:
	var vs := panel.size
	var v: Rect2 = VIEWS[view]
	var w := minf(vs.x * 0.92, vs.y * 0.78 * v.size.x / v.size.y)
	var h := w * v.size.y / v.size.x
	return Rect2(Vector2((vs.x - w) * 0.5, vs.y * 0.06), Vector2(w, h))


func _to_map(r: Rect2, at: Vector2) -> Vector2:
	var v: Rect2 = VIEWS[view]
	return r.position + (at - v.position) / v.size * r.size


func _from_map(r: Rect2, at: Vector2) -> Vector2:
	var v: Rect2 = VIEWS[view]
	return v.position + (at - r.position) / r.size * v.size


func _layout() -> void:
	var r := _map_rect()
	_btn_mark.position = Vector2(r.end.x - 250, r.end.y + 10)
	_btn_view.position = Vector2(r.position.x, r.end.y + 10)
	_btn_view.text = "MAPLE AVE" if view == "town" else "TOWN"
	_btn_mark.visible = selected != ""
	_btn_mark.text = "CLEAR DESTINATION" if selected != "" and String(Game.world_state.get("map_dest", "")) == selected else "MARK AS DESTINATION"
	panel.queue_redraw()


## Car search leads (game/world/expedition.gd car_leads): [key "part:...", "POSSIBLE CAR BATTERY - GAS STATION",
## world position, the short name for the diamond], at the find's real, reachable spot.
func part_leads() -> Array:
	var out: Array = []
	var ex = world.expedition
	if ex == null:
		return out
	for l in ex.car_leads():
		out.append([l[0], "%s - %s" % [l[1], _area_name(l[2])], l[2], l[1]])
	return out


func _lead(key: String) -> Array:
	for l in part_leads():
		if l[0] == key:
			return l
	return []


## Where a point is, in the map's own words: a building block it lies by, else the nearest street label.
func _area_name(at: Vector3) -> String:
	var p := Vector2(at.x, at.z)
	for b in _blocks:
		if String(b[1]) != "" and (b[0] as Rect2).grow(14.0).has_point(p):
			return String(b[1]).to_upper()
	var best := "TOWN"
	var bd := INF
	for st in STREETS:
		var d := p.distance_to(st[1])
		if d < bd:
			bd = d
			best = String(st[0])
	return best


func _house_at(r: Rect2, at: Vector2) -> String:
	for l in part_leads():
		if _to_map(r, Vector2(l[2].x, l[2].z)).distance_to(at) < 12.0:
			return String(l[0])
	var best := ""
	var bd := 14.0
	for z in houses:
		var c := _to_map(r, (houses[z]["rect"] as Rect2).get_center())
		if c.distance_to(at) < bd:
			bd = c.distance_to(at)
			best = z
	return best


func _on_map_input(e: InputEvent) -> void:
	var r := _map_rect()
	if e is InputEventMouseMotion:
		var hz := _house_at(r, (e as InputEventMouseMotion).position)
		if hz != _hover:
			_hover = hz
			panel.queue_redraw()
	elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var z := _house_at(r, (e as InputEventMouseButton).position)
		if z != "" or r.has_point((e as InputEventMouseButton).position):
			selected = z
			_layout()


func _toggle_dest() -> void:
	if selected == "":
		return
	if String(Game.world_state.get("map_dest", "")) == selected:
		Game.world_state.erase("map_dest")
	else:
		Game.world_state["map_dest"] = selected      # one search destination at a time
		_layout()
		close()                                      # marked: back to the game, the amber marker leads there (from Cline)
		return
	_layout()


func _street(z: String) -> String:
	var c: Vector2 = (houses[z]["rect"] as Rect2).get_center()
	if c.y > 300.0:
		return "MAPLE AVE"
	if c.x < -40.0:
		return "WEST END"
	return "TOWN"


func status_text(z: String) -> String:
	match status(z):
		"looted":
			return "Searched - supplies found" + ("  (supplies may have returned)" if returned(z) else "")
		"no_way_in":
			return "No way in"
		"empty":
			return "Searched - nothing found"
		"visited":
			return "Entered"
	return "Unexplored"


func _draw_map() -> void:
	var vs := panel.size
	var r := _map_rect()
	var font: Font = VeilUI.font()
	panel.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.72))
	var aerial: Texture2D = _tex.get(view)
	ink = LIGHT if aerial else INK
	var v: Rect2 = VIEWS[view]
	var clip := func(rr: Rect2) -> bool: return v.intersects(rr)
	if aerial:
		panel.draw_rect(r.grow(10), Color(0.08, 0.09, 0.08))
		panel.draw_texture_rect(aerial, r, false)
	else:
		panel.draw_rect(r.grow(10), PAPER.darkened(0.25))
		panel.draw_rect(r, PAPER)
		# worn paper: a few faint fold lines
		panel.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), PAPER.darkened(0.08), 2.0)
		panel.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), PAPER.darkened(0.08), 2.0)
	for rr in ([] if aerial else _roads):
		if clip.call(rr):
			var a := _to_map(r, (rr as Rect2).position)
			var b := _to_map(r, (rr as Rect2).end)
			panel.draw_rect(Rect2(a, b - a).intersection(r), ROAD)
	for j in ([] if aerial else _junctions):
		if v.has_point(j):
			panel.draw_circle(_to_map(r, j), 3.0, ROAD.darkened(0.45))
	if Game.has_flag("ch10_started") and view == "town" and not aerial:
		for road in WEST_ROADS:
			var pts := []
			for q in road:
				pts.append(_to_map(r, q))
			panel.draw_polyline(PackedVector2Array(pts), ROAD, 5.0)
	var labels: Array = []
	for bl in _blocks:
		var rr: Rect2 = bl[0]
		if not clip.call(rr):
			continue
		var a := _to_map(r, rr.position)
		var b := _to_map(r, rr.end)
		var box := Rect2(a, b - a).intersection(r)
		box = box.grow_individual(-box.size.x * 0.12, -box.size.y * 0.12, -box.size.x * 0.12, -box.size.y * 0.12)
		if not aerial:
			panel.draw_rect(box, PAPER.darkened(0.22))
			panel.draw_rect(box, ink, false, 1.2)
		if String(bl[1]) != "":
			_label(font, labels, String(bl[1]), box.get_center() + Vector2(0, -box.size.y * 0.5 - 6), ink, 13)
	# houses and their state
	for z in houses:
		var rr: Rect2 = houses[z]["rect"]
		if not clip.call(rr):
			continue
		var c := _to_map(r, rr.get_center())
		var hs := clampf(minf(r.size.x / 70.0, 11.0), 6.0, 11.0)     # one small, consistent house footprint
		var box := Rect2(c - Vector2(hs, hs) * 0.5, Vector2(hs, hs))
		var col := ink if accessible(z) else ink.lerp(PAPER if not aerial else Color(0.3, 0.3, 0.3), 0.45)
		panel.draw_rect(box, Color(0, 0, 0, 0.45) if aerial else PAPER.darkened(0.12))
		panel.draw_rect(box, col, false, 1.0)
		match status(z):
			"looted":
				panel.draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(6, -5)]), Color(0.45, 0.85, 0.45) if aerial else Color(0.15, 0.4, 0.18), 2.5)
			"no_way_in":
				var xc := Color(0.95, 0.35, 0.28) if aerial else Color(0.5, 0.15, 0.1)
				panel.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), xc, 2.5)
				panel.draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), xc, 2.5)
			"empty":
				panel.draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), ink, 2.0)
		if returned(z):
			panel.draw_circle(box.position + Vector2(box.size.x, 0), 3.5, AMBER)
		if z == _hover or z == selected:
			panel.draw_rect(box.grow(3), AMBER if z == selected else ink, false, 2.0)
		if String(Game.world_state.get("map_dest", "")) == z:
			_diamond(c + Vector2(0, -12), 6.0, AMBER)
	for st in STREETS:
		if String(st[2]) == view and v.has_point(st[1]):
			_label(font, labels, String(st[0]), _to_map(r, st[1]) + Vector2(0, -4), Color(0.85, 0.85, 0.8) if aerial else ROAD.darkened(0.55), 11)
	# car-part leads (amber, "?")
	for l in part_leads():
		var lp: Vector3 = l[2]
		if v.has_point(Vector2(lp.x, lp.z)):
			var lm := _to_map(r, Vector2(lp.x, lp.z))
			panel.draw_circle(lm, 7.0, AMBER if String(l[0]) == selected or String(Game.world_state.get("map_dest", "")) == String(l[0]) else AMBER.darkened(0.35))
			panel.draw_string(font, lm + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
			_label(font, labels, String(l[1]), lm + Vector2(0, -10), AMBER if aerial else AMBER.darkened(0.5), 11)
	# landmarks found so far
	for pl in places():
		var at: Vector2 = pl[1]
		if v.grow(-2).has_point(at) and String(pl[0]) not in ["Supermarket", "Video Game Shop"]:
			var m := _to_map(r, at)
			panel.draw_rect(Rect2(m - Vector2(3, 3), Vector2(6, 6)), ink)
			_label(font, labels, String(pl[0]), m + Vector2(6, -6), ink, 12)
	# the shelter, the story objective, the player
	var sh := shelter()
	if not sh.is_empty() and v.has_point(Vector2(sh[0].x, sh[0].z)):
		var sp := _to_map(r, Vector2(sh[0].x, sh[0].z))
		panel.draw_circle(sp, 6.0, Color(0.2, 0.42, 0.25))
		_label(font, labels, String(sh[1]), sp + Vector2(8, 12), Color(0.55, 0.9, 0.6) if aerial else Color(0.15, 0.32, 0.18), 12)
	var t: Variant = world.hud._mk_target
	var tp: Variant = (t as Node3D).global_position if t is Node3D and is_instance_valid(t) else (t if t is Vector3 else null)
	if tp != null and v.has_point(Vector2(tp.x, tp.z)):
		_diamond(_to_map(r, Vector2(tp.x, tp.z)), 7.0, STORY)
	var pp: Vector3 = world.player.global_position
	var fwd: Vector3 = -world.player.global_transform.basis.z
	var ang := atan2(fwd.z, fwd.x) + (v.size.x * 0.0)
	if v.has_point(Vector2(pp.x, pp.z)):
		var me := _to_map(r, Vector2(pp.x, pp.z))
		panel.draw_colored_polygon(PackedVector2Array([me + Vector2(cos(ang), sin(ang)) * 10.0, me + Vector2(cos(ang + 2.5), sin(ang + 2.5)) * 6.0,
			me + Vector2(cos(ang - 2.5), sin(ang - 2.5)) * 6.0]), Color(1, 1, 1) if aerial else Color(0.06, 0.08, 0.1))
		if aerial:
			panel.draw_circle(me, 13.0, Color(1, 1, 1, 0.9), false, 2.0)
	else:
		# off this sheet: an arrow on its edge toward the player
		var dir := (Vector2(pp.x, pp.z) - v.get_center()).normalized()
		var e := r.get_center() + dir * minf(r.size.x * 0.48 / maxf(absf(dir.x), 0.01), r.size.y * 0.48 / maxf(absf(dir.y), 0.01))
		panel.draw_colored_polygon(PackedVector2Array([e + dir * 9.0, e + dir.orthogonal() * 6.0, e - dir.orthogonal() * 6.0]), Color(0.06, 0.08, 0.1))
		_label(font, labels, "YOU", e - dir * 14.0 + Vector2(-10, 4), ink, 12)
	panel.draw_string(font, r.position + Vector2(12, 22), "GREYHAVEN" + ("  -  MAPLE AVE" if view == "north" else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	# the selected house and the key, under the sheet
	var info := ""
	if selected.begins_with("part:"):
		var sl := _lead(selected)
		info = String(sl[1]) if not sl.is_empty() else ""
	elif selected != "":
		info = "HOUSE  -  %s     %s" % [_street(selected), status_text(selected)]
	panel.draw_string(font, Vector2(r.position.x + 170, r.end.y + 32), info, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 440, 14, Color(0.9, 0.9, 0.86))
	panel.draw_string(font, Vector2(r.position.x, r.end.y + 64), "Check: found supplies   X: no way in   -: empty   Amber: search   Red: story   M: close",
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 11, Color(0.75, 0.75, 0.7))


func _label(font: Font, used: Array, txt: String, at: Vector2, col: Color, sz: int) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var box := Rect2(at - Vector2(w * 0.5, sz), Vector2(w, sz + 2))
	for u in used:
		if (u as Rect2).intersects(box):
			return                                   # never on top of another label
	used.append(box)
	if ink == LIGHT:
		panel.draw_string_outline(font, box.position + Vector2(0, sz), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, 0.9))
	panel.draw_string(font, box.position + Vector2(0, sz), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _diamond(c: Vector2, rad: float, col: Color) -> void:
	panel.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -rad), c + Vector2(rad, 0), c + Vector2(0, rad), c + Vector2(-rad, 0)]), col)


# ------------------------------------------------------------------ the search destination, on screen
func dest_point() -> Variant:
	var z := String(Game.world_state.get("map_dest", ""))
	if z.begins_with("part:"):
		var l := _lead(z)
		if l.is_empty():
			Game.world_state.erase("map_dest")         # found (or the car runs): the lead is done
			return null
		return (l[2] as Vector3) + Vector3(0, 1.0, 0)
	return (houses[z]["door"] as Vector3) + Vector3(0, 1.6, 0) if z != "" and houses.has(z) else null


## The marked house for the HUD's diamond: its front entrance, "<STREET> HOUSE", and whether it leads now
## (out on a supply run) or only when no story destination is showing.
func map_dest_marker() -> Array:
	var at: Variant = dest_point()
	if at == null:
		return []
	var z := String(Game.world_state.get("map_dest", ""))
	var out: bool = world.expedition != null and world.expedition.active()
	if z.begins_with("part:"):
		return [at, String(_lead(z)[3]) if not _lead(z).is_empty() else "CAR PART", out]
	return [at, _street(z) + " HOUSE", out]


func _draw_dest() -> void:
	var at: Variant = dest_point()
	if at == null or open or not world.player.visible or (world.get("_cine") and is_instance_valid(world.get("_cine"))):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs := dest_mark.size
	var d: float = cam.global_position.distance_to(at)
	var font: Font = VeilUI.font()
	if not cam.is_position_behind(at):
		var sp := cam.unproject_position(at)
		if Rect2(Vector2.ZERO, vs).grow(-20).has_point(sp):
			var pts := PackedVector2Array([sp + Vector2(0, -9), sp + Vector2(9, 0), sp + Vector2(0, 9), sp + Vector2(-9, 0), sp + Vector2(0, -9)])
			dest_mark.draw_polyline(pts, AMBER, 2.0)
			dest_mark.draw_string(font, sp + Vector2(-26, 24), "SEARCH  %d m" % int(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER)
			return
	var local := cam.global_transform.affine_inverse() * (at as Vector3)
	var dir := Vector2(local.x, -local.y)
	if dir.length() < 0.01:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var c := vs * 0.5
	var e := c + dir * minf(vs.x * 0.45 / maxf(absf(dir.x), 0.01), vs.y * 0.42 / maxf(absf(dir.y), 0.01))
	dest_mark.draw_colored_polygon(PackedVector2Array([e + dir * 10.0, e + dir.orthogonal() * 6.0, e - dir.orthogonal() * 6.0]), AMBER)


func _process(delta: float) -> void:
	if world == null:
		return
	dest_mark.queue_redraw()
	_t -= delta
	if _t <= 0.0 and not houses.is_empty():
		_t = 0.25
		_track()
	_maybe_give(delta)
	if open:
		panel.queue_redraw()
		if not world.player.visible or (world.get("_cine") and is_instance_valid(world.get("_cine"))):
			close()                                    # a cinematic took over: never leave the map up
