extends Node
class_name VeilSidearm
## THE VEIL - the store manager's handgun: self-defence, not combat.
##
## Sarah hands it over (she found it in the manager's desk) the first time the player goes to leave the shelter once
## she is living there; if she never comes to the supermarket (Ruth and Sarah were not invited, or Chapter 7 starts
## without her) Marcus does instead. A short practice follows, or is skipped: draw, aim, a shot at the overturned
## cart by the entrance, a reload; it can never hold the story up (leaving the store or two minutes end it).
## Older saves that already picked it up off the office floor keep it. H draws or holsters it (or its inventory / hotbar
## action). Drawn, it sits in the lower right of the view: left-click or F fires, right-click aims (raised to the
## centre, less sway), R reloads from the rounds carried. Holstered, F and R stay the flashlight's. Six rounds in
## the magazine to start; rounds found outside go to the reserve (1, 2, or a rare box of 6 - one-time finds, never
## restocked). Never during a conversation, a choice, the inventory, a cinematic or in the car.
## A hit makes a creature flinch; the ones that roam outside during long supply runs and the free-roaming Hounds
## are driven off - they turn back and leave. Story creatures only flinch (the Colossus is never hit): the story's
## scenes play out as written. Nothing dies from a bullet. State: Game.world_state["sidearm"] (saved):
## mag, reserve, drawn, given.

const GUN_MODEL := "res://THE_VEIL_ASSETS_V2/08_Inventory/Weapons/INV_Handgun.glb"
const GUN_SPOT := Vector3(-17.3, 0.05, 14.9)            # market-local: the manager's office floor, by the bedroll
const MAG_SIZE := 6
const START_ROUNDS := 6
const RANGE := 45.0
const COOLDOWN := 0.3
const RELOAD_TIME := 1.6
const EQUIP_TIME := 0.3
const KICK_TIME := 0.25
const ROAMERS := ["EXP_Hound", "C14_RunHound", "C15_Hound"]    # free-roaming Hounds: a hit drives them off
## The model's muzzle is on its -Z, sights on top (+Y), the grip at the back: it points down the view as it is.
const REST := Vector3(0.16, -0.2, -0.36)               # lower right, angled a touch in towards the crosshair
const AIMED := Vector3(0.0, -0.128, -0.30)             # sights just under the crosshair
const REST_YAW := 0.06
const MUZZLE := Vector3(0.0, 0.104, -0.1)              # model-local: the end of the barrel
const PRACTICE_ROUNDS := 3

var world: Node
var pickup: Node3D
var report := {"shots": 0, "hits": 0, "driven_off": 0, "dry": 0, "reloads": 0}
var _cd := 0.0
var _shot_stream: AudioStreamWAV
var _view: Node3D
var _flash: MeshInstance3D
var _equip := 0.0                                       # 0..1: the gun rising into view
var _kick := 0.0                                        # 1 at the shot, back to 0 over KICK_TIME
var _reload_t := -1.0                                   # >= 0 while reloading (seconds in)
var _aim := 0.0                                         # 0..1 toward the aimed pose
var _time := 0.0


func setup(w: Node) -> void:
	world = w
	add_to_group("veil_sidearm")
	_shot_stream = Sfx._make(0.45, func(t, i): return (Sfx._noise(i) * 0.9 + sin(TAU * 90.0 * t) * 0.6) * exp(-t * 14.0))
	Game.inventory_changed.connect(_on_inventory)
	_refresh_pickup()


func st() -> Dictionary:
	if not Game.world_state.has("sidearm"):
		Game.world_state["sidearm"] = {"mag": 0, "reserve": 0}
	var d: Dictionary = Game.world_state["sidearm"]
	if d.has("ammo") and not d.has("mag"):             # an older save: one pool of rounds -> magazine + reserve
		var a := int(d["ammo"])
		d["mag"] = mini(a, MAG_SIZE)
		d["reserve"] = a - int(d["mag"])
		d.erase("ammo")
		d["drawn"] = true
	return d


func has_gun() -> bool:
	return Game.has_item("handgun")


func mag() -> int:
	return int(st().get("mag", 0))


func reserve() -> int:
	return int(st().get("reserve", 0))


## Every round the player has: loaded and carried.
func ammo() -> int:
	return mag() + reserve()


func drawn() -> bool:
	return has_gun() and bool(st().get("drawn", false))


func reloading() -> bool:
	return _reload_t >= 0.0


func set_drawn(on: bool) -> void:
	if on and not has_gun():
		return
	if on != bool(st().get("drawn", false)):
		st()["drawn"] = on
		_equip = 0.0
		_reload_t = -1.0                                # a reload cut short moves no rounds
		if world and world.player:
			Sfx.play("pickup", world.player.global_position, -16.0, 0.8 if on else 0.6)


## The handgun lies in the office while the supermarket is the shelter and it has not been taken.
func _refresh_pickup() -> void:
	# (the floor pickup is gone: Sarah, or Marcus, hands the gun over - see handover())
	var want := false
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
		st()["mag"] = mag() + START_ROUNDS
		st()["drawn"] = true
		_equip = 0.0
		if String(st().get("tutorial", "")) == "":
			_hint("The manager's handgun - six rounds. Left-click or F fires, right-click aims, R reloads, H holsters. Make every shot count.", 8.0)
	for id in Game.inventory.duplicate():
		var n := int(Game.item_info(String(id)).get("rounds", 0))
		if n > 0 and Game.has_item(String(id)):
			Game.remove_item(String(id))
			st()["reserve"] = reserve() + n
			_hint("%d round%s - %d carried." % [n, "" if n == 1 else "s", reserve()], 3.0)


## Free to handle the gun at all: not talking, choosing, in a menu, the inventory, a cinematic or the car.
func can_act() -> bool:
	var p = world.player if world else null
	if not has_gun() or p == null or not p.visible or not p.controls_enabled or world.in_car or world.conversing:
		return false
	if Dialogue.confirm_mode or world.hud._dialogue_prompt_on() or world._choice_open() or world.hud.is_paused() or world.hud.inv_panel.visible:
		return false
	if world.get("_cine") and is_instance_valid(world.get("_cine")):
		return false
	return true


func can_fire() -> bool:
	return can_act() and drawn() and not reloading() and _cd <= 0.0


func _unhandled_input(e: InputEvent) -> void:
	if world == null or not (e.is_pressed() and not e.is_echo()):
		return
	var k := (e as InputEventKey).physical_keycode if e is InputEventKey else KEY_NONE
	var click: bool = e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if not can_act():
		return
	if k == KEY_H:
		set_drawn(not drawn())
	elif click and not drawn():
		set_drawn(true)                                 # a click with the gun away brings it up first
	elif (click or k == KEY_F) and drawn():
		if can_fire():
			fire()
	elif k == KEY_R and drawn():
		reload()
	else:
		return
	get_viewport().set_input_as_handled()


## R: top the magazine up from the rounds carried (only at the end of the motion: an interrupted reload moves none).
func reload() -> bool:
	if not drawn() or reloading() or mag() >= MAG_SIZE:
		return false
	if reserve() <= 0:
		_hint("No rounds left to load.", 1.6)
		return false
	if String(st().get("tutorial", "")) == "fire":
		return false                                     # (practice: the shot first)
	_reload_t = 0.0
	Sfx.play("pickup", world.player.global_position, -14.0, 0.7)
	return true


func _finish_reload() -> void:
	_reload_t = -1.0
	var n := mini(MAG_SIZE - mag(), reserve())
	st()["mag"] = mag() + n
	st()["reserve"] = reserve() - n
	report["reloads"] += 1
	_hint("HANDGUN  %d  |  %d" % [mag(), reserve()], 1.6)


func fire() -> void:
	_cd = COOLDOWN
	if mag() <= 0:
		report["dry"] += 1
		Sfx.play("door_close", world.player.global_position, -20.0, 2.8)    # a quiet click
		_hint("Empty. R to reload." if reserve() > 0 else "Empty.", 1.5)
		return
	st()["mag"] = mag() - 1
	report["shots"] += 1
	var cam: Camera3D = world.player.camera
	var p := AudioStreamPlayer.new()
	p.stream = _shot_stream
	p.volume_db = -6.0
	p.pitch_scale = randf_range(0.94, 1.06)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 3.0
	light.omni_range = 6.0
	cam.add_child(light)
	light.position = Vector3(0.25, -0.2, -0.8)
	get_tree().create_timer(0.06).timeout.connect(light.queue_free)
	_ensure_view()
	_kick = 1.0
	if _flash:
		_flash.visible = true
		_flash.rotation.z = randf() * TAU
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(_flash):
				_flash.visible = false)
	world.player.set_yaw_pitch(world.player.rotation.y, world.player.head.rotation.x + 0.035)    # a little kick
	var target := _target(cam)
	if target:
		_hit(target)
	_practice_shot(cam)
	_hint("HANDGUN  %d  |  %d" % [mag(), reserve()], 1.4)


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
		var was := ap.current_animation
		for an in ap.get_animation_list():
			if String(an).to_lower().contains("hit") and String(an) != was:
				ap.play(an)
				if was != "":                          # a flinch, then back to whatever it was doing
					get_tree().create_timer(minf(ap.current_animation_length, 0.6)).timeout.connect(func():
						if is_instance_valid(ap) and ap.has_animation(was):
							ap.play(was))
				break
	var ai: Node = n.get_node_or_null("AI")
	if ai and ai.get("voice"):
		ai.voice.pain()                                # its own yelp / shell crack
	else:
		Sfx.play("hurt", n.global_position + Vector3(0, 0.6, 0), 2.0, 0.6)
	if String(n.name) in ROAMERS and ai and "state" in ai:
		ai.state = "RETURN"                            # it turns back and leaves (the expedition removes it unseen)
		if ai.get("voice"):
			get_tree().create_timer(0.4).timeout.connect(func():
				if is_instance_valid(ai):
					ai.voice.hurt())                     # limping off, whimpering
		report["driven_off"] += 1


## The first-person gun (the inventory model, no arms) and its muzzle flash, under the camera.
func _ensure_view() -> void:
	if _view and is_instance_valid(_view):
		return
	var ps := load(GUN_MODEL) as PackedScene
	if ps == null:
		return
	var cam: Camera3D = world.player.camera
	_view = ps.instantiate() as Node3D
	_view.name = "SidearmView"
	cam.add_child(_view)
	_view.position = REST
	_view.basis = Basis(Vector3.UP, REST_YAW)
	_view.visible = false
	for gi in _view.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	_flash.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.75, 0.35, 0.9)
	_flash.material_override = m
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	cam.add_child(_flash)


func view_shown() -> bool:
	return _view != null and is_instance_valid(_view) and _view.visible


## Procedural motion: rise on equip, breathing and walking sway, aim toward the centre, the shot's kick, the reload.
func _animate(delta: float) -> void:
	var show: bool = drawn() and world.player.visible and world.player.controls_enabled and not world.in_car \
		and not (world.get("_cine") and is_instance_valid(world.get("_cine")))
	if not show:
		if _view and is_instance_valid(_view):
			_view.visible = false
		_equip = 0.0
		_reload_t = -1.0
		_aim = 0.0
		return
	_ensure_view()
	if _view == null:
		return
	_view.visible = true
	_time += delta
	_equip = minf(_equip + delta / EQUIP_TIME, 1.0)
	_kick = maxf(_kick - delta / KICK_TIME, 0.0)
	var want_aim := 1.0 if can_act() and not reloading() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0
	_aim = move_toward(_aim, want_aim, delta / 0.18)
	var aim_e := smoothstep(0.0, 1.0, _aim)
	var pos := REST.lerp(AIMED, aim_e)
	var v: Vector3 = world.player.velocity * Vector3(1, 0, 1)
	var walk := clampf(v.length() / 4.0, 0.0, 1.0)
	var sway := 1.0 - 0.7 * aim_e
	pos += Vector3(sin(_time * 4.2) * 0.010 * walk, absf(sin(_time * 8.4)) * -0.008 * walk + sin(_time * 1.6) * 0.003, 0.0) * sway
	var pitch := 0.0
	var roll := 0.0
	var k := _kick * _kick                              # sharp at the shot, settling smoothly
	pos.z += 0.07 * k
	pos.y += 0.02 * k
	pitch += 0.32 * k
	if reloading():
		_reload_t += delta
		var ph := clampf(_reload_t / RELOAD_TIME, 0.0, 1.0)
		var dip := sin(ph * PI)
		pos += Vector3(-0.04, -0.12, 0.05) * dip
		roll += 0.7 * dip
		pitch += 0.25 * dip
		if ph > 0.55 and ph < 0.7:                      # the magazine slapped home
			pos.y += 0.015 * sin((ph - 0.55) / 0.15 * PI)
		if ph >= 0.55 and _reload_t - delta < RELOAD_TIME * 0.55:
			Sfx.play("door_close", world.player.global_position, -16.0, 2.2)
		if _reload_t >= RELOAD_TIME:
			_finish_reload()
	pos.y -= 0.28 * (1.0 - smoothstep(0.0, 1.0, _equip))
	_view.position = pos
	_view.basis = Basis(Vector3.FORWARD, roll) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, REST_YAW * (1.0 - aim_e))
	if _flash:
		_flash.position = pos + _view.basis * MUZZLE      # at the end of the barrel, wherever the gun is


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
	_animate(delta)
	_practice_tick(delta)


# ------------------------------------------------------------------ the handover and the practice
## Who gives the gun right now: "Sarah" once she lives in the shelter, "Marcus" when she never will, "" = not yet.
func presenter() -> String:
	if world == null or not world.has_method("shelter_roster"):
		return ""
	var roster: Array = world.shelter_roster()
	if "Sarah" in roster:
		return "Sarah"
	var c6 = Game.world_state.get("ch6", {})
	var choice := String(c6.get("ruth_sarah_choice", "")) if c6 is Dictionary else ""
	var never := (Game.has_flag("ch6_ruth_sarah_met") and choice != "" and choice != "invite") or Game.has_flag("ch7_started")
	if never and "Marcus" in roster:
		return "Marcus"
	return ""


func handover_pending() -> bool:
	return Game.has_flag("c5_started") and not Game.has_flag("ch9_supermarket_lost") and not has_gun() \
		and not bool(st().get("given", false)) and presenter() != ""


var _handing := false
var _target_cart: Node3D = null
var _step_t := 0.0
var _practice_t := 0.0
var _practice_shots := 0


## "Before you go back out there": the presenter explains, hands the gun over, offers the practice.
func handover(choice: Node) -> void:
	if _handing or not handover_pending():
		return
	_handing = true
	var who := presenter()
	var a = world.animators.get(who)
	var npc: Node3D = a.root if a else null
	var c5 = world.phase4.chapter5 if world.phase4 and world.phase4.get("chapter5") else null
	var id := "gun_%s_intro" % who.to_lower()
	if c5:
		await c5._talk(id, npc)
	else:
		Dialogue.say(id, false, true)
		while Dialogue.is_busy():
			await get_tree().process_frame
	st()["tutorial"] = "offered"
	st()["from"] = who
	Game.add_item("handgun")                          # (one gun: has_gun() is checked before anything is given)
	report["handed_by"] = who
	var i: int = await choice.ask("THE HANDGUN", ["Show Me How It Works", "I Know How to Use It"], world.player)
	if i == 0:
		st()["reserve"] = reserve() + PRACTICE_ROUNDS
		_start_practice()
		_hint("%s: \"Three spare rounds. Practise on the cart by the doors.\"" % who, 4.0)
	else:
		st()["tutorial"] = "skipped"
		Dialogue.say("gun_%s_skip" % who.to_lower(), false, true)
		_hint("Left-click or F fires, right-click aims, R reloads, H holsters.", 6.0)
	_handing = false


func practising() -> bool:
	return String(st().get("tutorial", "")) in ["draw", "aim", "fire", "reload"]


func _start_practice() -> void:
	st()["tutorial"] = "draw" if not drawn() else "aim"
	_practice_t = 0.0
	_practice_shots = 0
	_target_cart = _find_cart()


## The practice target: an overturned shopping cart in the store (an existing prop), the one nearest the player.
func _find_cart() -> Node3D:
	if world.market == null:
		return null
	var props: Node = world.market.get_node_or_null("Props")
	var best: Node3D = null
	var bd := 30.0
	if props:
		for c in props.get_children():
			if String(c.name).begins_with("Cart_") and c is Node3D:
				var d: float = (c as Node3D).global_position.distance_to(world.player.global_position)
				if d < bd:
					bd = d
					best = c
	return best


const PRACTICE_HINT := {"draw": "PRACTICE  -  H: draw the handgun", "aim": "PRACTICE  -  hold RIGHT-CLICK to aim",
	"fire": "PRACTICE  -  LEFT-CLICK or F: shoot the overturned cart", "reload": "PRACTICE  -  R: reload"}


func _practice_tick(delta: float) -> void:
	if not practising():
		return
	var step := String(st()["tutorial"])
	_practice_t += delta
	# never a dead end: out of the store, a story scene, or two minutes and it is over
	var ex = world.get("expedition")
	var l: Vector3 = world.market.to_local(world.player.global_position) if world.market else Vector3(0, 0, 5)
	var outside := l.z < 0.3 or l.z > 18.0 or absf(l.x) > 20.5          # (the vestibule still counts as inside)
	if _practice_t > 120.0 or outside or (ex and ex.emergency(false)):
		_end_practice(false)
		return
	if world.hud and world.hud.hint.text != PRACTICE_HINT[step] and can_act():
		world.hud.set_hint(PRACTICE_HINT[step])
	match step:
		"draw":
			if drawn():
				_next_step("aim")
		"aim":
			_step_t = _step_t + delta if _aim >= 1.0 else 0.0
			if _step_t > 0.3:
				_next_step("fire")
		"reload":
			if mag() >= MAG_SIZE or (reserve() <= 0 and not reloading()):
				_end_practice(true)


func _next_step(s: String) -> void:
	st()["tutorial"] = s
	_step_t = 0.0
	report["practice_" + s] = true
	if s == "reload" and (reserve() <= 0 or mag() >= MAG_SIZE):
		_end_practice(true)


## A practice shot: on the cart (close to the aim line, nothing in between) it rings and rocks.
func _practice_shot(cam: Camera3D) -> void:
	if String(st().get("tutorial", "")) != "fire":
		return
	_practice_shots += 1
	var hit := false
	if _target_cart and is_instance_valid(_target_cart):
		var c := _target_cart.global_position + Vector3(0, 0.45, 0)
		var eye := cam.global_position
		var fwd := -cam.global_transform.basis.z
		var to := c - eye
		var along := to.dot(fwd)
		hit = along > 0.5 and (to - fwd * along).length() < 0.75
		if hit:
			Sfx.play("door_close", c, 2.0, 1.9)          # the ring of the wire basket
			var b0 := _target_cart.transform
			var tw := _target_cart.create_tween()
			tw.tween_property(_target_cart, "transform", Transform3D(b0.basis.rotated(Vector3.UP, 0.08), b0.origin + fwd * Vector3(1, 0, 1) * 0.08), 0.08)
			tw.tween_property(_target_cart, "transform", Transform3D(b0.basis.rotated(Vector3.UP, 0.05), b0.origin + fwd * Vector3(1, 0, 1) * 0.06), 0.25)
	else:
		hit = true                                       # (no cart: any shot will do)
	report["practice_hits"] = int(report.get("practice_hits", 0)) + (1 if hit else 0)
	if hit or _practice_shots >= 3:
		_next_step("reload")


func _end_practice(done: bool) -> void:
	st()["tutorial"] = "done" if done else "ended"
	report["practice_done"] = done
	if world.hud and String(world.hud.hint.text).begins_with("PRACTICE"):
		world.hud.set_hint("")
	var who := String(st().get("from", "Sarah"))
	if done:
		Dialogue.say("gun_%s_done" % who.to_lower(), false, true)
	_hint("H holsters it. Every shot is noise - out there, they hear it too.", 5.0)
