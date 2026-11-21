extends Node
class_name VeilThrowing
## THE VEIL - throwing and dropping carried items.
##   G  throw the bottle or can in the SELECTED quick slot (1-5) to draw the Hounds away: it leaves the inventory,
##      flies along the view, bounces off the world and, on its first hard impact, clinks (louder the harder it hit)
##      and every Hound within earshot goes to look at the sound (VeilHoundAI.investigate), the way a car alarm does.
##   X  put the selected item down in front of you: it is a real object that falls, bounces, makes a sound scaled to
##      how hard it landed, and can be picked up again. Food, medicine and miscellany only: keys, notes, puzzle pieces,
##      tools, weapons, the flashlight and the radio are never dropped.
## Both are deliberate (a selected slot), so nothing is lost by a stray key press.

const THROWABLE := ["water_bottle", "cola_bottle", "canned_food"]
const DROPPABLE_CATEGORIES := ["food", "medical", "misc"]
const SPEED := 11.0
const DROP_SPEED := 2.4
const HEARING := 30.0                ## metres: Hounds this close to the impact go to look
const LINGER := 7.0                  ## seconds a Hound stays at the noise
const COOLDOWN := 0.6
const LIFETIME := 900.0               ## a dropped item that nobody picks up is tidied away after this long

var world: Node
var report := {"thrown": 0, "impacts": 0, "distracted": 0, "dropped": 0, "drop_impacts": 0}
var _cd := 0.0


func setup(w: Node) -> void:
	world = w
	for a in [["throw_item", KEY_G], ["drop_item", KEY_X]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = a[1]
			InputMap.action_add_event(a[0], ev)


func _process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)


func _unhandled_input(e: InputEvent) -> void:
	if world == null or e.is_echo():
		return
	var throw: bool = e.is_action_pressed("throw_item")
	var drop: bool = e.is_action_pressed("drop_item")
	if not (throw or drop):
		return
	var p = world.get("player")
	if p == null or not p.visible or not p.controls_enabled or world.get("in_car") or world.get("conversing"):
		return
	if (try_throw() if throw else try_drop()):
		get_viewport().set_input_as_handled()


## The id in the selected quick slot ("" if none is selected or it is no longer carried).
func selected_item() -> String:
	var q := get_tree().get_first_node_in_group("veil_quick_slots") as VeilQuickSlots
	if q == null or q.selected < 0:
		return ""
	var id: String = VeilQuickSlots.slots()[q.selected]
	return id if id != "" and Game.has_item(id) else ""


func selected_throwable() -> String:
	var id := selected_item()
	return id if id in THROWABLE else ""


func can_drop(id: String) -> bool:
	return id != "" and String(Game.item_info(id).get("category", "")) in DROPPABLE_CATEGORIES


func try_throw(id := "") -> bool:
	if _cd > 0.0:
		return false
	if id == "":
		id = selected_throwable()
	if id == "" or not Game.has_item(id):
		_hint("To throw a bottle or can: select it in a quick slot (1-5), then press G.")
		return false
	_cd = COOLDOWN
	Game.remove_item(id)
	var cam: Camera3D = world.player.camera
	_spawn(id, -cam.global_transform.basis.z * SPEED + Vector3(0, 1.5, 0), true)
	report["thrown"] += 1
	world.player.set_yaw_pitch(world.player.rotation.y, world.player.head.rotation.x + 0.02)
	return true


func try_drop(id := "") -> bool:
	if _cd > 0.0:
		return false
	if id == "":
		id = selected_item()
	if id == "" or not Game.has_item(id):
		_hint("To put something down: select it in a quick slot (1-5), then press X.")
		return false
	if not can_drop(id):
		_hint("You keep that with you.")
		return false
	_cd = COOLDOWN
	Game.remove_item(id)
	var cam: Camera3D = world.player.camera
	var fwd := -cam.global_transform.basis.z
	_spawn(id, fwd * DROP_SPEED + Vector3(0, 0.6, 0), false)
	report["dropped"] += 1
	return true


## The physical item: a rigid body with the item's own model. Thrown = distracts Hounds; dropped = can be taken again.
func _spawn(id: String, velocity: Vector3, thrown: bool) -> RigidBody3D:
	var cam: Camera3D = world.player.camera
	var info: Dictionary = Game.item_info(id)
	var weight := float(info.get("weight", 0.4))
	var rb := RigidBody3D.new()
	rb.name = ("Thrown_" if thrown else "Dropped_") + id
	rb.collision_layer = 1 << 5                       # its own layer: never shoves the player
	rb.collision_mask = 1 | 4
	rb.mass = clampf(weight, 0.1, 6.0)
	rb.continuous_cd = true
	rb.contact_monitor = true
	rb.max_contacts_reported = 4
	world.add_child(rb)
	var origin := cam.global_position - cam.global_transform.basis.z * (0.5 if thrown else 0.7) + Vector3(0, -0.15, 0)
	rb.global_position = origin
	var path := String(info.get("model", ""))
	var size := Vector3(0.08, 0.2, 0.08)
	if path != "" and ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		VeilViewHands.strip_physics(model)
		rb.add_child(model)
		var box := Interactable.aabb_of(model)
		if box.size.length() > 0.001:
			var s := 0.22 / maxf(box.size.x, maxf(box.size.y, box.size.z))
			model.scale = Vector3.ONE * s
			model.position = -box.get_center() * s
			size = (box.size * s).max(Vector3.ONE * 0.04)
	if path == "" or not ResourceLoader.exists(path):
		# an item without a 3D model of its own (it used to be an invisible box: "it disappeared"): a small box carrying the item's inventory icon
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 0.14, 0.2)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.45, 0.3)
		bm.material = mat
		mi.mesh = bm
		rb.add_child(mi)
		var inv := get_tree().get_first_node_in_group("veil_inventory_panel") as VeilInventoryPanel
		var tex = inv._icon(id) if inv else null
		if tex != null:
			var sp := Sprite3D.new()
			sp.texture = tex
			sp.pixel_size = 0.2 / maxf(float((tex as Texture2D).get_width()), 1.0)
			sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp.position = Vector3(0, 0.16, 0)
			rb.add_child(sp)
		size = Vector3(0.2, 0.14, 0.2)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	rb.add_child(cs)
	rb.linear_velocity = velocity
	var floor_y := rb.global_position.y
	rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)) * (1.0 if thrown else 0.3)
	var state := {"hit": false, "last": 0.0}
	rb.body_entered.connect(func(_b):
		_impact(rb, state, thrown, weight))
	if not thrown:
		# a dropped item can be picked up again; the body goes when it is taken
		var it := Interactable.attach(rb, {"kind": "pickup", "label": String(info.get("name", id)), "item_id": id})
		it.used.connect(func(_by):
			get_tree().create_timer(0.4).timeout.connect(func():
				if is_instance_valid(rb):
					rb.queue_free()))
	if not thrown:
		# never lost under the floor: a dropped item that falls out of the world is set back where it was put down
		var guard := Timer.new()
		guard.wait_time = 0.5
		rb.add_child(guard)
		guard.timeout.connect(func():
			if is_instance_valid(rb) and rb.global_position.y < floor_y - 2.5:
				rb.linear_velocity = Vector3.ZERO
				rb.global_position = world.player.global_position + Vector3(0, 0.6, 0) - world.player.camera.global_transform.basis.z * 0.8)
		guard.start()
	get_tree().create_timer(10.0 if thrown else LIFETIME).timeout.connect(func():
		if is_instance_valid(rb):
			rb.queue_free())
	Sfx.play("pickup", rb.global_position, -12.0, 0.7)          # the little whoosh
	return rb


## What an impact sounds like: louder the harder it hit, lower and duller for heavy things.
func impact_volume(speed: float) -> float:
	return clampf(-18.0 + speed * 1.1, -18.0, 2.0)


func impact_pitch(weight: float) -> float:
	return clampf(2.4 - weight * 0.45, 0.8, 2.4)


func _impact(rb: RigidBody3D, state: Dictionary, thrown: bool, weight: float) -> void:
	if not is_instance_valid(rb):
		return
	var speed := rb.linear_velocity.length()
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(state["last"]) < 0.12:
		return                                        # a rattle of contacts on one bounce is one sound
	state["last"] = now
	var first: bool = not state["hit"]
	state["hit"] = true
	if first:
		report["impacts" if thrown else "drop_impacts"] += 1
	if first or speed > 1.5:
		var v := impact_volume(speed if first else speed * 0.8)
		Sfx.play("door_close", rb.global_position, v, impact_pitch(weight) * randf_range(0.92, 1.08))
		if first:
			Sfx.play("pickup", rb.global_position, v - 6.0, 0.6)
	if first and thrown:
		_distract(rb.global_position)


func _distract(at: Vector3) -> void:
	for ai in get_tree().get_nodes_in_group("veil_hunter"):
		var body = ai.get("body")
		if body == null or not (body is Node3D):
			continue
		if (body as Node3D).global_position.distance_to(at) <= HEARING and ai.has_method("investigate"):
			if ai.investigate(at, LINGER):
				report["distracted"] += 1


func _hint(t: String) -> void:
	var hud = world.get("hud")
	if hud and hud.has_method("set_hint"):
		hud.set_hint(t)
		get_tree().create_timer(3.5).timeout.connect(func():
			if is_instance_valid(hud) and hud.hint.text == t:
				hud.set_hint(""))
