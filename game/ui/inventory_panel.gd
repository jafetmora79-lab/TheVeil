extends Control
class_name VeilInventoryPanel
## THE VEIL - survival-horror inventory screen (reusable; presentation only).
## Backend unchanged: Game.inventory (item ids), game/data/items.json (name, category, description, model,
## weight). Quantities: one per id, except batteries (= the flashlight's spare count). Weight is display only
## (placeholder values; carry_capacity_kg in items.json).
## Layout: item grid with 3D-model icons (each Pack 08 model rendered once into a small SubViewport) | details
## (larger preview, name, category, description, quantity, weight, actions) | weight bar + controls.
## Actions are only the ones the game already supports: the flashlight (switch on / off) and its batteries (load).
## Mouse, keyboard (arrows / WASD to move, E / Enter to act, Tab / Esc to close) and touch (tap a slot, tap a button).

signal closed

const COLS := 4
const ROWS := 4
const SLOT := 84
const CAT_COLOR := {"food": Color(0.55, 0.62, 0.38), "medical": Color(0.66, 0.32, 0.3), "flashlight": Color(0.75, 0.66, 0.33),
	"key": Color(0.55, 0.52, 0.66), "weapon": Color(0.5, 0.5, 0.52), "tool": Color(0.45, 0.55, 0.6),
	"radio": Color(0.4, 0.6, 0.55), "note": Color(0.6, 0.58, 0.5), "puzzle": Color(0.6, 0.45, 0.6), "misc": Color(0.45, 0.47, 0.5)}
const CAT_NAME := {"food": "FOOD", "medical": "MEDICAL", "flashlight": "LIGHT / BATTERIES", "key": "KEY ITEM",
	"weapon": "WEAPON", "tool": "TOOL", "radio": "RADIO", "note": "DOCUMENT", "puzzle": "KEY ITEM", "misc": "MISC."}

var _grid: GridContainer
var _slots: Array = []
var _name: Label
var _cat: Label
var _desc: Label
var _qty: Label
var _wt: Label
var _preview: TextureRect
var _actions: HBoxContainer
var _weight: Label
var _weight_bar: ColorRect
var _sel := 0
var _ids: Array = []
var _icons := {}             ## item id -> ViewportTexture (rendered once)
var _views := {}


func _ready() -> void:
	add_to_group("veil_inventory_panel")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", VeilUI.panel_style())
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(VeilUI.label("INVENTORY", 22))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var x := VeilUI.button("CLOSE")
	x.pressed.connect(close)
	head.add_child(x)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	col.add_child(body)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(_grid)
	for i in COLS * ROWS:
		_slots.append(_make_slot(i))
	var det := VBoxContainer.new()
	det.custom_minimum_size = Vector2(300, 0)
	det.add_theme_constant_override("separation", 8)
	body.add_child(det)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(150, 150)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	det.add_child(_preview)
	_name = VeilUI.label("", 20)
	det.add_child(_name)
	_cat = VeilUI.label("", 13, VeilUI.MUTED)
	det.add_child(_cat)
	_desc = VeilUI.label("", 14, VeilUI.MUTED)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(300, 60)
	det.add_child(_desc)
	_qty = VeilUI.label("", 14)
	det.add_child(_qty)
	_wt = VeilUI.label("", 14, VeilUI.MUTED)
	det.add_child(_wt)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	det.add_child(_actions)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	_weight = VeilUI.label("", 14)
	foot.add_child(_weight)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.1, 0.12, 0.14)
	bar_bg.custom_minimum_size = Vector2(180, 10)
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(bar_bg)
	_weight_bar = ColorRect.new()
	_weight_bar.color = Color(0.62, 0.66, 0.6)
	_weight_bar.size = Vector2(0, 10)
	bar_bg.add_child(_weight_bar)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	foot.add_child(VeilUI.label("" if _touch() else "Arrows select  ·  E use  ·  Tab close", 13, VeilUI.MUTED))
	Game.inventory_changed.connect(refresh)
	refresh()


func _touch() -> bool:
	return DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")


func _make_slot(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.07, 0.95)
	st.border_color = VeilUI.EDGE
	st.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	var sel := st.duplicate() as StyleBoxFlat
	sel.border_color = Color(0.85, 0.82, 0.62)
	sel.set_border_width_all(2)
	b.add_theme_stylebox_override("pressed", sel)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var tag := ColorRect.new()
	tag.name = "Cat"
	tag.size = Vector2(SLOT - 2, 3)
	tag.position = Vector2(1, SLOT - 4)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tag)
	var q := VeilUI.label("", 13)
	q.name = "Qty"
	q.position = Vector2(SLOT - 26, SLOT - 26)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(q)
	var n := VeilUI.label("", 10, VeilUI.MUTED)
	n.name = "Letter"
	n.position = Vector2(6, 4)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(n)
	b.pressed.connect(func(): select(i))
	_grid.add_child(b)
	return b


## Quantity of an item the player carries (stack sizes come from the systems that own them).
static func quantity(id: String) -> int:
	if not Game.has_item(id):
		return 0
	if id == "batteries":
		var fl := _flashlight()
		return fl.spares if fl else 1
	return Game.inventory.count(id)


static func _flashlight() -> VeilFlashlight:
	var t := Engine.get_main_loop() as SceneTree
	return t.get_first_node_in_group("veil_flashlight") as VeilFlashlight if t else null


static func carried_weight() -> float:
	var w := 0.0
	for id in Game.inventory:
		w += float(Game.item_info(id).get("weight", 0.0)) * maxi(1, quantity(id)) / maxi(1, Game.inventory.count(id))
	return w


func refresh() -> void:
	_ids = Game.inventory.duplicate()
	for i in _slots.size():
		var b: Button = _slots[i]
		var icon := b.get_node("Icon") as TextureRect
		var q := b.get_node("Qty") as Label
		var tag := b.get_node("Cat") as ColorRect
		var letter := b.get_node("Letter") as Label
		if i < _ids.size():
			var id: String = _ids[i]
			var info := Game.item_info(id)
			icon.texture = _icon(id)
			var n := quantity(id)
			q.text = "x%d" % n if n > 1 else ""
			tag.color = CAT_COLOR.get(String(info.get("category", "misc")), CAT_COLOR["misc"])
			tag.visible = true
			letter.text = "" if icon.texture else String(info.get("name", id)).left(3).to_upper()
			b.disabled = false
		else:
			icon.texture = null
			q.text = ""
			letter.text = ""
			tag.visible = false
			b.disabled = true
		b.button_pressed = i == _sel and i < _ids.size()
	var cap := float(Game.items.get("carry_capacity_kg", 15.0))
	var w := carried_weight()
	_weight.text = "WEIGHT  %.1f / %.1f kg" % [w, cap]
	_weight_bar.size = Vector2(180.0 * clampf(w / cap, 0.0, 1.0), 10)
	_weight_bar.color = Color(0.62, 0.66, 0.6) if w <= cap else Color(0.75, 0.35, 0.3)
	select(clampi(_sel, 0, maxi(_ids.size() - 1, 0)))


func select(i: int) -> void:
	_sel = i
	for k in _slots.size():
		(_slots[k] as Button).button_pressed = k == i and k < _ids.size()
	for c in _actions.get_children():
		c.queue_free()
	if i >= _ids.size():
		_name.text = "Pockets are empty." if _ids.is_empty() else ""
		_cat.text = ""
		_desc.text = ""
		_qty.text = ""
		_wt.text = ""
		_preview.texture = null
		return
	var id: String = _ids[i]
	var info := Game.item_info(id)
	var cat := String(info.get("category", "misc"))
	_name.text = String(info.get("name", id)).to_upper()
	_cat.text = CAT_NAME.get(cat, cat.to_upper())
	_cat.add_theme_color_override("font_color", CAT_COLOR.get(cat, CAT_COLOR["misc"]).lightened(0.25))
	_desc.text = String(info.get("description", ""))
	var n := quantity(id)
	_qty.text = "QUANTITY  %d" % n
	var each := float(info.get("weight", 0.0))
	_wt.text = "WEIGHT  %.2f kg" % each + ("   (total %.2f kg)" % (each * n) if n > 1 else "")
	_preview.texture = _icon(id)
	for k in 5:                                  # assign to a quick slot (keys 1-5, or these buttons on touch)
		var qb := VeilUI.button(str(k + 1))
		qb.custom_minimum_size = Vector2(34, 30)
		qb.tooltip_text = "Put in quick slot %d" % (k + 1)
		qb.pressed.connect(func(): VeilQuickSlots.assign(k, id))
		_actions.add_child(qb)
	for a in actions_for(id):
		var b := VeilUI.button(a[0])
		b.pressed.connect(func():
			a[1].call()
			refresh())
		_actions.add_child(b)


## [label, callable] pairs for actions the game really supports for this item.
func actions_for(id: String) -> Array:
	var out: Array = []
	var fl := _flashlight()
	if fl == null:
		return out
	if id == "flashlight":
		out.append(["SWITCH OFF" if fl.on else "SWITCH ON", func(): fl.set_on(not fl.on)])
	elif id == "batteries" and fl.spares > 0 and fl.charge < 1.0:
		out.append(["LOAD INTO FLASHLIGHT", func(): fl.reload()])
	return out


# ------------------------------------------------------------------ icons: the item's own 3D model, rendered once
func _icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var icon_path := String(Game.item_info(id).get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icons[id] = load(icon_path)                 # a flat pixel icon (items without a Pack 08 model)
		return _icons[id]
	var path := String(Game.item_info(id).get("model", ""))
	if path == "" or not ResourceLoader.exists(path):
		_icons[id] = null
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	vp.add_child(model)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.56, 0.6)
	e.background_mode = Environment.BG_CLEAR_COLOR
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var box := Interactable.aabb_of(model)
	if box.size.length() < 0.001:
		box = AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.2, 0.2))
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.5, 0.03)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.01
	vp.add_child(cam)
	cam.position = c + Vector3(0.55, 0.45, 1.0).normalized() * r / tan(deg_to_rad(15.0)) * 1.05
	cam.look_at(c, Vector3.UP)
	var tex := vp.get_texture()
	_icons[id] = tex
	_views[id] = vp
	return tex


# ------------------------------------------------------------------ open / close / keyboard
func open() -> void:
	refresh()
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("ui_cancel"):
		close()
	elif e.is_action_pressed("ui_right") or e.is_action_pressed("move_right"):
		select(mini(_sel + 1, maxi(_ids.size() - 1, 0)))
	elif e.is_action_pressed("ui_left") or e.is_action_pressed("move_left"):
		select(maxi(_sel - 1, 0))
	elif e.is_action_pressed("ui_down") or e.is_action_pressed("move_back"):
		select(mini(_sel + COLS, maxi(_ids.size() - 1, 0)))
	elif e.is_action_pressed("ui_up") or e.is_action_pressed("move_forward"):
		select(maxi(_sel - COLS, 0))
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_5:
		if _sel < _ids.size():
			VeilQuickSlots.assign(e.physical_keycode - KEY_1, _ids[_sel])
	elif e.is_action_pressed("interact") or e.is_action_pressed("ui_accept"):
		var acts := actions_for(_ids[_sel]) if _sel < _ids.size() else []
		if not acts.is_empty():
			acts[0][1].call()
			refresh()
	else:
		return
	get_viewport().set_input_as_handled()
