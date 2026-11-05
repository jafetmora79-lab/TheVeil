extends CanvasLayer
class_name VeilNavMap
## THE VEIL - light navigation help (no GPS, no pathfinding, no new save data):
##   * the way back to the current shelter: when no story destination is set and the player is out (> 25 m from it),
##     the HUD marker points to the shelter's door (the supermarket; then the mill-worker house; in the finale's
##     opening, the old maintenance station). A shelter that has fallen is never shown.
##   * M: a simple worn map of Greyhaven - the main roads (the opening drive's route from world_data.json and the
##     later roads out west, authored), the places found so far (from story flags, so old saves work), the shelter,
##     the current destination and the player. M or Esc closes it; the player cannot move while it is open.
## Secret encounters and Easter eggs are never shown.

const BOUNDS := Rect2(-170.0, -170.0, 580.0, 780.0)        # world x / z covered by the map
const WEST_ROADS := [
	[Vector2(-24, 0), Vector2(-46, 0), Vector2(-60, 2), Vector2(-92, 5), Vector2(-104, 2)],                # the main road west
	[Vector2(-92, 8), Vector2(-100, 2), Vector2(-108, -16), Vector2(-113, -36), Vector2(-104, -70), Vector2(-96, -88)],   # the farm road
	[Vector2(-104, 2), Vector2(-114, 18), Vector2(-121, 31), Vector2(-125, 60)],                          # the old road north-west
	[Vector2(-88, 0), Vector2(-82, -12), Vector2(-80, -24)]]                                              # to the maintenance station
## name, world x/z (or a node path to read it from), the flag that reveals it ("" = known from the start)
const PLACES := [["Home", "Residential/Houses/PLAYER_HOME", ""], ["Video Game Shop", "Commercial/GAME_SHOP", ""],
	["Supermarket", "Commercial/SUPERMARKET", ""], ["Mill-Worker House", Vector2(-92, 14), "ch10_started"],
	["Farmhouses", Vector2(-100, -95), "ch11_started"], ["Maintenance Station", Vector2(-80, -28), "ch12_started"],
	["Old District", Vector2(-125, 50), "ch13_started"]]

var world: Node
var panel: Control
var open := false
var _held := {}
var _route: Array = []


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
	add_child(panel)
	world.hud.marker_fallback = shelter_marker


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
		show_map()
		get_viewport().set_input_as_handled()


func show_map() -> void:
	open = true
	var p = world.player
	_held = {"controls": p.controls_enabled, "look": p.look_enabled}
	p.controls_enabled = false
	p.look_enabled = false
	p.velocity = Vector3.ZERO
	panel.visible = true
	panel.queue_redraw()


func close() -> void:
	open = false
	panel.visible = false
	var p = world.player
	if p:
		p.controls_enabled = bool(_held.get("controls", true))
		p.look_enabled = bool(_held.get("look", true))


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


func _to_map(r: Rect2, at: Vector2) -> Vector2:
	var k := minf(r.size.x / BOUNDS.size.x, r.size.y / BOUNDS.size.y)
	var used := BOUNDS.size * k
	var o := r.position + (r.size - used) * 0.5
	return o + (at - BOUNDS.position) * k


func _draw_map() -> void:
	var vs := panel.size
	var side := minf(vs.x, vs.y) * 0.9
	var r := Rect2((vs - Vector2(side, side)) * 0.5, Vector2(side, side))
	var ink := Color(0.22, 0.2, 0.16)
	var paper := Color(0.72, 0.68, 0.56)
	var font: Font = VeilUI.font()
	panel.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	panel.draw_rect(r, paper)
	panel.draw_rect(r.grow(-6), Color(0.66, 0.62, 0.5), false, 2.0)
	panel.draw_string(font, r.position + Vector2(18, 30), "GREYHAVEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	# roads
	var line := []
	for v in _route:
		line.append(_to_map(r, v))
	if line.size() > 1:
		panel.draw_polyline(PackedVector2Array(line), Color(0.35, 0.32, 0.26), 3.0)
	for road in WEST_ROADS:
		if not Game.has_flag("ch10_started"):
			break                                      # roads out west once the group has gone that way
		var pts := []
		for v in road:
			pts.append(_to_map(r, v))
		panel.draw_polyline(PackedVector2Array(pts), Color(0.4, 0.36, 0.28), 2.0)
	# places
	for pl in places():
		var at := _to_map(r, pl[1])
		panel.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), ink)
		panel.draw_string(font, at + Vector2(8, -6), String(pl[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	# the shelter
	var s := shelter()
	if not s.is_empty():
		var sp := _to_map(r, Vector2(s[0].x, s[0].z))
		panel.draw_circle(sp, 8.0, Color(0.2, 0.42, 0.25))
		panel.draw_string(font, sp + Vector2(10, 14), String(s[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.15, 0.32, 0.18))
	# the current destination (only a real story destination)
	var t: Variant = world.hud._mk_target
	var tp: Variant = (t as Node3D).global_position if t is Node3D and is_instance_valid(t) else (t if t is Vector3 else null)
	if tp != null:
		var dp := _to_map(r, Vector2(tp.x, tp.z))
		panel.draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -8), dp + Vector2(8, 0), dp + Vector2(0, 8), dp + Vector2(-8, 0)]), Color(0.6, 0.12, 0.08))
	# the player
	var pp: Vector3 = world.player.global_position
	var me := _to_map(r, Vector2(pp.x, pp.z))
	var fwd: Vector3 = -world.player.global_transform.basis.z
	var a := atan2(fwd.z, fwd.x)
	var tri := PackedVector2Array([me + Vector2(cos(a), sin(a)) * 11.0, me + Vector2(cos(a + 2.5), sin(a + 2.5)) * 7.0, me + Vector2(cos(a - 2.5), sin(a - 2.5)) * 7.0])
	panel.draw_colored_polygon(tri, Color(0.08, 0.1, 0.12))
	# legend
	var ly := r.end.y - 70
	panel.draw_circle(Vector2(r.position.x + 24, ly), 6.0, Color(0.2, 0.42, 0.25))
	panel.draw_string(font, Vector2(r.position.x + 36, ly + 5), "Shelter", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	panel.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 24, ly + 14), Vector2(r.position.x + 30, ly + 20), Vector2(r.position.x + 24, ly + 26), Vector2(r.position.x + 18, ly + 20)]), Color(0.6, 0.12, 0.08))
	panel.draw_string(font, Vector2(r.position.x + 36, ly + 25), "Where you need to go", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	panel.draw_rect(Rect2(Vector2(r.position.x + 20, ly + 36), Vector2(8, 8)), ink)
	panel.draw_string(font, Vector2(r.position.x + 36, ly + 45), "Places you know     Arrow: you     M / Esc: close", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)


func _process(_d: float) -> void:
	if open:
		panel.queue_redraw()
		if not world.player.visible or (world.get("_cine") and is_instance_valid(world.get("_cine"))):
			close()                                    # a cinematic took over: never leave the map up
