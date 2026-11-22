extends Node
class_name VeilStreetLife
## Review notes #92 / #93: the street furniture is alive. Traffic lights step through green -> amber -> red -> green (the lens materials are switched per light, one phase offset each); street lamps flicker from
## time to time (a short stutter of a lamp near the player, never one the Colossus took down: those leave the "veil_streetlight" group). After the Veil the signals stop cycling and blink amber (the town is dead).
const GREEN := 9.0
const AMBER := 2.2
const RED := 9.0
var world: Node
var _signals: Array = []            # {"mi": MeshInstance3D, "r": int, "a": int, "g": int, "mats": [r,a,g], "off": float}
var _t := 0.0
var _flick_t := 3.0
var _blink := false
var report := {"signals": 0, "flickers": 0}


func setup(w: Node) -> void:
	world = w
	for part in ["Core", "Extension"]:
		var root := w.get_node_or_null(part)
		if root == null:
			continue
		for mi in root.find_children("SP_TrafficLight_*", "MeshInstance3D", true, false):
			_add_signal(mi)
	report["signals"] = _signals.size()
	set_process(true)


func _add_signal(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var idx := {"Red": -1, "Amber": -1, "Green": -1}
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		var n := String(m.resource_name) if m else ""
		for k in idx:
			if n.ends_with("Lens" + k):
				idx[k] = s
	if idx["Red"] < 0 or idx["Amber"] < 0 or idx["Green"] < 0:
		return
	var mats: Array = []
	for k in ["Red", "Amber", "Green"]:
		var m: StandardMaterial3D = (mi.mesh.surface_get_material(idx[k]) as StandardMaterial3D).duplicate()
		mi.set_surface_override_material(idx[k], m)
		mats.append(m)
	_signals.append({"mi": mi, "s": [idx["Red"], idx["Amber"], idx["Green"]], "mats": mats, "off": randf() * (GREEN + AMBER + RED), "base": [1.4, 1.4, 1.4]})
	_apply(_signals[-1], 0.0)


func phase_at(t: float) -> int:        ## 0 red, 1 amber, 2 green
	var c := fposmod(t, GREEN + AMBER + RED)
	if c < GREEN:
		return 2
	if c < GREEN + AMBER:
		return 1
	return 0


func _apply(sg: Dictionary, t: float) -> void:
	var ph: int = phase_at(t + float(sg["off"]))
	if _blink:
		ph = 1 if fmod(t, 1.2) < 0.6 else -1
	for i in 3:
		var lit := (i == ph)
		var m: StandardMaterial3D = sg["mats"][i]
		m.emission_energy_multiplier = float(sg["base"][i]) * 1.6 if lit else 0.05
		m.albedo_color.a = 1.0


func _process(delta: float) -> void:
	_t += delta
	if world == null or not is_instance_valid(world):
		return
	_blink = _veil_up()
	for sg in _signals:
		_apply(sg, _t)
	_edge_t -= delta
	if _edge_t <= 0.0:
		_edge_t = 0.25
		_edge_check()
	_flick_t -= delta
	if _flick_t <= 0.0:
		_flick_t = randf_range(2.5, 7.0)
		_flicker()


func _veil_up() -> bool:
	return Game.has_flag("p3_stepped_out")


func _flicker() -> void:
	var pl = world.get("player")
	if pl == null:
		return
	var near: Array = []
	for l in get_tree().get_nodes_in_group("veil_streetlight"):
		if l is Light3D and l.visible and l.global_position.distance_to(pl.global_position) < 55.0:
			near.append(l)
	if near.is_empty():
		return
	var l: Light3D = near[randi() % near.size()]
	if l.has_meta("flickering"):
		return
	l.set_meta("flickering", true)
	var e0: float = l.light_energy
	var tw := create_tween()
	for k in randi_range(2, 4):
		tw.tween_property(l, "light_energy", e0 * randf_range(0.0, 0.35), randf_range(0.03, 0.07))
		tw.tween_property(l, "light_energy", e0 * randf_range(0.8, 1.3), randf_range(0.03, 0.12))
	tw.tween_callback(func():
		if is_instance_valid(l):
			l.light_energy = e0
			l.remove_meta("flickering"))
	report["flickers"] += 1


# ------------------------------------------------------------------ the edge of the map (review note #90)
const MAP := Rect2(-160.0, -160.0, 560.0, 760.0)      ## the town's ground (TOWN_Ground_Game)
const WARN := 35.0
const KILL := 6.0
var _edge_t := 1.0
var _warned := false
var _edge_busy := false


func edge_distance(p: Vector3) -> float:       ## metres to the map's edge (negative = beyond it)
	return minf(minf(p.x - MAP.position.x, MAP.end.x - p.x), minf(p.z - MAP.position.y, MAP.end.y - p.z))


func _edge_check() -> void:
	var pl = world.get("player")
	if pl == null or _edge_busy or pl.health <= 0.0:
		return
	var p: Vector3 = pl.global_position
	if p.y < -3.0 or p.y > 40.0:
		return                                        # underground / the roofs: other places
	var d := edge_distance(p)
	if d < -60.0:
		return                                        # far beyond: a set-piece somewhere else, not the town's edge
	if d < WARN and d > KILL:
		if not _warned:
			_warned = true
			world.hud.set_hint("The forest thickens. Something out there is watching - turn back.")
			Sfx.play("colossus_call", p + Vector3(0, 30, 0), -4.0, 1.4)
	elif d >= WARN:
		_warned = false
	if d <= KILL:
		_edge_busy = true
		world.hud.set_hint("")
		var bs = world.get_node_or_null("EdgeSnatch")
		if bs == null:
			bs = load("res://game/world/bird_snatch.gd").new()
			bs.name = "EdgeSnatch"
			world.add_child(bs)
			bs.setup(world)
		bs.misses = 1                                  # no second chance out here
		bs.trigger(true)
		report["edge_kills"] = int(report.get("edge_kills", 0)) + 1
		await get_tree().create_timer(12.0).timeout
		_edge_busy = false
