extends Node3D
class_name VeilRestPoint
## THE VEIL - a place to sleep (first used in Phase 4: the supermarket office).
## Shows "[E] Sleep", asks for confirmation, fades to black and emits `slept(shelter_id)`; the caller decides
## what the night changes (story flags, day counter). Kept independent so a later shelter system can register
## many rest points (shelter_id, availability via `can_rest`) without changing this script.

signal slept(shelter_id: String)
signal refused(shelter_id: String)

@export var shelter_id := "shelter"
@export var prompt := "[E] Sleep"
@export var confirm_title := "Rest until morning?"
## Callable returning true when resting is allowed right now (story gate); empty = always.
var can_rest: Callable = Callable()
## Survival rule shared by every rest point (set by the expedition controller): returns "" when the group has
## enough to eat and drink tonight, otherwise the reason (shown as a hint; sleeping is refused).
static var supply_gate: Callable = Callable()
var supply_refusals := 0
var hungry_nights := 0                ## tests
var interactable: Interactable
var choice: VeilChoicePanel
var hud: Node
var player: Node3D
var _busy := false


func setup(size: Vector3, p_choice: VeilChoicePanel, p_hud: Node, p_player: Node3D) -> void:
	choice = p_choice
	hud = p_hud
	player = p_player
	interactable = Interactable.new()
	interactable.name = "Interact"
	interactable.kind = "custom"
	interactable.label = "Rest"
	interactable.prompt_text = prompt
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	interactable.add_child(cs)
	add_child(interactable)
	interactable.used.connect(func(_b): request())


func request() -> void:
	if _busy:
		return
	if can_rest.is_valid() and not can_rest.call():
		refused.emit(shelter_id)
		return
	if supply_gate.is_valid():
		var why: String = supply_gate.call()
		if why != "":
			if hud and hud.has_method("set_hint"):
				hud.set_hint(why)                  # (not the story's "not tired" refusal: this is about supplies)
			supply_refusals += 1
			# never a dead end: sleeping hungry is allowed (the night's shortfall costs morale)
			_busy = true
			var k: int = await choice.ask("NOT ENOUGH FOR EVERYONE TONIGHT", ["Find More Supplies", "Sleep Anyway - Some Survivors Go Hungry"], player)
			_busy = false
			if k != 1:
				return
			hungry_nights += 1
			_busy = true
			_sleep_now(true)
			return
	_busy = true
	var i: int = await choice.ask(confirm_title, ["Sleep - Continue to Next Day", "Not yet"], player)
	if i != 0:
		_busy = false
		return
	_sleep_now()


## A night's sleep heals: fully after a fed night, partly when the group went to bed hungry.
func _sleep_now(hungry := false) -> void:
	_busy = true
	if player:
		player.set("controls_enabled", false)
	await hud.fade_to(1.0, 2.0)
	if player and player.has_method("heal"):
		player.heal(40.0 if hungry else 100.0)
	interactable.prompt_text = ""
	slept.emit(shelter_id)
	_busy = false
