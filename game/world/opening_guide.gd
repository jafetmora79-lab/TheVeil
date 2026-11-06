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


func _process(delta: float) -> void:
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
