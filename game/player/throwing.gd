extends Node
class_name VeilThrowing
## THE VEIL - throwing a bottle or a can to draw the Hounds away (G).
## The item in the SELECTED quick slot (1-5) is thrown, so it is always a deliberate choice: it leaves the inventory,
## flies along the view, bounces off the world and, on its first hard impact, clinks (louder when it hits faster)
## and every Hound within earshot goes to look at the sound (VeilHoundAI.investigate), the same way a car alarm
## draws them. A distraction, never a weapon.

const THROWABLE := ["water_bottle", "cola_bottle", "canned_food"]
const SPEED := 11.0
const HEARING := 30.0                ## metres: Hounds this close to the impact go to look
const LINGER := 7.0                  ## seconds a Hound stays at the noise
const COOLDOWN := 0.6

var world: Node
var report := {"thrown": 0, "impacts": 0, "distracted": 0}
var _cd := 0.0


func setup(w: Node) -> void:
	world = w
	if not InputMap.has_action("throw_item"):
		InputMap.add_action("throw_item")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_G
		InputMap.action_add_event("throw_item", ev)


func _process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)


func _unhandled_input(e: InputEvent) -> void:
	if world == null or not e.is_action_pressed("throw_item") or e.is_echo():
		return
	var p = world.get("player")
	if p == null or not p.visible or not p.controls_enabled or world.get("in_car") or world.get("conversing"):
		return
	if try_throw():
		get_viewport().set_input_as_handled()


## The id in the selected quick slot, if it can be thrown and is still carried ("" otherwise).
func selected_throwable() -> String:
	var q := get_tree().get_first_node_in_group("veil_quick_slots") as VeilQuickSlots
	if q == null or q.selected < 0:
		return ""
	var id: String = VeilQuickSlots.slots()[q.selected]
	return id if id in THROWABLE and Game.has_item(id) else ""


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
	_spawn(id)
	report["thrown"] += 1
	return true


func _spawn(id: String) -> void:
	var cam: Camera3D = world.player.camera
	var rb := RigidBody3D.new()
	rb.name = "Thrown_" + id
	rb.collision_layer = 1 << 5                       # its own layer: never shoves the player
	rb.collision_mask = 1 | 4
	rb.mass = 0.4
	rb.continuous_cd = true
	rb.contact_monitor = true
	rb.max_contacts_reported = 4
	world.add_child(rb)
	rb.global_position = cam.global_position - cam.global_transform.basis.z * 0.5 + Vector3(0, -0.1, 0)
	var path := String(Game.item_info(id).get("model", ""))
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
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	rb.add_child(cs)
	rb.linear_velocity = -cam.global_transform.basis.z * SPEED + Vector3(0, 1.5, 0)
	rb.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	var state := {"hit": false, "speed": 0.0}
	rb.body_entered.connect(func(_b):
		_impact(rb, state))
	var t := get_tree().create_timer(10.0)
	t.timeout.connect(func():
		if is_instance_valid(rb):
			rb.queue_free())
	Sfx.play("pickup", rb.global_position, -12.0, 0.7)          # the little whoosh of the throw
	world.player.set_yaw_pitch(world.player.rotation.y, world.player.head.rotation.x + 0.02)




func _impact(rb: RigidBody3D, state: Dictionary) -> void:
	if not is_instance_valid(rb):
		return
	var speed := rb.linear_velocity.length()
	var first: bool = not state["hit"]
	state["hit"] = true
	if first:
		report["impacts"] += 1
		# a clink, louder the harder it hit (the speed after contact is a fair stand-in for the speed before)
		var v := clampf(-16.0 + speed * 0.9, -16.0, 2.0)
		Sfx.play("door_close", rb.global_position, v, 2.1)
		Sfx.play("pickup", rb.global_position, v - 4.0, 0.6)
		_distract(rb.global_position)
	elif speed > 2.0:
		Sfx.play("door_close", rb.global_position, clampf(-20.0 + speed, -20.0, -4.0), randf_range(1.7, 2.4))


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
