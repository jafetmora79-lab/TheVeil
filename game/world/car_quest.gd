extends Node
class_name VeilCarQuest
## THE VEIL - the car repair as a scavenging quest (a child of the expedition controller).
##
## Four parts, each a real place in town with its own short, hands-on interaction (game/data/expedition.json
## "vehicle_parts", "site"):
##   gas_can  - a red gas canister beside a pump at the gas station: [E] Pick Up Gas Canister (a reach down for it)
##   battery  - the delivery van behind the supermarket, hood up: Inspect Engine -> Disconnect Negative Cable ->
##              Disconnect Positive Cable -> Pull Out Battery (a click effort meter)
##   fuse     - the damaged sedan on the west road: Inspect Vehicle -> Open Driver Door -> Open Fuse Panel ->
##              Inspect Fuse -> Pull Fuse
##   relay    - a pickup out past the lot, its hood up, a Shellcrawler guarding it. A car alarm nearby draws it off
##              to investigate (it really walks there, lingers, comes back); or the player goes straight in and
##              may be grabbed (the shared struggle: BREAK FREE). The Crab is never killed, removed in view or
##              teleported in view; nothing forces the encounter.
## Every step is saved in Game.world_state["car_quest"] (and the parts' "exp/part_<id>" keys of older saves count as
## taken). Fitting the parts and starting the engine happen at the player's own car (expedition.gd: the checklist).

const PARTS := "res://game/props/car_parts/"
const GAS_CAN := preload("res://game/props/car_parts/GasCanister.tscn")
const BATTERY := preload("res://game/props/car_parts/CarBattery.tscn")
const FUSE_PANEL := preload("res://game/props/car_parts/FusePanel.tscn")
const RELAY := preload("res://game/props/car_parts/StarterRelay.tscn")

const CARDS := {
	"fuel_can": ["GAS CANISTER ACQUIRED", "Contains enough fuel to get the car running."],
	"car_battery": ["CAR BATTERY ACQUIRED", "Heavy, but it should still work."],
	"car_fuse": ["REPLACEMENT FUSE ACQUIRED", "One less thing keeping that car off the road."],
	"starter_relay": ["STARTER RELAY ACQUIRED", "Small. The car won't turn over without it."],
}

const PULL_PER_CLICK := 0.075        ## ~14 clicks
const PULL_DECAY := 0.11             ## per second
const PULL_TIME := 9.0               ## then the grip slips: try again (nothing lost)
const ALARM_SECONDS := 16.0
const ALARM_USES := 3
const ALARM_COOLDOWN := 22.0
const CRAB_LEASH := 30.0
const CRAB_SPAWN_MIN := 30.0          ## never closer than this when it first appears, and never in view

var ex: Node                          ## VeilExpedition
var world: Node
var placed := false
var ready_sites := false
var sites := {}                       ## part id -> {"cfg", "root", ...}
var steps := {}                       ## "<site>/<step>" -> Interactable
var anchors := {}                     ## part item -> the anchor Interactable (map leads, diamonds; taken = acquired)
var crab_ai: Node = null
var busy := false
var _alarm_t := 0.0
var _alarm_cool := 0.0
var _alarm_player: AudioStreamPlayer3D
var _alarm_light: OmniLight3D
var _scrape_t := 6.0
var _save_t := 0.0
var _streams := {}
# the effort meter (battery pull)
var pulling := false
var pull := 0.0
var _pull_t := 0.0
var _ui: CanvasLayer
var _bar: ColorRect
var _title: Label


func setup(e: Node) -> void:
	ex = e
	world = e.world
	name = "CarQuest"
	_streams["click"] = Sfx._make(0.09, func(t: float, i: int) -> float: return (Sfx._noise(i) * 0.6 + sin(TAU * 2400.0 * t) * 0.4) * exp(-t * 70.0))
	_streams["creak"] = Sfx._make(0.9, func(t: float, i: int) -> float: return sin(TAU * (160.0 + 70.0 * sin(t * 6.0)) * t) * 0.22 * (0.55 + 0.45 * sin(t * 95.0)) * minf(t * 8.0, 1.0) * exp(-t * 2.2) + Sfx._noise(i) * 0.03)
	_streams["crank"] = Sfx._make(1.6, func(t: float, i: int) -> float: return (Sfx._noise(i) * 0.25 + sin(TAU * 52.0 * t) * 0.5) * (0.55 + 0.45 * sin(TAU * 7.5 * t)) * minf(t * 10.0, 1.0) * minf((1.6 - t) * 6.0, 1.0))
	_streams["catch"] = Sfx._make(2.4, func(t: float, i: int) -> float: return (sin(TAU * 38.0 * t) * 0.55 + sin(TAU * 76.0 * t) * 0.25 + Sfx._noise(i) * 0.12) * minf(t * 3.0, 1.0) * (1.0 - 0.5 * clampf((t - 0.8) / 1.6, 0.0, 1.0)) * (1.0 + 0.3 * exp(-t * 4.0)))
	_streams["alarm"] = Sfx._make(0.5, func(t: float, _i: int) -> float: return sin(TAU * (880.0 if t < 0.25 else 660.0) * t) * 0.35, true)
	_streams["thud"] = Sfx._make(0.3, func(t: float, i: int) -> float: return (Sfx._noise(i) * 0.4 + sin(TAU * 70.0 * t) * 0.7) * exp(-t * 16.0))
	_build_ui()


## The quest state (saved with the game).
func q() -> Dictionary:
	if not Game.world_state.has("car_quest"):
		Game.world_state["car_quest"] = {}
	return Game.world_state["car_quest"]


func part_state(item: String) -> Dictionary:
	var d: Dictionary = q().get(item, {})
	q()[item] = d
	return d


## This part is in the player's hands (or already in the car): the site has nothing more to give.
func acquired(item: String) -> bool:
	if bool(part_state(item).get("taken", false)) or ex.installed(item) or Game.has_item(item):
		return true
	var old: Dictionary = Game.world_state.get("exp/part_" + item, {})
	return bool(old.get("taken", false))                 # (a save from before the quest: the part was picked up)


func _cfg(site: String) -> Dictionary:
	for c in ex.cfg.get("vehicle_parts", []):
		if String(c.get("site", "")) == site:
			return c
	return {}


# ------------------------------------------------------------------ placing the sites
## Once the town is the group's (Chapter 5 on, the supermarket still standing): the wrecks, the canister, the alarm car.
func place() -> void:
	if placed:
		return
	placed = true
	var props := {}
	for c in ex.cfg.get("vehicle_parts", []):
		if c.has("prop"):
			props[String(c["site"])] = _prop(c)
	# their colliders are in the physics space from the next frames on: the parts are seated on them after that
	await get_tree().physics_frame
	await get_tree().physics_frame
	for c in ex.cfg.get("vehicle_parts", []):
		var pr: Node3D = props.get(String(c.get("site", "")))
		match String(c.get("site", "")):
			"gas_can":
				_place_gas_can(c)
			"battery":
				if pr:
					_place_battery(c, pr)
			"fuse":
				if pr:
					_place_fuse(c, pr)
			"relay":
				if pr:
					_place_relay(c, pr)
	ready_sites = true
	ex._part_markers()


func _prop(c: Dictionary, key := "prop") -> Node3D:
	var pr: Dictionary = c.get(key, {})
	var ps := load(String(pr.get("scene", ""))) as PackedScene if pr.has("scene") else null
	if ps == null:
		return null
	var o := ps.instantiate() as Node3D
	o.name = "EXP_Wreck_" + String(c["id"]) + ("" if key == "prop" else "_" + key)
	world.add_child(o)
	var p: Array = pr["pos"]
	o.global_transform = Transform3D(Basis(Vector3.UP, float(pr.get("yaw", 0.0))), Vector3(p[0], p[1], p[2]))
	_ground(o)
	return o


## Straight down onto the ground (layer 1) under it, ignoring its own colliders.
func _ground(n: Node3D, at := Vector3.INF) -> void:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var from: Vector3 = n.global_position if not at.is_finite() else at
	var exl: Array[RID] = [ex._player().get_rid()]
	for co in n.find_children("*", "CollisionObject3D", true, false):
		exl.append((co as CollisionObject3D).get_rid())
	if n is CollisionObject3D:
		exl.append((n as CollisionObject3D).get_rid())
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.2, from - Vector3.UP * 3.0, 1, exl))
	if hit:
		n.global_position.y = (hit["position"] as Vector3).y + 0.002


## The top of a vehicle's own collision under a point (world), or INF.
func _surface(vehicle: Node3D, at: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q2 := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at - Vector3.UP * 2.0, 1)
	q2.exclude = [ex._player().get_rid()]
	var hit := space.intersect_ray(q2)
	if hit and vehicle.is_ancestor_of(hit["collider"] as Node):
		return (hit["position"] as Vector3).y
	return INF


## A use point: a Node3D under `parent` at local `pos` with an [E] box of `size` (custom, prompt per step).
func _step(key: String, parent: Node3D, pos: Vector3, size: Vector3, prompt: String, cb: Callable) -> Interactable:
	var s := Node3D.new()
	s.name = "CQ_" + key.replace("/", "_")
	parent.add_child(s)
	s.position = pos
	var it := Interactable.attach(s, {"kind": "custom", "label": key, "prompt_text": prompt})
	var cs := it.get_child(0) as CollisionShape3D
	(cs.shape as BoxShape3D).size = size
	cs.position = Vector3.ZERO
	it.used.connect(func(_b: Node) -> void: cb.call())
	steps[key] = it
	return it


## The anchor of a part's site: where its diamond and map lead point; `taken` once the part is in hand.
func _anchor(item: String, parent: Node3D, pos: Vector3) -> Interactable:
	var s := Node3D.new()
	s.name = "CQ_Anchor_" + item
	parent.add_child(s)
	s.position = pos
	var it := Interactable.attach(s, {"kind": "custom", "label": item, "prompt_text": ""})
	it.set_deferred("collision_layer", 0)
	it.taken = acquired(item)
	anchors[item] = it
	ex.its["exp/part_" + item] = it
	return it


func _on(key: String, on: bool) -> void:
	var it: Interactable = steps.get(key)
	if it == null:
		return
	it.collision_layer = 8 if on and not busy else 0
	it.monitorable = on


# ---- the gas canister
func _place_gas_can(c: Dictionary) -> void:
	var can := GAS_CAN.instantiate() as Node3D
	can.name = "CQ_GasCanister"
	world.add_child(can)
	var p: Array = c["pos"]
	can.global_transform = Transform3D(Basis(Vector3.UP, float(c.get("yaw", 0.0))), Vector3(p[0], p[1], p[2]))
	_ground(can)
	sites["fuel_can"] = {"root": can}
	_anchor("fuel_can", can, Vector3(0, 0.2, 0))
	var it := _step("gas/take", can, Vector3(0, 0.2, 0), Vector3(0.6, 0.55, 0.5), "[E] Pick Up Gas Canister", _take_gas)
	if acquired("fuel_can"):
		can.visible = false
	_on("gas/take", not acquired("fuel_can"))
	it.set_meta("veil_car_part", "fuel_can")


func _take_gas() -> void:
	if busy or acquired("fuel_can"):
		return
	busy = true
	_on("gas/take", false)
	var can: Node3D = sites["fuel_can"]["root"]
	await _peek(can.global_position + Vector3(0, 0.15, 0), 0.55, 0.25, true)
	can.visible = false
	_acquire("fuel_can")
	await _peek_back()
	busy = false


# ---- the battery (delivery van)
func _place_battery(c: Dictionary, van: Node3D) -> void:
	var local: Array = c.get("battery_local", [0.38, 0.0, -2.0])
	var bat := BATTERY.instantiate() as Node3D
	bat.name = "CQ_Battery"
	van.add_child(bat)
	var lp := Vector3(local[0], 0.0, local[2])
	var top := _surface(van, van.global_transform * Vector3(lp.x, 2.0, lp.z))
	bat.position = Vector3(lp.x, (top - van.global_position.y) - 0.04 if is_finite(top) else float(local[1]), lp.z)
	bat.rotation.y = PI * 0.5                        # its terminals face the front of the van
	sites["car_battery"] = {"root": van, "battery": bat, "base": bat.transform}
	var b := bat.position
	_anchor("car_battery", van, b + Vector3(0, 0.25, 0))
	var box := Vector3(1.0, 0.9, 0.9)
	_step("battery/inspect", van, b + Vector3(0, 0.45, -0.15), box, "[E] Inspect Engine", _battery_inspect)
	_step("battery/neg", bat, Vector3(-0.095, 0.3, 0.05), Vector3(0.32, 0.4, 0.34), "[E] Disconnect Negative Cable", _battery_cable.bind("neg"))
	_step("battery/pos", bat, Vector3(0.095, 0.3, 0.05), Vector3(0.32, 0.4, 0.34), "[E] Disconnect Positive Cable", _battery_cable.bind("pos"))
	_step("battery/pull", van, b + Vector3(0, 0.45, -0.15), box, "[E] Pull Out Battery", _battery_pull)
	var st := part_state("car_battery")
	for side in ["neg", "pos"]:
		if bool(st.get(side, false)):
			_unclamp(bat, side, true)
	if acquired("car_battery"):
		bat.visible = false
	_battery_steps()


func _battery_steps() -> void:
	var st := part_state("car_battery")
	var done := acquired("car_battery")
	var ins := bool(st.get("inspected", false))
	_on("battery/inspect", not done and not ins)
	_on("battery/neg", not done and ins and not bool(st.get("neg", false)))
	_on("battery/pos", not done and ins and bool(st.get("neg", false)) and not bool(st.get("pos", false)))
	_on("battery/pull", not done and ins and bool(st.get("neg", false)) and bool(st.get("pos", false)))


func _battery_inspect() -> void:
	if busy:
		return
	busy = true
	_battery_steps()
	var bat: Node3D = sites["car_battery"]["battery"]
	await _peek(bat.global_position + Vector3(0, 0.12, 0), 0.75, 1.6)
	_say("The battery still looks usable. I'll need to disconnect it.", 3.2)
	part_state("car_battery")["inspected"] = true
	await _peek_back()
	busy = false
	_battery_steps()
	_save()


func _battery_cable(side: String) -> void:
	var st := part_state("car_battery")
	if busy or not bool(st.get("inspected", false)) or (side == "pos" and not bool(st.get("neg", false))):
		return
	busy = true
	_battery_steps()
	var bat: Node3D = sites["car_battery"]["battery"]
	var term := bat.get_node("Terminal" + ("Neg" if side == "neg" else "Pos")) as Node3D
	await _peek(term.global_position, 0.8, 0.15)
	_snd("click", term.global_position, -2.0)
	_unclamp(bat, side, false)
	await get_tree().create_timer(0.45).timeout
	st[side] = true
	await _peek_back()
	busy = false
	_battery_steps()
	_save()


## The clamp lifts off its post and is laid back along its cable (out of the way).
func _unclamp(bat: Node3D, side: String, instant: bool) -> void:
	var sfx := "Neg" if side == "neg" else "Pos"
	for n in ["Clamp" + sfx, "Cable" + sfx]:
		var m := bat.get_node_or_null(n) as Node3D
		if m == null:
			continue
		var to := m.position + Vector3(0.03 * (-1.0 if side == "neg" else 1.0), 0.07, 0.11)
		var rot := Vector3(deg_to_rad(-35.0), 0.0, 0.0)
		if instant:
			m.position = to
			m.rotation = rot
		else:
			var tw := m.create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
			tw.tween_property(m, "position", to, 0.35)
			tw.tween_property(m, "rotation", rot, 0.35)


func _battery_pull() -> void:
	var st := part_state("car_battery")
	if busy or acquired("car_battery") or not (bool(st.get("neg", false)) and bool(st.get("pos", false))):
		return
	busy = true
	_battery_steps()
	var bat: Node3D = sites["car_battery"]["battery"]
	await _peek(bat.global_position + Vector3(0, 0.2, 0), 0.7, 0.1)
	var won: bool = await effort("CLICK REPEATEDLY — PULL BATTERY")
	if won:
		var base: Transform3D = sites["car_battery"]["base"]
		var tw := bat.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(bat, "position", base.origin + Vector3(0, 0.45, -0.25), 0.6)
		await tw.finished
		_snd("thud", bat.global_position, -6.0)
		bat.visible = false
		_acquire("car_battery")
	else:
		_say("Too heavy at this angle. Get a better grip.", 2.6)
	await _peek_back()
	busy = false
	_battery_steps()


# ---- the fuse (damaged sedan)
func _place_fuse(c: Dictionary, car: Node3D) -> void:
	var door := car.find_child("Door_FL", true, false) as Node3D
	var panel := FUSE_PANEL.instantiate() as Node3D
	panel.name = "CQ_FusePanel"
	car.add_child(panel)
	var lp: Array = c.get("panel_local", [-0.6, 0.62, -0.5])
	panel.position = Vector3(lp[0], lp[1], lp[2])
	panel.rotation.y = -PI * 0.5                       # its face to the open door
	var st := part_state("car_fuse")
	sites["car_fuse"] = {"root": car, "door": door, "door_base": door.transform.basis if door else Basis(), "panel": panel}
	if door:
		door.transform.basis = Basis()                  # shut (the model has it ajar)
		sites["car_fuse"]["door_base"] = Basis()
		if bool(st.get("door", false)):
			door.transform.basis = Basis(Vector3.UP, deg_to_rad(-68.0))
	var cover := panel.get_node("Cover") as Node3D
	if bool(st.get("panel", false)):
		cover.rotation.y = deg_to_rad(-100.0)
	var good := panel.get_node("Fuse_Good") as Node3D
	if acquired("car_fuse"):
		good.visible = false
	_anchor("car_fuse", car, panel.position)
	var outside := Vector3(-1.05, 0.95, -0.35)          # beside the driver's door, in reach from outside
	_step("fuse/inspect", car, outside, Vector3(0.6, 1.2, 1.6), "[E] Inspect Vehicle", _fuse_inspect)
	_step("fuse/door", car, outside, Vector3(0.6, 1.2, 1.6), "[E] Open Driver Door", _fuse_door)
	_step("fuse/panel", car, Vector3(-0.95, 0.65, -0.5), Vector3(0.7, 0.55, 0.6), "[E] Open Fuse Panel", _fuse_panel)
	_step("fuse/look", car, Vector3(-0.95, 0.65, -0.5), Vector3(0.7, 0.55, 0.6), "[E] Inspect Fuse", _fuse_look)
	_step("fuse/pull", car, Vector3(-0.95, 0.65, -0.5), Vector3(0.7, 0.55, 0.6), "[E] Pull Fuse", _fuse_pull)
	_fuse_steps()


func _fuse_steps() -> void:
	var st := part_state("car_fuse")
	var done := acquired("car_fuse")
	var a := bool(st.get("inspected", false))
	var b := bool(st.get("door", false))
	var c := bool(st.get("panel", false))
	var d := bool(st.get("looked", false))
	_on("fuse/inspect", not done and not a)
	_on("fuse/door", not done and a and not b)
	_on("fuse/panel", not done and b and not c)
	_on("fuse/look", not done and c and not d)
	_on("fuse/pull", not done and d)
	var good := (sites["car_fuse"]["panel"] as Node3D).get_node("Fuse_Good") as GeometryInstance3D
	if good:
		good.material_overlay = _glow() if (c and not done) else null


var _glow_mat: StandardMaterial3D


## The one fuse worth taking, picked out faintly (not a beam: a dull warm sheen on it alone).
func _glow() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.albedo_color = Color(0.35, 0.28, 0.08)
	return _glow_mat


func _fuse_inspect() -> void:
	if busy:
		return
	busy = true
	_fuse_steps()
	var car: Node3D = sites["car_fuse"]["root"]
	await _peek(car.global_transform * Vector3(-0.4, 0.9, -0.4), 0.4, 1.2)
	_say("Dash is intact. If the fuse box is, there's a fuse in there I can use.", 3.2)
	part_state("car_fuse")["inspected"] = true
	await _peek_back()
	busy = false
	_fuse_steps()
	_save()


func _fuse_door() -> void:
	if busy:
		return
	busy = true
	_fuse_steps()
	var door: Node3D = sites["car_fuse"]["door"]
	if door:
		_snd("creak", door.global_position, -2.0)
		var tw := door.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(door, "transform:basis", Basis(Vector3.UP, deg_to_rad(-68.0)), 1.0)
		await tw.finished
	part_state("car_fuse")["door"] = true
	busy = false
	_fuse_steps()
	_save()


func _fuse_panel() -> void:
	if busy:
		return
	busy = true
	_fuse_steps()
	var panel: Node3D = sites["car_fuse"]["panel"]
	await _peek(panel.global_position, 0.75, 0.1)          # leaning in under the dashboard
	_snd("click", panel.global_position, -6.0)
	var cover := panel.get_node("Cover") as Node3D
	var tw := cover.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(cover, "rotation:y", deg_to_rad(-100.0), 0.4)
	await tw.finished
	part_state("car_fuse")["panel"] = true
	_fuse_steps()
	await get_tree().create_timer(0.5).timeout
	await _peek_back()
	busy = false
	_fuse_steps()
	_save()


func _fuse_look() -> void:
	if busy:
		return
	busy = true
	_fuse_steps()
	var good := (sites["car_fuse"]["panel"] as Node3D).get_node("Fuse_Good") as Node3D
	await _peek(good.global_position, 0.85, 1.4)
	_say("This one looks intact. Might fit the other car.", 3.0)
	part_state("car_fuse")["looked"] = true
	await _peek_back()
	busy = false
	_fuse_steps()
	_save()


func _fuse_pull() -> void:
	if busy or acquired("car_fuse"):
		return
	busy = true
	_fuse_steps()
	var good := (sites["car_fuse"]["panel"] as Node3D).get_node("Fuse_Good") as Node3D
	await _peek(good.global_position, 0.85, 0.2)
	_snd("click", good.global_position, -4.0)
	var tw := good.create_tween()
	tw.tween_property(good, "position", good.position + Vector3(0, 0, 0.05), 0.2)
	await tw.finished
	good.visible = false
	_acquire("car_fuse")
	await _peek_back()
	busy = false
	_fuse_steps()


# ---- the starter relay (pickup truck, guarded) and the alarm car
func _place_relay(c: Dictionary, truck: Node3D) -> void:
	var hood := truck.find_child("Hood", true, false) as Node3D
	if hood:
		hood.rotation.x = deg_to_rad(52.0)              # up: someone was working on it
	var relay := RELAY.instantiate() as Node3D
	relay.name = "CQ_Relay"
	truck.add_child(relay)
	var lp: Array = c.get("relay_local", [0.45, 0.0, -1.9])
	var top := _surface(truck, truck.global_transform * Vector3(lp[0], 2.0, lp[2]))
	relay.position = Vector3(lp[0], (top - truck.global_position.y) + 0.001 if is_finite(top) else float(lp[1]), lp[2])
	sites["starter_relay"] = {"root": truck, "relay": relay}
	_anchor("starter_relay", truck, relay.position)
	_step("relay/take", truck, relay.position + Vector3(0, 0.3, -0.2), Vector3(0.9, 0.8, 0.9), "[E] Take Starter Relay", _take_relay)
	if acquired("starter_relay"):
		relay.visible = false
	_on("relay/take", not acquired("starter_relay"))
	var alarm := _prop(c, "alarm")
	if alarm:
		sites["starter_relay"]["alarm"] = alarm
		_step("relay/alarm", alarm, Vector3(-1.05, 0.95, -0.3), Vector3(0.6, 1.2, 1.8), "[E] Set Off Car Alarm", set_off_alarm)
		_alarm_prompt()
		_alarm_light = OmniLight3D.new()
		_alarm_light.light_color = Color(1.0, 0.62, 0.2)
		_alarm_light.omni_range = 5.0
		_alarm_light.light_energy = 0.0
		alarm.add_child(_alarm_light)
		_alarm_light.position = Vector3(0, 0.9, -2.3)


func _take_relay() -> void:
	if busy or acquired("starter_relay"):
		return
	busy = true
	_on("relay/take", false)
	var relay: Node3D = sites["starter_relay"]["relay"]
	await _peek(relay.global_position, 0.7, 0.2)
	_snd("click", relay.global_position, -4.0)
	relay.visible = false
	_acquire("starter_relay")
	await _peek_back()
	busy = false


func _alarm_prompt() -> void:
	var used := int(q().get("alarm_uses", 0))
	var it: Interactable = steps.get("relay/alarm")
	if it == null:
		return
	it.prompt_text = "[E] Set Off Car Alarm" if used < ALARM_USES else ""
	_on("relay/alarm", used < ALARM_USES and _alarm_t <= 0.0 and _alarm_cool <= 0.0)


## The beige sedan's alarm: a loud, long whoop. The guard (and anything else hunting nearby) goes to look.
func set_off_alarm() -> void:
	var alarm: Node3D = sites.get("starter_relay", {}).get("alarm")
	if alarm == null or _alarm_t > 0.0 or _alarm_cool > 0.0 or int(q().get("alarm_uses", 0)) >= ALARM_USES:
		return
	q()["alarm_uses"] = int(q().get("alarm_uses", 0)) + 1
	_alarm_t = ALARM_SECONDS
	_alarm_cool = ALARM_COOLDOWN
	_snd("thud", alarm.global_position + Vector3(0, 0.8, 0), -4.0)
	_alarm_player = AudioStreamPlayer3D.new()
	_alarm_player.stream = _streams["alarm"]
	_alarm_player.unit_size = 30.0
	_alarm_player.volume_db = 2.0
	alarm.add_child(_alarm_player)
	_alarm_player.position = Vector3(0, 1.1, 0)
	_alarm_player.play()
	_alarm_prompt()
	var noise := alarm.global_position
	if crab_ai and is_instance_valid(crab_ai):
		crab_ai.investigate(noise + (crab_ai.body.global_position - noise).normalized() * 2.8, 9.0)
	for cr in ex.creatures:
		var ai = cr.get("ai")
		if ai and is_instance_valid(ai) and ai.has_method("investigate") and (ai.body as Node3D).global_position.distance_to(noise) < 45.0:
			ai.investigate(noise, 6.0)
	if int(q()["alarm_uses"]) == 1:
		_say("That'll get its attention.", 2.4)
	_save()


# ------------------------------------------------------------------ the guard
## The Shellcrawler that lives round the pickup: it appears (out of view, a fair way off) once the town is open and
## the relay is still there, patrols the truck, and stays. Never killed; never moved while anyone can see it.
func _crab_tick() -> void:
	var c := _cfg("relay")
	if c.is_empty() or not sites.has("starter_relay") or Game.has_flag("vehicle_repaired"):
		return
	var home := _crab_home()
	if crab_ai == null or not is_instance_valid(crab_ai):
		crab_ai = null
		if acquired("starter_relay") and not q().has("crab_pos"):
			return                                       # (taken before it ever came: it does not turn up now)
		if ex.shelter() != "supermarket" or ex.emergency():
			return
		var at := home
		if q().has("crab_pos"):
			var sp: Array = q()["crab_pos"]
			at = Vector3(sp[0], sp[1], sp[2])
		if not _unseen_spot(at):
			if not _unseen_spot(home):
				return
			at = home
		crab_ai = ex.make_hunter("crab", at, _crab_patrol(home), CRAB_LEASH)
		if crab_ai:
			crab_ai.home = home
			crab_ai.state = "PATROL"
			crab_ai.set("awareness", 0.0)
			crab_ai.body.name = "CQ_GuardCrab"
			crab_ai.set_meta("struggle_force", true)    # a grab here is always the struggle (when one can happen)
			q()["crab_pos"] = [at.x, at.y, at.z]
		return
	var b: Node3D = crab_ai.body
	q()["crab_pos"] = [b.global_position.x, b.global_position.y, b.global_position.z]
	# scraping in the fog: the player hears it before seeing it
	_scrape_t -= 0.25
	var d := b.global_position.distance_to(ex._player().global_position)
	if _scrape_t <= 0.0 and d < 55.0 and d > 9.0:
		_scrape_t = randf_range(5.0, 9.0)
		Sfx.bank_at("cr_creak" if randf() < 0.6 else "cr_walk_loop", b.global_position + Vector3(0, 0.4, 0), -4.0, 9.0)


func _crab_home() -> Vector3:
	var c := _cfg("relay")
	var h: Array = c.get("crab_home", [0, 0, 0])
	var v := Vector3(h[0], h[1], h[2])
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(v + Vector3.UP * 3.0, v - Vector3.UP * 3.0, 1))
	if hit:
		v.y = (hit["position"] as Vector3).y
	return v


func _crab_patrol(home: Vector3) -> Array:
	var c := _cfg("relay")
	var out: Array = [home]
	for p in c.get("crab_patrol", []):
		out.append(Vector3(p[0], home.y, p[2]))
	return out


## Far enough from the player and not in the camera's view (fog or not).
func _unseen_spot(at: Vector3) -> bool:
	var p: Vector3 = ex._player().global_position
	if at.distance_to(p) < CRAB_SPAWN_MIN:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	return not cam.is_position_in_frustum(at + Vector3(0, 0.8, 0)) or at.distance_to(p) > 70.0


# ------------------------------------------------------------------ per tick
var _tick := 0.0


func _process(delta: float) -> void:
	if pulling:
		_pull_tick(delta)
	if _alarm_t > 0.0:
		_alarm_t -= delta
		if _alarm_light:
			_alarm_light.light_energy = 1.6 if fmod(_alarm_t, 0.5) < 0.25 else 0.0
		if _alarm_t <= 0.0:
			if _alarm_player and is_instance_valid(_alarm_player):
				_alarm_player.queue_free()
			if _alarm_light:
				_alarm_light.light_energy = 0.0
			_alarm_prompt()
	if _alarm_cool > 0.0:
		_alarm_cool -= delta
		if _alarm_cool <= 0.0:
			_alarm_prompt()
	_tick -= delta
	if _tick > 0.0 or not ready_sites:
		return
	_tick = 0.25
	_crab_tick()


# ------------------------------------------------------------------ shared bits
## A part in hand: the inventory, its card, the site marked as done, the game saved.
func _acquire(item: String) -> void:
	part_state(item)["taken"] = true
	if not Game.has_item(item):
		Game.add_item(item)
	var a: Interactable = anchors.get(item)
	if a:
		a.taken = true
	_snd_ui("pickup")
	var card: Array = CARDS.get(item, [String(Game.item_info(item).get("name", item)).to_upper() + " ACQUIRED", ""])
	world.hud.location_caption("%s\n%s" % [card[0], card[1]], 2.8)
	ex._part_markers()
	_save()


func _save() -> void:
	if world.has_method("save_if_alive"):
		world.save_if_alive()
	elif world.has_method("save"):
		world.save()


func _say(t: String, secs: float) -> void:
	world.hud.show_subtitle(t)
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(world) and world.hud.sub.text == t:
			world.hud.show_subtitle(""))


func _snd(id: String, at: Vector3, db := 0.0) -> void:
	var s: AudioStream = _streams.get(id)
	if s == null or get_tree().current_scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.unit_size = 5.0
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


func _snd_ui(id: String) -> void:
	Sfx.play(id, ex._player().global_position + Vector3(0, 1.0, 0), -2.0)


var _cam_base := Transform3D()
var _cam_from := Transform3D()
var _cam_lock := false


## First person: the view leans towards a point (reaching, peering in), the player held still meanwhile.
func _peek(at: Vector3, closer: float, hold: float, dip := false) -> void:
	var p: Node3D = ex._player()
	var cam := p.get("camera") as Camera3D
	p.set("controls_enabled", false)
	p.set("look_enabled", false)
	p.set("velocity", Vector3.ZERO)
	if cam == null:
		return
	if not _cam_lock:
		_cam_base = cam.transform
		_cam_lock = true
	_cam_from = cam.global_transform
	var eye := _cam_from.origin
	var d := at - eye
	var to_pos := eye + d.normalized() * clampf(d.length() - 0.45, 0.0, closer)
	if dip:
		to_pos.y = minf(to_pos.y, eye.y - 0.45)          # crouching down to it
	var look := at - to_pos
	if look.length() < 0.05:
		look = -_cam_from.basis.z
	var up := Vector3.UP if absf(look.normalized().y) < 0.98 else Vector3.FORWARD
	var to := Transform3D(Basis.looking_at(look, up), to_pos)
	var from := _cam_from
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(cam):
			cam.global_transform = from.interpolate_with(to, t), 0.0, 1.0, 0.5)
	tw.tween_interval(hold)
	await tw.finished


func _peek_back() -> void:
	var p: Node3D = ex._player()
	var cam := p.get("camera") as Camera3D
	if cam and _cam_lock:
		var from := cam.global_transform
		var to := _cam_from
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(cam):
				cam.global_transform = from.interpolate_with(to, t), 0.0, 1.0, 0.4)
		await tw.finished
		if is_instance_valid(cam):
			cam.transform = _cam_base
	_cam_lock = false
	if float(p.get("health")) > 0.0:
		p.set("controls_enabled", true)
		p.set("look_enabled", true)


# ------------------------------------------------------------------ the effort meter
signal effort_done(won: bool)


## CLICK REPEATEDLY: true once the bar is full, false if the grip slips (time) or the player is hurt meanwhile.
func effort(title: String) -> bool:
	pull = 0.0
	_pull_t = PULL_TIME
	pulling = true
	_title.text = title
	_ui.visible = true
	var p: Node3D = ex._player()
	var hurt := func(_a: float) -> void:
		if pulling:
			_end_pull(false)
	if p.has_signal("hurt"):
		p.connect("hurt", hurt)
	var won: bool = await effort_done
	if p.has_signal("hurt") and p.is_connected("hurt", hurt):
		p.disconnect("hurt", hurt)
	return won


func click() -> void:
	if not pulling:
		return
	pull = minf(pull + PULL_PER_CLICK, 1.0)
	if randf() < 0.35:
		Sfx.bank_at("pl_effort", ex._player().global_position + Vector3(0, 1.4, 0), -8.0, 4.0)


func _input(e: InputEvent) -> void:
	if pulling and e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		click()
		get_viewport().set_input_as_handled()


func _pull_tick(delta: float) -> void:
	if get_tree().paused:
		return
	_pull_t -= delta
	pull = maxf(pull - PULL_DECAY * delta, 0.0)
	_bar.size.x = 260.0 * pull
	if pull >= 1.0:
		_end_pull(true)
	elif _pull_t <= 0.0:
		_end_pull(false)


func _end_pull(won: bool) -> void:
	pulling = false
	_ui.visible = false
	effort_done.emit(won)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	_ui.visible = false
	add_child(_ui)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(c)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	_title = VeilUI.label("", 24)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0.6)
	frame.custom_minimum_size = Vector2(264, 14)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	_bar = ColorRect.new()
	_bar.color = Color(0.86, 0.62, 0.26)
	_bar.position = Vector2(2, 2)
	_bar.size = Vector2(0, 10)
	frame.add_child(_bar)


# ------------------------------------------------------------------ fitting the parts at the player's car
## A short, hands-on fitting at the car (hood, door, fuel cap) - the item is used up. Called by expedition._fit.
func install(id: String) -> void:
	var car: Node3D = world.sedan
	var model := car.get("model") as Node3D
	var hood := model.find_child("Hood", true, false) as Node3D if model else null
	var at_front: Vector3 = car.global_transform * Vector3(0, 0.9, -1.7)
	var at_door: Vector3 = car.global_transform * Vector3(-0.5, 0.8, -0.4)
	var at_cap: Vector3 = car.global_transform * Vector3(-0.85, 0.85, 1.35)
	match id:
		"car_battery", "starter_relay":
			await _hood(hood, true)
			await _peek(at_front, 0.6, 0.2)
			var prop := (BATTERY if id == "car_battery" else RELAY).instantiate() as Node3D
			car.add_child(prop)
			prop.global_position = car.global_transform * (Vector3(0.38, 0.62, -1.75) if id == "car_battery" else Vector3(-0.35, 0.7, -1.6))
			prop.global_rotation.y = car.global_rotation.y + PI * 0.5
			_snd("thud" if id == "car_battery" else "click", prop.global_position, -6.0)
			_say("Battery in. Positive... negative." if id == "car_battery" else "Relay seated.", 2.4)
			await get_tree().create_timer(0.7).timeout
			_snd("click", prop.global_position, -4.0)
			await get_tree().create_timer(0.6).timeout
			if id == "car_battery":
				_snd("click", prop.global_position, -4.0)
				await get_tree().create_timer(0.5).timeout
			await _peek_back()
			await _hood(hood, false)
			prop.queue_free()
		"car_fuse":
			await car.swing_door(true, 0.6)
			await _peek(at_door, 0.5, 0.4)
			_snd("click", at_door, -4.0)
			_say("Fuse in.", 1.8)
			await get_tree().create_timer(0.6).timeout
			await _peek_back()
			await car.swing_door(false, 0.4)
		"fuel_can":
			await _peek(at_cap, 0.55, 0.1, true)
			var can := GAS_CAN.instantiate() as Node3D
			car.add_child(can)
			can.global_position = at_cap + car.global_transform.basis.x * -0.25 + Vector3(0, -0.05, 0)
			can.global_rotation = Vector3(0, car.global_rotation.y, deg_to_rad(60.0))
			_snd("click", at_cap, -6.0)                  # the cap
			Sfx.play("water_run", at_cap, -8.0, 0.8)
			_say("Pouring it in...", 2.2)
			await get_tree().create_timer(2.3).timeout
			can.queue_free()
			_snd("click", at_cap, -6.0)
			await _peek_back()
		_:
			await get_tree().create_timer(0.8).timeout


func _hood(hood: Node3D, open: bool) -> void:
	if hood == null:
		Sfx.play("door_close", world.sedan.global_position + Vector3(0, 0.8, 0), -8.0, 0.6)
		await get_tree().create_timer(0.4).timeout
		return
	if not hood.has_meta("cq_base"):
		hood.set_meta("cq_base", hood.rotation.x)
	var base := float(hood.get_meta("cq_base"))
	_snd("creak" if open else "thud", hood.global_position, -6.0)
	var tw := hood.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(hood, "rotation:x", base + (deg_to_rad(55.0) if open else 0.0), 0.6)
	await tw.finished


## [E] Start Engine, once everything is in: the starter grinds, catches on the second try, it runs.
func start_engine() -> void:
	var car: Node3D = world.sedan
	var at: Vector3 = car.global_transform * Vector3(0, 0.8, -1.2)
	await car.swing_door(true, 0.4)
	await _peek(car.global_transform * Vector3(-0.37, 0.95, -0.35), 0.5, 0.2)
	_snd("crank", at, -2.0)
	await get_tree().create_timer(1.7).timeout
	_say("Come on...", 1.6)
	await get_tree().create_timer(0.6).timeout
	_snd("crank", at, -2.0)
	await get_tree().create_timer(1.1).timeout
	_snd("catch", at, 0.0)
	await get_tree().create_timer(1.2).timeout
	world.hud.location_caption("VEHICLE REPAIRED\nLet's hope it stays that way.", 3.0)
	await _peek_back()
	await car.swing_door(false, 0.4)


## Why the repaired car will not go right now ("" when it will).
func unusable_reason() -> String:
	var car = world.sedan
	if not Game.has_flag("vehicle_repaired"):
		if not ex.installed("car_battery"):
			return "BATTERY MISSING"
		return "NOT RUNNING YET"
	if car.fuel <= 0.0:
		return "OUT OF FUEL"
	if car.condition <= 0.0:
		return "ENGINE TOO DAMAGED"
	return ""
