extends HBoxContainer
class_name VeilQuickSlots
## THE VEIL - five quick-access slots (keys 1-5, or tap a slot). Presentation on top of the existing inventory:
## a slot holds an item id (saved in Game.world_state["quickslots"]); using it runs the item's first real action
## from the inventory screen (flashlight on / off, load batteries) or just selects it when it has none (keys
## stay passive and are never consumed). Items no longer carried show as empty.

const N := 5
const SLOT := 52
var _btn: Array = []
var selected := -1


static func slots() -> Array:
	var a: Array = Game.world_state.get("quickslots", [])
	while a.size() < N:
		a.append("")
	return a


static func assign(i: int, id: String) -> void:
	var a := slots()
	for k in N:                                   # one slot per item
		if a[k] == id:
			a[k] = ""
	a[i] = id
	Game.world_state["quickslots"] = a
	Game.inventory_changed.emit()
	var world := (Engine.get_main_loop() as SceneTree).get_first_node_in_group("veil_world")
	if world:
		world.save()


func _ready() -> void:
	add_to_group("veil_quick_slots")                 # the throwing system reads the selected slot
	# bottom-right corner, clear of the subtitles (centre) and the health / stamina bars (left)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -300
	offset_top = -118
	offset_bottom = -118 + SLOT                  # the bar is exactly one slot tall: square slots, not tall rectangles
	offset_right = -300 + N * SLOT + (N - 1) * 6
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in N:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.focus_mode = Control.FOCUS_NONE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.04, 0.05, 0.06, 0.7)
		st.border_color = VeilUI.EDGE
		st.set_border_width_all(1)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 5
		icon.offset_top = 5
		icon.offset_right = -5
		icon.offset_bottom = -5
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var num := VeilUI.label(str(i + 1), 10, VeilUI.MUTED)
		num.position = Vector2(3, 1)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(num)
		var q := VeilUI.label("", 11)
		q.name = "Qty"
		q.position = Vector2(30, 34)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(q)
		b.pressed.connect(func(): use(i))
		add_child(b)
		_btn.append(b)
	Game.inventory_changed.connect(refresh)
	refresh()


func refresh() -> void:
	_auto_slot()
	var w0 := get_tree().get_first_node_in_group("veil_world")
	var sa0 = w0.get("sidearm") if w0 else null
	if sa0 != null and sa0.has_gun() and sa0.drawn() and "handgun" in slots():
		selected = slots().find("handgun")             # a gun in the hand always has its slot selected
	var a := slots()
	var inv := get_tree().get_first_node_in_group("veil_inventory_panel") as VeilInventoryPanel
	for i in N:
		var b: Button = _btn[i]
		var id: String = a[i]
		var have := id != "" and Game.has_item(id) and VeilInventoryPanel.usable(id)
		(b.get_node("Icon") as TextureRect).texture = inv._icon(id) if have and inv else null
		var n := VeilInventoryPanel.quantity(id) if have else 0
		(b.get_node("Qty") as Label).text = "x%d" % n if n > 1 else ""
		var st := (b.get_theme_stylebox("normal") as StyleBoxFlat)
		st.border_color = Color(0.85, 0.82, 0.62) if i == selected else VeilUI.EDGE
		st.set_border_width_all(2 if i == selected else 1)


## Use slot i: select it and run the item's first real action, if any. The handgun is just another item: its slot draws it; any other slot, an empty one included, puts it away.
func use(i: int) -> bool:
	selected = i
	var id: String = slots()[i]
	var used := false
	_gun(id)
	if id != "" and id != "handgun" and Game.has_item(id):
		var inv := get_tree().get_first_node_in_group("veil_inventory_panel") as VeilInventoryPanel
		var acts: Array = inv.actions_for(id) if inv else []
		if not acts.is_empty():
			acts[0][1].call()
			used = true
	refresh()
	return used


## The mouse wheel steps through the five slots (an empty slot = hands free) without using what it lands on (except the gun, which comes up when its slot is selected).
func step(dir: int) -> void:
	var from := selected if selected >= 0 else 0
	selected = posmod(from + dir, N)
	_gun(String(slots()[selected]))
	_light(String(slots()[selected]))
	refresh()


## Landing on the flashlight's slot (the wheel) puts the light in the hand, switched on; landing anywhere else lowers it.
func _light(id: String) -> void:
	var fl := get_tree().get_first_node_in_group("veil_flashlight")
	if fl != null and fl.has_method("set_on") and Game.has_item("flashlight"):
		fl.set_on(id == "flashlight")


func _gun(id: String) -> void:
	var w := get_tree().get_first_node_in_group("veil_world")
	var sa = w.get("sidearm") if w else null
	if sa == null or not sa.has_gun():
		return
	sa.set_drawn(id == "handgun")


var _auto := false


## The gun lands in the first free slot by itself when it is picked up.
func _auto_slot() -> void:
	if _auto:
		return
	_auto = true
	for item in ["flashlight", "handgun"]:                  # the flashlight is a held item too, always in a slot (review note #32): its slot selected = the light in the hand
		if not Game.has_item(item) or item in slots():
			continue
		var a := slots()
		for k in N:
			if String(a[k]) == "" or not Game.has_item(String(a[k])):
				assign(k, item)
				if item == "handgun":
					var w := get_tree().get_first_node_in_group("veil_world")
					var sa = w.get("sidearm") if w else null
					if sa != null and sa.drawn():
						selected = k                          # it comes into the hand with its slot selected
				break
	_auto = false


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_5:
		var inv := get_tree().get_first_node_in_group("veil_inventory_panel") as VeilInventoryPanel
		if inv and inv.visible:
			return                                  # the inventory screen assigns with 1-5 instead
		use(e.physical_keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var inv2 := get_tree().get_first_node_in_group("veil_inventory_panel") as VeilInventoryPanel
		var w := get_tree().get_first_node_in_group("veil_world")
		var pl = w.get("player") if w else null
		if (inv2 and inv2.visible) or pl == null or not pl.controls_enabled or w.get("in_car") or w.get("conversing"):
			return
		step(1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		get_viewport().set_input_as_handled()
