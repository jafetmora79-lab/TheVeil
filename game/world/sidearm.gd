extends Node
class_name VeilSidearm
## THE VEIL - the store manager's handgun (from the first scavenging day on): self-defence, not combat.
##
## It lies in the supermarket's manager's office (where the protagonist sleeps) once the supply rule starts (flag
## c5_started), while the supermarket is still the shelter. Left-click or F fires (never during a conversation, a
## choice, the inventory, a cinematic or in the car). Six rounds to start; ammo boxes found outside add six each.
## A hit makes a creature flinch; the ones that roam outside during long supply runs (the dynamic danger) and the
## free-roaming Hounds are driven off - they turn back and leave. Story creatures only flinch: the story's scenes
## play out as written. State: Game.world_state["sidearm"] (saved).

const GUN_MODEL := "res://THE_VEIL_ASSETS_V2/08_Inventory/Weapons/INV_Handgun.glb"
const GUN_SPOT := Vector3(-17.3, 0.05, 14.9)            # market-local: the manager's office floor, by the bedroll
const ROUNDS_PER_BOX := 6
const RANGE := 45.0
const COOLDOWN := 0.5
const ROAMERS := ["EXP_Hound", "C14_RunHound", "C15_Hound"]    # free-roaming Hounds: a hit drives them off

var world: Node
var pickup: Node3D
var report := {"shots": 0, "hits": 0, "driven_off": 0, "dry": 0}
var _cd := 0.0
var _shot_stream: AudioStreamWAV
var _view: Node3D
var _view_t := 0.0


func setup(w: Node) -> void:
	world = w
	_shot_stream = Sfx._make(0.45, func(t, i): return (Sfx._noise(i) * 0.9 + sin(TAU * 90.0 * t) * 0.6) * exp(-t * 14.0))
	Game.inventory_changed.connect(_on_inventory)
	_refresh_pickup()


func st() -> Dictionary:
	if not Game.world_state.has("sidearm"):
		Game.world_state["sidearm"] = {"ammo": 0}
	return Game.world_state["sidearm"]


func has_gun() -> bool:
	return Game.has_item("handgun")


func ammo() -> int:
	return int(st().get("ammo", 0))


## The handgun lies in the office while the supermarket is the shelter and it has not been taken.
func _refresh_pickup() -> void:
	var want: bool = Game.has_flag("c5_started") and not Game.has_flag("ch9_supermarket_lost") and not has_gun() \
		and not Game.world_state.get("sidearm/handgun", {}).get("taken", false)
	if want and pickup == null and world.market:
		var ps := load(GUN_MODEL) as PackedScene
		if ps == null:
			return
		pickup = ps.instantiate() as Node3D
		pickup.name = "Sidearm_Handgun"
		world.add_child(pickup)
		pickup.global_transform = Transform3D(world.market.global_transform.basis.rotated(Vector3.UP, 0.7), world.market.global_transform * GUN_SPOT)
		var it := Interactable.attach(pickup, {"kind": "pickup", "label": "Handgun", "item_id": "handgun", "state_key": "sidearm/handgun"})
		var cs := it.get_child(0) as CollisionShape3D
		(cs.shape as BoxShape3D).size = (cs.shape as BoxShape3D).size.max(Vector3(0.6, 0.4, 0.6))


func _on_inventory() -> void:
	if has_gun() and not st().get("given", false):
		st()["given"] = true
		st()["ammo"] = ammo() + ROUNDS_PER_BOX
		_hint("A handgun from the manager's desk - six rounds. Left-click or F to fire. It drives off what roams outside; it won't stop everything.", 7.0)
	while Game.has_item("handgun_ammo"):
		Game.remove_item("handgun_ammo")
		st()["ammo"] = ammo() + ROUNDS_PER_BOX
		_hint("Handgun ammo: %d rounds." % ammo(), 3.0)


func can_fire() -> bool:
	var p = world.player
	if not has_gun() or p == null or not p.visible or not p.controls_enabled or world.in_car or world.conversing:
		return false
	if Dialogue.confirm_mode or world.hud._dialogue_prompt_on() or world._choice_open() or world.hud.is_paused() or world.hud.inv_panel.visible:
		return false
	if world.get("_cine") and is_instance_valid(world.get("_cine")):
		return false
	return _cd <= 0.0


func _unhandled_input(e: InputEvent) -> void:
	var pull: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and e.pressed) \
		or (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_F and e.pressed and not e.echo)
	if pull and can_fire():
		fire()
		get_viewport().set_input_as_handled()


func fire() -> void:
	_cd = COOLDOWN
	if ammo() <= 0:
		report["dry"] += 1
		Sfx.play("door_close", world.player.global_position, -10.0, 2.4)
		_hint("Empty.", 1.5)
		return
	st()["ammo"] = ammo() - 1
	report["shots"] += 1
	var cam: Camera3D = world.player.camera
	var p := AudioStreamPlayer.new()
	p.stream = _shot_stream
	p.volume_db = -4.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.5)
	flash.light_energy = 3.0
	flash.omni_range = 6.0
	cam.add_child(flash)
	flash.position = Vector3(0.25, -0.2, -0.8)
	get_tree().create_timer(0.06).timeout.connect(flash.queue_free)
	_show_gun()
	world.player.set_yaw_pitch(world.player.rotation.y, world.player.head.rotation.x + 0.035)    # a little kick
	var target := _target(cam)
	if target:
		_hit(target)
	_hint("HANDGUN  %d" % ammo(), 1.4)


## The creature the shot would hit: close to the aim line, in range, with nothing solid in between.
func _target(cam: Camera3D) -> Node3D:
	var eye := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var best: Node3D = null
	var best_d := INF
	for n in world.find_children("*", "Node3D", true, false):
		if not n.has_meta("veil_creature") or String(n.get_meta("veil_creature")) == "Colossus" or not (n as Node3D).is_visible_in_tree():
			continue
		var c: Vector3 = (n as Node3D).global_position + Vector3(0, 0.6, 0)
		var to := c - eye
		var along := to.dot(fwd)
		if along <= 0.5 or along > RANGE:
			continue
		if (to - fwd * along).length() > 0.9:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, c, 1, [world.player.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(eye) < along - 0.8:
			continue
		if along < best_d:
			best_d = along
			best = n
	return best


func _hit(n: Node3D) -> void:
	report["hits"] += 1
	var ap := n.get_node_or_null(String(n.get_meta("animation_player", "Model/AnimationPlayer"))) as AnimationPlayer
	if ap:
		for an in ap.get_animation_list():
			if String(an).to_lower().contains("hit"):
				ap.play(an)
				break
	Sfx.play("hurt", n.global_position + Vector3(0, 0.6, 0), 2.0, 0.6)
	var ai: Node = n.get_node_or_null("AI")
	if String(n.name) in ROAMERS and ai and "state" in ai:
		ai.state = "RETURN"                            # it turns back and leaves (the expedition removes it unseen)
		report["driven_off"] += 1


func _show_gun() -> void:
	var cam: Camera3D = world.player.camera
	if _view == null or not is_instance_valid(_view):
		var ps := load(GUN_MODEL) as PackedScene
		if ps == null:
			return
		_view = ps.instantiate() as Node3D
		cam.add_child(_view)
		_view.position = Vector3(0.26, -0.24, -0.55)
		_view.rotation = Vector3(0.0, PI * 0.5, 0.0)
		for gi in _view.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.visible = true
	_view_t = 1.1


func _hint(t: String, hold: float) -> void:
	var hud = world.hud
	if hud and hud.has_method("set_hint"):
		hud.set_hint(t)
		get_tree().create_timer(hold).timeout.connect(func():
			if is_instance_valid(hud) and hud.hint.text == t:
				hud.set_hint(""))


func _process(delta: float) -> void:
	if world == null:
		return
	_cd = maxf(_cd - delta, 0.0)
	if _view and is_instance_valid(_view) and _view.visible:
		_view_t -= delta
		if _view_t <= 0.0 or not world.player.controls_enabled:
			_view.visible = false
	if pickup == null and Game.has_flag("c5_started") and not has_gun():
		_refresh_pickup()
	elif pickup and Game.has_flag("ch9_supermarket_lost") and is_instance_valid(pickup) and not has_gun():
		pickup.queue_free()                            # the shelter is gone (and the desk with it)
		pickup = null
