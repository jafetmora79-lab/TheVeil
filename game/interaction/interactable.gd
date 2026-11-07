extends Area3D
class_name Interactable
## THE VEIL - reusable interaction component (collision layer 4). The player's ray looks for anything with
## get_prompt() / interact(). Kinds:
##   hinge   - rotates `target` about its local Y by open_deg (doors, fridge, cabinets)
##   slide   - moves `target` along slide_axis by slide_dist (drawers, sliding doors, garage doors, sashes)
##   pickup  - adds item_id to the inventory and hides `target`
##   toggle  - toggles a light (light_node) on / off
##   observe - plays a protagonist observation (dialogue_id)
##   custom  - only emits `used` (vehicle entry etc.)
## Every kind can also set story_flag and play dialogue_id on first use, and emits `used`.
## State (open / taken / on) is mirrored into Game.world_state[state_key] for saving.

signal used(by: Node)

@export_enum("hinge", "slide", "pickup", "toggle", "observe", "custom") var kind := "observe"
@export var label := "Object"
@export var target: Node3D
@export var open_deg := 90.0
## local hinge axis (doors: Y; oven doors, lids: X)
@export var hinge_axis := Vector3.UP
@export var slide_axis := Vector3(0, 0, 1)
@export var slide_dist := 0.4
@export var item_id := ""
@export var dialogue_id := ""
@export var story_flag := ""
@export var light_node: Light3D
@export var anim_time := 0.45
@export var state_key := ""
## custom prompt override (custom kind)
@export var prompt_text := ""

var is_open := false
var taken := false
var _base: Transform3D
var _busy := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if kind == "pickup":
		add_to_group("veil_pickup")
	if kind == "hinge":
		add_to_group("veil_door")                   # companions open these on their way
	if target:
		_base = target.transform
	if state_key != "" and Game.world_state.has(state_key):
		var st: Dictionary = Game.world_state[state_key]
		if st.get("taken", false):
			_take(true)
		elif st.get("open", false):
			set_open(true, true)


func get_prompt() -> String:
	if taken:
		return ""
	match kind:
		"hinge", "slide":
			return key_hint() + "%s %s" % ["Close" if is_open else "Open", label]
		"pickup":
			return prompt_text if prompt_text != "" else key_hint() + "TAKE " + display_name().to_upper()
		"toggle":
			return key_hint() + label
		"observe":
			return key_hint() + "Examine " + label
	return prompt_text


## "[E] " on keyboard / mouse, nothing on a touch screen (the on-screen use button carries the action).
static func key_hint() -> String:
	return "" if DisplayServer.is_touchscreen_available() and OS.has_feature("mobile") else "[E] "


## Item name from game/data/items.json when this is an inventory pickup (so prompts use the real item names).
func display_name() -> String:
	if item_id != "":
		var info: Dictionary = Game.item_info(item_id)
		if info.has("name"):
			return String(info["name"])
	return label


## One highlight for every collectible (food, batteries, medicine, keys, quest items, loot in containers): a faint
## additive rim while the player is aiming at it, removed when they look away or it is taken. The player calls this.
var _hl: ShaderMaterial
const HL_SHADER := preload("res://game/interaction/pickup_highlight.gdshader")


func set_focus(on: bool) -> void:
	if kind != "pickup" or target == null:
		return
	if _hl == null:
		_hl = ShaderMaterial.new()
		_hl.shader = HL_SHADER
	var mat: Material = _hl if on and not taken else null
	for m in target.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).material_overlay = mat
	if target is GeometryInstance3D:
		(target as GeometryInstance3D).material_overlay = mat


## Loot inside a container: the container part (drawer / cabinet door) and the container piece's own colliders,
## which the aim assist's line-of-sight check ignores (the item sits inside that solid box). Set by the owner.
var container: Interactable
var los_ignore: Array[RID] = []


## World-space point the aim assist and line-of-sight checks use (centre of the pickup box).
func focus_point() -> Vector3:
	for c in get_children():
		if c is CollisionShape3D:
			return (c as CollisionShape3D).global_position
	return global_position


## Optional: returns a dialogue id ("" = allowed) - a door that will not open yet says why instead.
var lock_check: Callable = Callable()


func interact(by: Node) -> void:
	if taken or _busy:
		return
	if lock_check.is_valid() and not is_open:
		var why: String = lock_check.call()
		if why != "":
			Dialogue.say(why, false, true)
			return
	match kind:
		"hinge", "slide":
			set_open(not is_open)
			Sfx.play("door_open" if is_open else "door_close", global_position, -4.0 if kind == "slide" else 0.0,
				1.3 if label in ["Drawer", "Cabinet"] else 1.0)
		"pickup":
			Game.add_item(item_id)
			_take(false)
			Sfx.play("pickup", global_position)
		"toggle":
			if light_node:
				light_node.visible = not light_node.visible
				is_open = light_node.visible
				_store()
		"observe":
			pass
	if dialogue_id != "":
		Dialogue.say(dialogue_id, false, true)
	if story_flag != "":
		Game.set_flag(story_flag)
	used.emit(by)


func set_open(v: bool, instant := false) -> void:
	is_open = v
	_store()
	if not target:
		return
	var t := _base
	if v and kind == "hinge":
		t = Transform3D(_base.basis * Basis(hinge_axis.normalized(), deg_to_rad(open_deg)), _base.origin)
	elif v and kind == "slide":
		t = Transform3D(_base.basis, _base.origin + _base.basis * (slide_axis.normalized() * slide_dist))
	if instant:
		target.transform = t
		return
	_busy = true
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "transform", t, anim_time)
	tw.tween_callback(func(): _busy = false)


func _take(instant: bool) -> void:
	set_focus(false)
	taken = true
	_store()
	if target:
		if instant:
			target.visible = false
		else:
			var tw := create_tween()
			tw.tween_property(target, "scale", target.scale * 0.01, 0.18)
			tw.tween_callback(func(): target.visible = false)
	set_deferred("monitorable", false)
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)


func _store() -> void:
	if state_key != "":
		Game.world_state[state_key] = {"open": is_open, "taken": taken}


## Helper: build an Interactable whose box covers the meshes under `node` (in node-local space).
static func attach(node: Node3D, cfg: Dictionary) -> Interactable:
	var it := Interactable.new()
	it.name = "Interact"
	for k in cfg:
		it.set(k, cfg[k])
	if it.target == null and cfg.get("kind", "") in ["hinge", "slide", "pickup"]:
		it.target = node
	var box := aabb_of(node)
	if box.size.length() < 0.01:
		box = AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 0.4, 0.4))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = (box.size + Vector3.ONE * 0.04).max(Vector3.ONE * 0.12)
	cs.shape = bs
	cs.position = box.get_center()
	it.add_child(cs)
	node.add_child(it)
	return it


static func aabb_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse()
	for vi in node.find_children("*", "VisualInstance3D", true, false):
		var a: AABB = (inv * (vi as VisualInstance3D).global_transform) * (vi as VisualInstance3D).get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	if node is VisualInstance3D:
		var a2: AABB = (node as VisualInstance3D).get_aabb()
		out = a2 if first else out.merge(a2)
	return out
