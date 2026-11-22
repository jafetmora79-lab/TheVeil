extends CanvasLayer
class_name VeilStoragePanel
## The shelter supplies chest as two grids (review note #99): SHELTER STORES on the left (what the group has: food, water, medicine, with a picture of the item and the amount) and WHAT YOU CARRY on the right.
## DRAG an item to move it: onto another cell of the same grid to rearrange / swap, or across to the other grid to take it or store it (the whole stack). Right click moves one, double click or shift click moves the whole stack.
## Only what the group can use (food, water, medicine, batteries) can be stored. The tree is paused while it is open.
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
static var _mem_l: Array = []                   ## cell arrangement, kept between openings: stored kinds
static var _mem_r: Array = []                   ## carried item ids


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
	var hint := VeilUI.label("Drag to move or swap.  Right click: one.  Double click: all.", 12, VeilUI.MUTED)
	hint.position = Vector2(24, 44)
	_root.add_child(hint)
	var lt := VeilUI.label("STORED", 15)
	lt.position = Vector2(24, 66)
	_root.add_child(lt)
	var rt := VeilUI.label("YOU CARRY", 15)
	rt.position = Vector2(470, 66)
	_root.add_child(rt)
	_left = GridContainer.new()
	_left.columns = COLS
	_left.position = Vector2(24, 92)
	_left.add_theme_constant_override("h_separation", 4)
	_left.add_theme_constant_override("v_separation", 4)
	_root.add_child(_left)
	_right = GridContainer.new()
	_right.columns = COLS
	_right.position = Vector2(470, 92)
	_right.add_theme_constant_override("h_separation", 4)
	_right.add_theme_constant_override("v_separation", 4)
	_root.add_child(_right)
	_info = VeilUI.label("", 13)
	_info.position = Vector2(24, 440)
	_info.size = Vector2(852, 40)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.clip_text = true
	_root.add_child(_info)
	var grp := Button.new()
	grp.text = "Check on the Group"
	grp.position = Vector2(560, 484)
	grp.size = Vector2(190, 32)
	grp.focus_mode = Control.FOCUS_NONE
	grp.pressed.connect(func(): _close(true))
	_root.add_child(grp)
	var cl := Button.new()
	cl.text = "Close"
	cl.position = Vector2(770, 484)
	cl.size = Vector2(110, 32)
	cl.focus_mode = Control.FOCUS_NONE
	cl.pressed.connect(func(): _close(false))
	_root.add_child(cl)
	if world.survivors == null:
		grp.visible = false
	if _mem_l.size() != COLS * ROWS:
		_mem_l = _blank()
	if _mem_r.size() != COLS * ROWS:
		_mem_r = _blank()
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


func _blank() -> Array:
	var a: Array = []
	a.resize(COLS * ROWS)
	a.fill("")
	return a


func _slot(parent: GridContainer, side: int, idx: int, id: String, qty: int, tip: String, on_click: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT, SLOT)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
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
		var shown := _item_of(side, id)
		var ic := TextureRect.new()
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 6
		ic.offset_top = 4
		ic.offset_right = -6
		ic.offset_bottom = -14
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = _icon(shown)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		if ic.texture == null:
			var n := VeilUI.label(String(Game.item_info(shown).get("name", shown)), 9, VeilUI.MUTED)
			n.position = Vector2(4, 4)
			n.size = Vector2(SLOT - 8, SLOT - 18)
			n.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			n.clip_text = true
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(n)
		var qs := "x%d" % qty
		var q := VeilUI.label(qs, 11)
		q.position = Vector2(SLOT - 8 - 9 * qs.length(), SLOT - 17)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(q)
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				if e.button_index == MOUSE_BUTTON_RIGHT:
					on_click.call(false)
				elif e.button_index == MOUSE_BUTTON_LEFT and (e.double_click or Input.is_key_pressed(KEY_SHIFT)):
					on_click.call(true))
	b.set_drag_forwarding(_drag.bind(side, idx, id), _can_drop.bind(side, idx), _drop.bind(side, idx))
	parent.add_child(b)


## The item id behind a cell token: the left grid holds supply kinds, the right grid holds item ids.
func _item_of(side: int, token: String) -> String:
	return String(SUPPLY_ITEM.get(token, token)) if side == 0 else token


func _drag(_at: Vector2, side: int, _idx: int, token: String) -> Variant:
	if token == "":
		return null
	var pv := Control.new()
	var ic := TextureRect.new()
	ic.texture = _icon(_item_of(side, token))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size = Vector2(48, 48)
	ic.position = Vector2(-24, -24)
	ic.modulate = Color(1, 1, 1, 0.85)
	pv.add_child(ic)
	_root.set_drag_preview(pv)
	return {"side": side, "idx": _idx, "token": token}


func _can_drop(_at: Vector2, data: Variant, side: int, _idx: int) -> bool:
	if not (data is Dictionary and data.has("side")):
		return false
	if int(data["side"]) == side:
		return true
	if int(data["side"]) == 1:
		return Game.shelter_resource(String(data["token"])) != ""     # only what the group can use goes into the stores
	return true


func _drop(_at: Vector2, data: Variant, side: int, idx: int) -> void:
	var from := int(data["side"])
	var tok := String(data["token"])
	var arr: Array = _mem_l if side == 0 else _mem_r
	if from == side:
		var f := int(data["idx"])
		var t = arr[idx]
		arr[idx] = arr[f]
		arr[f] = t
		refresh()
		return
	if from == 0:
		_take(tok, true)
		var id := String(SUPPLY_ITEM[tok])
		var at := _mem_r.find(id)
		if at >= 0 and at != idx and _mem_r[idx] == "":
			_mem_r[idx] = id
			_mem_r[at] = ""
	else:
		_put(tok, true)
		var kind := Game.shelter_resource(tok)
		var at2 := _mem_l.find(kind)
		if at2 >= 0 and at2 != idx and _mem_l[idx] == "":
			_mem_l[idx] = kind
			_mem_l[at2] = ""
	refresh()


## Keep the remembered cell arrangement in step with what exists: drop what is gone, put newcomers in the first free cell.
func _reconcile(mem: Array, present: Array) -> void:
	for i in mem.size():
		if mem[i] != "" and not present.has(mem[i]):
			mem[i] = ""
	for p in present:
		if not mem.has(p):
			var at := mem.find("")
			if at >= 0:
				mem[at] = p


func refresh() -> void:
	if _left == null:
		return
	for c in _left.get_children():
		c.queue_free()
	for c in _right.get_children():
		c.queue_free()
	var stock := Game.shelter_stock()
	var kinds: Array = []
	for r in STORE_KINDS:
		if int(stock.get(r, 0)) > 0:
			kinds.append(r)
	_reconcile(_mem_l, kinds)
	for i in COLS * ROWS:
		var r := String(_mem_l[i])
		if r == "":
			_slot(_left, 0, i, "", 0, "", Callable())
		else:
			var sid := String(SUPPLY_ITEM[r])
			_slot(_left, 0, i, r, int(stock.get(r, 0)), "%s - in the stores" % Game.item_info(sid).get("name", sid), func(all: bool): _take(r, all))
	var ids: Array = []
	for id in Game.inventory:
		if not (id in ids) and not (id in VeilInventoryPanel.SHOPPING_ONLY):
			ids.append(id)
	_reconcile(_mem_r, ids)
	for i in COLS * ROWS:
		var cid := String(_mem_r[i])
		if cid == "":
			_slot(_right, 1, i, "", 0, "", Callable())
		else:
			var storable := Game.shelter_resource(cid) != ""
			_slot(_right, 1, i, cid, VeilInventoryPanel.quantity(cid), String(Game.item_info(cid).get("name", cid)) + ("" if storable else " - not for the stores"), func(all: bool): _put(cid, all))
	var text := ""
	if world.expedition and world.expedition.shelter() != "":
		var need: Dictionary = world.expedition.supply_need()
		text = "Tonight: %d food, %d water needed.  Stored: food %d, water %d, medicine %d." % [need["need"], need["need"], need["food"], need["water"], int(stock.get("medical", 0))]
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
