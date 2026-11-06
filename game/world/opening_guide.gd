extends Node
## THE VEIL - guidance through the opening (Chapters 1-2), on the existing objectives: a marker for the current
## step (the fridge, the car keys, the front door, the car, then the way into town; the town's own beacons take
## over there), the front door staying shut until the kitchen is checked and the keys are found (the existing
## "need the kitchen" / "need the keys" lines), and a gentle reminder when the player has not moved the story on
## for ~40 s. All of it ends once the car is parked in town.

const REMIND_S := 40.0
var world: Node
var _step := ""
var _idle := 0.0
var _t := 0.0
var reminders := 0                     ## tests


func setup(w: Node) -> void:
	world = w
	var door: Interactable = world.interactables.get("home/INT_Door_Front")
	if door:
		door.lock_check = func() -> String:
			if Game.has_flag("left_house"):
				return ""
			if not Game.has_flag("fridge_checked"):
				return "need_kitchen"
			if not Game.has_item("car_keys"):
				return "need_keys"
			return ""


func active() -> bool:
	return not Game.has_flag("reached_town") and not Game.has_flag("parked")


## [target, label, reminder] for the current opening step, or [] once it is over.
func step() -> Array:
	if not active():
		return []
	if not Game.has_flag("fridge_checked"):
		var fr: Interactable = _find(func(i): return i.target and String(i.target.name).contains("Fridge"))
		return [fr, "FRIDGE", "I'm starving. I should check the kitchen first."]
	if not Game.has_item("car_keys"):
		var k: Interactable = _find(func(i): return i.item_id == "car_keys" and not i.taken)
		return [k, "CAR KEYS", "Nothing in the fridge. I need my car keys - then the store."]
	if not Game.has_flag("left_house"):
		return [world.interactables.get("home/INT_Door_Front"), "FRONT DOOR", "Keys in hand. Out the front door to the car."]
	if not world.in_car:
		return [world.sedan, "CAR", "The car is in the driveway."]
	return []                                   # driving: the road arrows at the turns lead into town


func _find(f: Callable) -> Interactable:
	for i in world.interactables.values():
		if is_instance_valid(i) and f.call(i):
			return i
	return null


## The shopping: a small diamond over each grocery still needed, the cashier's once all three are in hand; a word
## if the player seems lost in the store. Then, the first time out of the supermarket with the game still to buy,
## a short look across to Game Haven.
var _shop_idle := 0.0
var _ready_said := false
var gh_reminders := 0                  ## tests


func _shopping(delta: float) -> void:
	var hud = world.hud
	var on: bool = Game.has_flag("reached_town") and not Game.has_flag("groceries_done") and world.market != null \
		and world.player.global_position.distance_to(world.market.global_position) < 45.0
	var need := []
	for id in world.GROCERIES:
		if not Game.has_item(id):
			need.append(id)
	var merch = world.get("market_merch")
	for id in world.GROCERIES:
		var it = merch.groups[id]["it"] if merch and merch.groups.has(id) else null
		hud.world_diamond("grocery_" + id, it if on and id in need else null)
	hud.world_diamond("cashier", world.cashier if on and need.is_empty() and world.cashier and world.cashier.visible else null)
	if not on:
		return
	if need.is_empty() and not _ready_said:
		_ready_said = true
		hud.set_hint("Alright, that's everything. Time to pay.")
	_shop_idle += delta
	if world.expedition == null or not need.is_empty():
		if _shop_idle > 45.0 and hud.hint.text == "":
			_shop_idle = 0.0
			hud.set_hint("Still need to grab a few things.")
			get_tree().create_timer(4.0).timeout.connect(func():
				if hud.hint.text == "Still need to grab a few things.":
					hud.set_hint(""))


func _game_haven_look() -> void:
	if Game.has_flag("gh_reminder") or not Game.has_flag("groceries_done") or Game.has_flag("game_bought") or Game.has_flag("p3_mist"):
		return
	var p: Node3D = world.player
	if world.market == null or world.game_shop == null or not p.visible or not p.controls_enabled or world.conversing or world.in_car:
		return
	var lp: Vector3 = world.market.to_local(p.global_position)
	if lp.z > -2.5 or lp.z < -14.0 or absf(lp.x) > 10.0:
		return                                         # just outside the supermarket's front doors
	Game.set_flag("gh_reminder")
	gh_reminders += 1
	p.controls_enabled = false
	p.velocity = Vector3.ZERO
	var cam: Camera3D = p.camera
	var fov0 := cam.fov
	var door := world.game_shop.get_node_or_null("Doorways/Entrance_Outside") as Node3D
	var look: Vector3 = (door.global_position if door else world.game_shop.global_position) + Vector3(0, 2.2, 0)
	var v := look - cam.global_position
	var y0: float = p.rotation.y
	var x0: float = p.head.rotation.x
	var y1 := atan2(-v.x, -v.z)
	var x1 := clampf(asin(clampf(v.normalized().y, -1.0, 1.0)), -0.3, 0.3)
	await get_tree().create_timer(0.4).timeout
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float): p.set_yaw_pitch(lerp_angle(y0, y1, k), lerpf(x0, x1, k)), 0.0, 1.0, 1.0)
	tw.parallel().tween_property(cam, "fov", fov0 * 0.82, 1.0)
	await tw.finished
	Dialogue.say("gh_reminder", false, true)
	await get_tree().create_timer(1.6).timeout
	var back := create_tween().set_trans(Tween.TRANS_SINE)
	back.tween_property(cam, "fov", fov0, 0.8)
	await back.finished
	cam.fov = fov0
	p.controls_enabled = true


func _process(delta: float) -> void:
	if world != null:
		_shopping(delta)
		_game_haven_look()
	if world == null or not active():
		if world and _step != "done":
			_step = "done"
			world.hud.set_marker(null)
		return
	_t -= delta
	_idle += delta
	if _t > 0.0:
		return
	_t = 0.25
	var s := step()
	var label: String = s[1] if s.size() > 1 else ""
	if label != _step:
		_step = label
		_idle = 0.0
	var free: bool = world.player.visible and world.player.controls_enabled and not world.conversing
	if s.is_empty() or s[0] == null or not free:
		world.hud.set_marker(null)
		return
	var t = s[0]
	world.hud.set_marker((t as Interactable).focus_point() if t is Interactable else t, label)
	if _idle > REMIND_S and not Dialogue.is_busy():
		_idle = 0.0
		reminders += 1
		world.hud.set_hint(String(s[2]))
		get_tree().create_timer(6.0).timeout.connect(func():
			if world.hud.hint.text == String(s[2]):
				world.hud.set_hint(""))
