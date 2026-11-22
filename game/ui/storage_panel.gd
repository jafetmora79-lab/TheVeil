extends CanvasLayer
class_name VeilStoragePanel
## The shelter supplies chest as two grids (review note #99): SHELTER STORES on the left (what the group has: food, water, medicine, with a picture of the item and the amount) and WHAT YOU CARRY on the right.
## Click a stored slot to take one (shift / right click: all); click a carried slot that the group can use (food, water, medicine, batteries) to put one in (shift / right click: all). The tree is paused while it is open.
signal closed(group: bool)
const COLS := 5
const ROWS := 5
const SLOT := 64
const STORE_KINDS := ["food", "water", "medical", "batteries"]
const SUPPLY_ITEM := {"food": "canned_food", "water": "water_bottle", "medical": "painkillers", "batteries": "batteries"}
var world: Node
var p4: Node
var _root: Control
var _left: GridContainer
var _right: GridContainer
var _info: Label
var _paused_by_me := false


func setup(w: Node, phase4: Node) -> void:
	world = w
	p4 = phase4
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_root = Control.new()
	_root.custom_minimum_size = Vector2(900, 520)
	_root.size = Vector2(900, 520)
	add_child(_root)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", VeilUI.panel_style())
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var title := VeilUI.label("SHELTER SUPPLIES", 20)
	title.position = Vector2(24, 14)
	_root.add_child(title)
	var lt := VeilUI.label("STORED  (click: take one, shift: all)", 13, VeilUI.MUTED)
	lt.position = Vector2(24, 52)
	_root.add_child(lt)
	var rt := VeilUI.label("YOU CARRY  (click: store one, shift: all)", 13, VeilUI.MUTED)
	rt.position = Vector2(470, 52)
	_root.add_child(rt)
	_left = GridContainer.new()
	_left.columns = COLS
	_left.position = Vector2(24, 76)
	_left.add_theme_constant_override("h_separation", 4)
	_left.add_theme_constant_override("v_separation", 4)
	_root.add_child(_left)
	_right = GridContainer.new()
	_right.columns = COLS
	_right.position = Vector2(470, 76)
	_right.add_theme_constant_override("h_separation", 4)
	_right.add_theme_constant_override("v_separation", 4)
	_root.add_child(_right)
	_info = VeilUI.label("", 13)
	_info.position = Vector2(24, 418)
	_info.size = Vector2(852, 56)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_info)
	var grp := Button.new()
	grp.text = "Check on the Group"
	grp.position = Vector2(560, 478)
	grp.size = Vector2(190, 32)
	grp.focus_mode = Control.FOCUS_NONE
	grp.pressed.connect(func(): _close(true))
	_root.add_child(grp)
	var cl := Button.new()
	cl.text = "Close"
	cl.position = Vector2(770, 478)
	cl.size = Vector2(110, 32)
	cl.focus_mode = Control.FOCUS_NONE
	cl.pressed.connect(func(): _close(false))
	_root.add_child(cl)
	if world.survivors == null:
		grp.visible = false
	get_viewport().size_changed.connect(_fit)
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	Game.inventory_changed.connect(refresh)
	refresh()
	_fit()
	_fit.call_deferred()


func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k := minf(1.0, minf(vs.x / 930.0, vs.y / 550.0))
	_root.scale = Vector2(k, k)
	_root.position = (vs - _root.size * k) * 0.5


func _icon(id: String) -> Texture2D:
	var inv = world.hud.get("inv_panel") if world.hud else null
	return inv._icon(id) if inv != null else null


func _slot(parent: GridContainer, id: String, qty: int, tip: String, on_click: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.07, 0.95)
	st.border_color = VeilUI.EDGE
	st.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("disabled", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.border_color = Color(0.85, 0.82, 0.62)
	hv.set_border_width_all(2)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	if id != "":
		var ic := TextureRect.new()
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 4
		ic.offset_top = 4
		ic.offset_right = -4
		ic.offset_bottom = -4
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = _icon(id)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		if ic.texture == null:
			var n := VeilUI.label(String(Game.item_info(id).get("name", id)), 10, VeilUI.MUTED)
			n.position = Vector2(4, 4)
			n.size = Vector2(SLOT - 8, SLOT - 8)
			n.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(n)
		var q := VeilUI.label("x%d" % qty, 13)
		q.position = Vector2(SLOT - 34, SLOT - 24)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(q)
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
				on_click.call(e.button_index == MOUSE_BUTTON_RIGHT or Input.is_key_pressed(KEY_SHIFT)))
	else:
		b.disabled = true
	parent.add_child(b)


func refresh() -> void:
	if _left == null:
		return
	for c in _left.get_children():
		c.queue_free()
	for c in _right.get_children():
		c.queue_free()
	var stock := Game.shelter_stock()
	var cells := 0
	for r in STORE_KINDS:
		var n := int(stock.get(r, 0))
		if n > 0:
			var id := String(SUPPLY_ITEM[r])
			_slot(_left, id, n, "%s - the group's stores" % Game.item_info(id).get("name", id), func(all: bool): _take(r, all))
			cells += 1
	for i in range(cells, COLS * ROWS):
		_slot(_left, "", 0, "", Callable())
	var seen: Array = []
	cells = 0
	for id in Game.inventory:
		if id in seen or id in VeilInventoryPanel.SHOPPING_ONLY:
			continue
		seen.append(id)
		var q := VeilInventoryPanel.quantity(id)
		var storable := Game.shelter_resource(String(id)) != ""
		_slot(_right, String(id), q, String(Game.item_info(id).get("name", id)) + ("" if storable else " - not for the stores"), func(all: bool): _put(String(id), all))
		cells += 1
		if cells >= COLS * ROWS:
			break
	for i in range(cells, COLS * ROWS):
		_slot(_right, "", 0, "", Callable())
	var text := ""
	if world.expedition and world.expedition.shelter() != "":
		var need: Dictionary = world.expedition.supply_need()
		text = "Tonight the group needs %d food and %d water.  Stored: food %d, water %d, medicine %d." % [need["need"], need["need"], need["food"], need["water"], int(stock.get("medical", 0))]
		if int(need["food"]) < int(need["need"]):
			text += "  Short of food."
		if int(need["water"]) < int(need["need"]):
			text += "  Short of water."
	else:
		text = "Food %d   Water %d   Medicine %d" % [int(stock.get("food", 0)), int(stock.get("water", 0)), int(stock.get("medical", 0))]
	_info.text = text


func _take(r: String, all: bool) -> void:
	var n := int(Game.shelter_stock().get(r, 0)) if all else 1
	for i in n:
		p4._withdraw(r)
	refresh()


func _put(id: String, all: bool) -> void:
	if Game.shelter_resource(id) == "":
		_info.text = "The group has no use for that: keep it."
		return
	var n := Game.inventory.count(id) if all else 1
	if id == "batteries":
		n = VeilInventoryPanel.quantity(id) if all else 1
	for i in n:
		if not world.deposit_shelter_item(id):
			break
	refresh()


func _close(group: bool) -> void:
	if Game.inventory_changed.is_connected(refresh):
		Game.inventory_changed.disconnect(refresh)
	if _paused_by_me:
		get_tree().paused = false
	closed.emit(group)
	queue_free()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_close(false)
