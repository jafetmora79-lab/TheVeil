extends Control
class_name VeilInventoryPanel
## THE VEIL - survival-horror inventory screen (reusable; presentation only).
## Backend unchanged: Game.inventory (item ids), game/data/items.json (name, category, description, model,
## weight). Quantities: one per id, except batteries (= the flashlight's spare count). Weight is display only
## (placeholder values; carry_capacity_kg in items.json).
## Layout (a square panel): item grid with 3D-model icons on top; below it the selected item's picture, name,
## how to use it and its action buttons; weight bar + one line of controls at the bottom.
## Only items that can be USED are listed (USABLE below); key / story items without a use stay carried
## (Game.inventory is unchanged) but are not shown. Click a slot to select it, click its button to use it, click its
## picture to inspect it (the model turns slowly in a large view). Keyboard / touch still work.

signal closed

const COLS := 6
const ROWS := 2
const SLOT := 84
const PANEL := 600                ## the panel is square: PANEL x PANEL
## Items with a real use, and the one sentence that explains it (the button does exactly this).
const USE_TEXT := {
	"flashlight": "Click SWITCH ON / SWITCH OFF to light the dark. Its charge runs down while it is on.",
	"batteries": "Click LOAD INTO FLASHLIGHT when the flashlight is running low.",
	"food": "Click EAT to restore your stamina and a little health. It is used up.",
	"drink": "Click DRINK to restore your stamina and a little health. It is used up.",
	"medical": "Click TAKE to restore health. It is used up.",
	"note": "Click READ to read it.",
}
const DRINKS := ["water_bottle", "cola_bottle"]
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
var _pv_button: Button
var _quick: HBoxContainer
var _insp: Control                 ## the inspect view (large turning model)
var _insp_vp: SubViewport
var _insp_pivot: Node3D
var _insp_tex: TextureRect
var _insp_name: Label
var _insp_desc: Label


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
	panel.custom_minimum_size = Vector2(PANEL, PANEL)
	center.add_child(panel)
	_main = panel
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
	var gwrap := CenterContainer.new()
	col.add_child(gwrap)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	gwrap.add_child(_grid)
	for i in COLS * ROWS:
		_slots.append(_make_slot(i))
	var line := ColorRect.new()
	line.color = VeilUI.EDGE
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var pv := Button.new()                         # the picture: click it to inspect the item
	pv.custom_minimum_size = Vector2(150, 150)
	pv.focus_mode = Control.FOCUS_NONE
	pv.tooltip_text = "Click to inspect"
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color(0.05, 0.06, 0.07, 0.95)
	pst.border_color = VeilUI.EDGE
	pst.set_border_width_all(1)
	pv.add_theme_stylebox_override("normal", pst)
	var psh := pst.duplicate() as StyleBoxFlat
	psh.border_color = Color(0.85, 0.82, 0.62)
	pv.add_theme_stylebox_override("hover", psh)
	pv.add_theme_stylebox_override("pressed", psh)
	pv.pressed.connect(func(): inspect())
	body.add_child(pv)
	_preview = TextureRect.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 8
	_preview.offset_top = 8
	_preview.offset_right = -8
	_preview.offset_bottom = -22
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(_preview)
	var ihint := VeilUI.label("INSPECT", 11, VeilUI.MUTED)
	ihint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ihint.offset_top = -18
	ihint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ihint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(ihint)
	_pv_button = pv
	var det := VBoxContainer.new()
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.add_theme_constant_override("separation", 6)
	body.add_child(det)
	_name = VeilUI.label("", 20)
	det.add_child(_name)
	_cat = VeilUI.label("", 13, VeilUI.MUTED)
	det.add_child(_cat)
	_desc = VeilUI.label("", 14)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(380, 40)
	det.add_child(_desc)
	_qty = VeilUI.label("", 13, VeilUI.MUTED)
	det.add_child(_qty)
	_wt = VeilUI.label("", 13, VeilUI.MUTED)
	det.add_child(_wt)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	det.add_child(_actions)
	_quick = HBoxContainer.new()
	_quick.add_theme_constant_override("separation", 4)
	det.add_child(_quick)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	_weight = VeilUI.label("", 13)
	foot.add_child(_weight)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.1, 0.12, 0.14)
	bar_bg.custom_minimum_size = Vector2(140, 10)
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(bar_bg)
	_weight_bar = ColorRect.new()
	_weight_bar.color = Color(0.62, 0.66, 0.6)
	_weight_bar.size = Vector2(0, 10)
	bar_bg.add_child(_weight_bar)
	var help := VeilUI.label("Click an item to select it  ·  click its button to use it  ·  click the picture to inspect", 12, VeilUI.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(help)
	_build_inspect()
	Game.inventory_changed.connect(refresh)
	get_viewport().size_changed.connect(_fit)
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
		w += float(Game.item_info(id).get("weight", 0.0)) * quantity(id) / maxi(1, Game.inventory.count(id))
	return w


## Shown in the inventory: only items the player can actually use (key / story items without a use are carried
## but not listed; groceries still to be paid for are not the player's yet).
static func usable(id: String) -> bool:
	match String(Game.item_info(id).get("category", "")):
		"flashlight", "medical", "note":
			return true
		"food":
			return id != "groceries" and Game.has_flag("groceries_done")
	return false


func refresh() -> void:
	_ids = Game.inventory.filter(func(id): return usable(id))
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
	for c in _quick.get_children():
		c.queue_free()
	_pv_button.disabled = i >= _ids.size()
	if i >= _ids.size():
		_name.text = "Nothing usable on you." if _ids.is_empty() else ""
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
	_desc.text = how_to(id)
	var n := quantity(id)
	_qty.text = "QUANTITY  %d" % n
	var each := float(info.get("weight", 0.0))
	_wt.text = "WEIGHT  %.2f kg" % each + ("   (total %.2f kg)" % (each * n) if n > 1 else "")
	_preview.texture = _icon(id)
	_quick.add_child(VeilUI.label("QUICK SLOT", 11, VeilUI.MUTED))
	for k in 5:                                  # put it on a quick slot: then press that number key in the game
		var qb := VeilUI.button(str(k + 1))
		qb.custom_minimum_size = Vector2(30, 26)
		qb.tooltip_text = "Put in quick slot %d (press %d in the game to use it)" % [k + 1, k + 1]
		qb.pressed.connect(func(): VeilQuickSlots.assign(k, id))
		_quick.add_child(qb)
	for a in actions_for(id):
		var b := VeilUI.button(a[0])
		b.pressed.connect(func():
			a[1].call()
			refresh())
		_actions.add_child(b)


## [label, callable] pairs for actions the game really supports for this item.
func actions_for(id: String) -> Array:
	var out: Array = []
	var cat := String(Game.item_info(id).get("category", ""))
	var world := get_tree().get_first_node_in_group("veil_world")
	if world and world.has_method("can_heal_with") and world.can_heal_with(id):
		out.append(["USE FOR HEALING", func(): world.use_healing_item(id)])   # the shelter's healing rules
		return out
	var fl := _flashlight()
	if id == "flashlight" and fl:
		out.append(["SWITCH OFF" if fl.on else "SWITCH ON", func(): fl.set_on(not fl.on)])
	elif id == "batteries" and fl and fl.spares > 0 and fl.charge < 1.0:
		out.append(["LOAD INTO FLASHLIGHT", func(): fl.reload()])
	elif cat == "food" and usable(id):
		out.append(["DRINK" if id in DRINKS else "EAT", func(): _consume(id, 10.0, true)])
	elif cat == "medical" and not (world and world.has_method("can_heal_with")):
		out.append(["TAKE", func(): _consume(id, 35.0, false)])   # (the shelter's rule above wins: no waste at full health)
	elif id == "handgun" and world and world.get("sidearm"):
		var sa = world.sidearm
		out.append(["HOLSTER" if sa.drawn() else "DRAW", func(): sa.set_drawn(not sa.drawn())])
	elif cat == "note":
		out.append(["READ", func(): inspect()])
	return out


## The one-line explanation shown under the item's name (what its button does).
func how_to(id: String) -> String:
	var cat := String(Game.item_info(id).get("category", ""))
	var key := "drink" if id in DRINKS else cat
	if id == "flashlight" or id == "batteries":
		key = id
	var fl := _flashlight()
	if id == "batteries" and fl and fl.charge >= 1.0:
		return "Spare batteries for the flashlight. It is fully charged right now."
	if (id == "flashlight" or id == "batteries") and fl == null:
		return "You have no use for it here yet."
	return USE_TEXT.get(key, String(Game.item_info(id).get("description", "")))


func _consume(id: String, health: float, refill_stamina: bool) -> void:
	var pl = get_tree().current_scene.get("player") if get_tree().current_scene else null
	if pl is VeilPlayer:
		(pl as VeilPlayer).heal(health)
		if refill_stamina:
			pl.stamina = VeilPlayer.MAX_STAMINA
			pl.stamina_changed.emit(pl.stamina, VeilPlayer.MAX_STAMINA)
	Game.remove_item(id)


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


# ------------------------------------------------------------------ inspect: the item large, slowly turning
func _build_inspect() -> void:
	_insp = Control.new()
	_insp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_insp.mouse_filter = Control.MOUSE_FILTER_STOP
	_insp.visible = false
	add_child(_insp)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_insp.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_insp.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", VeilUI.panel_style())
	panel.custom_minimum_size = Vector2(PANEL, PANEL)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_insp_name = VeilUI.label("", 22)
	head.add_child(_insp_name)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var back := VeilUI.button("BACK")
	back.pressed.connect(close_inspect)
	head.add_child(back)
	_insp_vp = SubViewport.new()
	_insp_vp.size = Vector2i(360, 360)
	_insp_vp.transparent_bg = true
	_insp_vp.own_world_3d = true
	_insp_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_insp_vp)
	_insp_tex = TextureRect.new()
	_insp_tex.custom_minimum_size = Vector2(360, 360)
	_insp_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_insp_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_insp_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_insp_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(_insp_tex)
	_insp_desc = VeilUI.label("", 15)
	_insp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_insp_desc.custom_minimum_size = Vector2(PANEL - 40, 0)
	col.add_child(_insp_desc)
	col.add_child(VeilUI.label("Click BACK (or press Esc) to return", 12, VeilUI.MUTED))


## Open the large view of the selected item: its model turns slowly; name and full description below.
func inspect() -> void:
	if _sel >= _ids.size():
		return
	var id: String = _ids[_sel]
	var info := Game.item_info(id)
	_insp_name.text = String(info.get("name", id)).to_upper()
	_insp_desc.text = String(info.get("description", ""))
	for c in _insp_vp.get_children():
		c.queue_free()
	_insp_pivot = null
	var path := String(info.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		_insp_pivot = Node3D.new()
		_insp_vp.add_child(_insp_pivot)
		_insp_pivot.add_child(model)
		var box := Interactable.aabb_of(model)
		if box.size.length() < 0.001:
			box = AABB(Vector3(-0.1, 0, -0.1), Vector3(0.2, 0.2, 0.2))
		model.position = -box.get_center()              # turn about its own centre
		var r := maxf(box.size.length() * 0.5, 0.03)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.55, 0.56, 0.6)
		e.background_mode = Environment.BG_CLEAR_COLOR
		env.environment = e
		_insp_vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, 30, 0)
		sun.light_energy = 1.1
		_insp_vp.add_child(sun)
		var cam := Camera3D.new()
		cam.fov = 30.0
		cam.near = 0.01
		_insp_vp.add_child(cam)
		cam.position = Vector3(0, 0.35, 1.0).normalized() * r / tan(deg_to_rad(15.0)) * 1.1
		cam.look_at(Vector3.ZERO, Vector3.UP)
		_insp_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_insp_tex.texture = _insp_vp.get_texture()
	else:
		_insp_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_insp_tex.texture = _icon(id)
	_insp.visible = true


func close_inspect() -> void:
	_insp.visible = false
	_insp_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_inspecting() -> bool:
	return _insp != null and _insp.visible


func _process(delta: float) -> void:
	if visible and is_inspecting() and _insp_pivot:
		_insp_pivot.rotate_y(delta * 0.6)              # a slow turn (about 10 s per revolution)


# ------------------------------------------------------------------ open / close / keyboard
var _main: PanelContainer


## Keep the panel square (as wide as its content is tall) and scaled down to fit the window: its text lines are
## taller than the 600 px design allowed for, which pushed the bottom off a 720 px screen.
func _fit() -> void:
	if _main == null:
		return
	var need := _main.get_combined_minimum_size()
	var side := maxf(PANEL, maxf(need.x, need.y))
	_main.custom_minimum_size = Vector2(side, side)
	var vp := get_viewport_rect().size
	var k := minf(1.0, minf(vp.x * 0.94 / side, vp.y * 0.94 / side))
	_main.pivot_offset = Vector2(side, side) * 0.5
	_main.scale = Vector2.ONE * k


func open() -> void:
	refresh()
	visible = true
	_fit()
	_fit.call_deferred()                               # again once the new details have been laid out


func close() -> void:
	if visible:
		close_inspect()
		visible = false
		closed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if is_inspecting():
		if e.is_action_pressed("ui_cancel") or e.is_action_pressed("interact") or e.is_action_pressed("ui_accept"):
			close_inspect()
			get_viewport().set_input_as_handled()
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
