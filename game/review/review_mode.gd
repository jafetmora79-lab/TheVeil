class_name VeilReviewMode
extends CanvasLayer
## THE VEIL - REVIEW MODE ("sticky notes"). F2 turns it on and off while you play (in the exported exe too).
##   - aim the crosshair at a bug or a 3D asset that needs fixing, CLICK: a small note box opens (BUG / 3D ASSET / OTHER + a line of text);
##   - the note is saved with what you were pointing at (its node, scene / model file, mesh and material names), where you were, what you were looking at,
##     the chapter, the current objective and the story flags, plus a small screenshot;
##   - notes live in  user://veil_notes.json  (Windows: %APPDATA%\Godot\app_userdata\THE VEIL\veil_notes.json), screenshots in  user://review/ ;
##   - saved notes show in the world as numbered markers while review mode is on (yellow = open, green = fixed, grey = won't fix).
## Claude reads the file afterwards and fixes the notes one by one (game/tools/review_notes.py lists / marks them).
## Nothing here changes the game: no flags, no inventory. The game is paused for the note box only where pausing is allowed (not in cinematics).

const NOTES_PATH := "user://veil_notes.json"
const SHOT_DIR := "user://review"
var notes_path := NOTES_PATH            ## (the test points this somewhere else)
var shot_dir := SHOT_DIR
const MAX_RAY := 90.0
const TYPES := ["bug", "asset", "other"]
const TYPE_LABELS := {"bug": "BUG", "asset": "3D ASSET", "other": "OTHER"}

var active := false
var notes: Array = []
var world: Node
var _banner: Label
var _target: Label
var _ring: Control
var _panel: PanelContainer
var _info: Label
var _text: TextEdit
var _type_buttons: Dictionary = {}
var _type := "bug"
var _pending: Dictionary = {}
var _dialog_open := false
var _prev_mouse := Input.MOUSE_MODE_CAPTURED
var _prev_paused := false
var _prev_controls := true
var _held_player := false
var _markers: Node3D
var _look_t := 0.0
var _last_target := {}
var capture_screenshots := true          ## off in the headless test


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = get_parent()
	_load()
	_build_ui()
	_markers = Node3D.new()
	_markers.name = "ReviewMarkers"
	_markers.visible = false
	world.add_child.call_deferred(_markers)
	_set_active(false)


# ------------------------------------------------------------------ the notes file
func _load() -> void:
	notes = []
	if FileAccess.file_exists(notes_path):
		var f := FileAccess.open(notes_path, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary and d.get("notes") is Array:
			notes = d["notes"]


func _save() -> void:
	var f := FileAccess.open(notes_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"about": "THE VEIL review notes: read by Claude; fix one by one (game/tools/review_notes.py)", "notes": notes}, "  "))
	f.close()


func open_count() -> int:
	var n := 0
	for x in notes:
		if String(x.get("status", "open")) == "open":
			n += 1
	return n


# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	_banner = Label.new()
	_banner.position = Vector2(14, 10)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.add_theme_font_size_override("font_size", 18)
	add_child(_banner)
	_target = Label.new()
	_target.add_theme_color_override("font_color", Color(1, 1, 1))
	_target.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_target.add_theme_constant_override("outline_size", 6)
	_target.add_theme_font_size_override("font_size", 16)
	_target.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_target.position += Vector2(24, 18)
	add_child(_target)
	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(func():
		_ring.draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(1.0, 0.86, 0.3, 0.95), 2.0)
		_ring.draw_arc(Vector2.ZERO, 3.0, 0.0, TAU, 12, Color(1.0, 0.86, 0.3, 0.95), 2.0))
	add_child(_ring)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.position -= Vector2(280, 170)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.11, 0.13, 0.97)
	sb.border_color = Color(1.0, 0.86, 0.3)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var title := Label.new()
	title.text = "LEAVE A NOTE"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	v.add_child(title)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(520, 0)
	_info.add_theme_font_size_override("font_size", 14)
	v.add_child(_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for t in TYPES:
		var b := Button.new()
		b.text = TYPE_LABELS[t]
		b.toggle_mode = true
		b.pressed.connect(_pick_type.bind(t))
		row.add_child(b)
		_type_buttons[t] = b
	v.add_child(row)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(520, 110)
	_text.placeholder_text = "What is wrong, or what should it look like?"
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(_text)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	var save := Button.new()
	save.text = "SAVE NOTE"
	save.pressed.connect(_save_pending)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_close_dialog)
	row2.add_child(save)
	row2.add_child(cancel)
	v.add_child(row2)
	add_child(_panel)
	_pick_type("bug")


func _pick_type(t: String) -> void:
	_type = t
	for k in _type_buttons:
		(_type_buttons[k] as Button).button_pressed = (k == t)


func _refresh_banner() -> void:
	_banner.text = "REVIEW MODE   -   aim and CLICK to leave a note   -   F2 to leave   -   %d notes (%d open)" % [notes.size(), open_count()]


func _set_active(on: bool) -> void:
	active = on
	_banner.visible = on
	_target.visible = on
	_ring.visible = on
	if _markers:
		_markers.visible = on
	if on:
		_refresh_banner()
		_rebuild_markers()
	else:
		_close_dialog()


# ------------------------------------------------------------------ input
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F2:
		if world and world.get("hud") and world.hud.is_paused() and not active:
			return                                                     # (not over the pause menu)
		_set_active(not active)
		get_viewport().set_input_as_handled()
		return
	if not active or _dialog_open:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		get_viewport().set_input_as_handled()
		_start_note()


func _process(delta: float) -> void:
	if not active or _dialog_open:
		return
	_look_t -= delta
	if _look_t > 0.0:
		return
	_look_t = 0.15
	_last_target = point_at()
	var t := _last_target
	_target.text = "" if t.is_empty() else "%s   (%.1f m)" % [t.get("name", "?"), float(t.get("distance", 0.0))]


# ------------------------------------------------------------------ what is under the crosshair
## Ray from the middle of the screen: the first solid or area, plus the meshes that really contain the hit point (smallest first), with their model files.
func point_at(from: Vector3 = Vector3.INF, dir: Vector3 = Vector3.ZERO) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null and from == Vector3.INF:
		return {}
	var o: Vector3 = cam.global_position if from == Vector3.INF else from
	var d: Vector3 = (-cam.global_basis.z) if dir == Vector3.ZERO else dir.normalized()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(o, o + d * MAX_RAY)
	q.collide_with_areas = true
	if world.get("player"):
		q.exclude = [world.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	var out := {}
	var at: Vector3 = o + d * 6.0
	if not hit.is_empty():
		at = hit["position"]
		var c: Node = hit["collider"]
		out = _describe_node(c)
		out["hit_position"] = _v(at)
		out["hit_normal"] = _v(hit["normal"])
		out["distance"] = snappedf(o.distance_to(at), 0.01)
		out["kind"] = "collider"
	else:
		out = {"name": "(nothing solid - open air or a decoration)", "kind": "air", "distance": 6.0, "hit_position": _v(at)}
	out["candidates"] = _meshes_at(o, d, at, hit.is_empty())
	if hit.is_empty() and not out["candidates"].is_empty():
		var c0: Dictionary = out["candidates"][0]
		out["name"] = String(c0.get("name", "?"))
		out["distance"] = float(c0.get("distance", 0.0))
	return out


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


## A node described for the file: its path, its type, the instanced scene / model it comes from, the mesh and materials near it.
func _describe_node(n: Node) -> Dictionary:
	var d := {"name": String(n.name), "path": String(n.get_path()), "class": n.get_class()}
	var p: Node = n
	while p != null:
		if p.scene_file_path != "":
			d["scene"] = p.scene_file_path
			d["scene_node"] = String(p.name)
			break
		p = p.get_parent()
	var script: Script = n.get_script()
	if script:
		d["script"] = script.resource_path
	# a mesh belonging to it (the node's own, a child's, or a sibling's under the same parent)
	var mesh_owner: MeshInstance3D = null
	if n is MeshInstance3D:
		mesh_owner = n
	else:
		var kids := n.find_children("*", "MeshInstance3D", true, false)
		if kids.is_empty() and n.get_parent():
			kids = n.get_parent().find_children("*", "MeshInstance3D", false, false)
		if not kids.is_empty():
			mesh_owner = kids[0]
	if mesh_owner != null and mesh_owner.mesh != null:
		d["mesh_node"] = String(mesh_owner.name)
		d["mesh"] = mesh_owner.mesh.resource_path if mesh_owner.mesh.resource_path != "" else mesh_owner.mesh.resource_name
		var mats: Array = []
		for i in mesh_owner.mesh.get_surface_count():
			var m := mesh_owner.get_active_material(i)
			if m:
				var tex := ""
				if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture:
					tex = (m as BaseMaterial3D).albedo_texture.resource_path
				mats.append({"name": m.resource_name, "path": m.resource_path, "albedo": tex})
		d["materials"] = mats
	return d


## Every visible mesh whose box contains the point (a little slack), the smallest first: the most specific thing there.
func _meshes_at(o: Vector3, d: Vector3, at: Vector3, by_ray: bool) -> Array:
	var found: Array = []
	for mi in world.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		if m.get_parent() == _markers:
			continue
		var inv := m.global_transform.affine_inverse()
		var local_at := inv * at
		var box := m.get_aabb().grow(0.12)
		var hit_t := -1.0
		if box.has_point(local_at):
			hit_t = o.distance_to(at)
		elif by_ray:
			var r: Variant = box.intersects_ray(inv * o, inv.basis * d)
			if r != null:
				hit_t = o.distance_to(m.global_transform * (r as Vector3))
		if hit_t < 0.0 or hit_t > MAX_RAY:
			continue
		var vol := box.size.x * box.size.y * box.size.z * absf(m.global_basis.determinant())
		var info := _describe_node(m)
		info["distance"] = snappedf(hit_t, 0.01)
		info["volume"] = snappedf(vol, 0.001)
		found.append(info)
	found.sort_custom(func(a, b): return float(a["volume"]) < float(b["volume"]))
	return found.slice(0, 5)


# ------------------------------------------------------------------ taking a note
func _start_note() -> void:
	_pending = {}
	_pending["target"] = point_at()
	var cam := get_viewport().get_camera_3d()
	if cam:
		_pending["camera"] = {"position": _v(cam.global_position), "rotation_deg": _v(cam.global_rotation_degrees), "fov": cam.fov}
	if world.get("player"):
		_pending["player"] = {"position": _v(world.player.global_position)}
	if capture_screenshots:
		_banner.visible = false
		_target.visible = false
		_ring.visible = false
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		_banner.visible = true
		_target.visible = true
		_ring.visible = true
		if img != null:
			if img.get_width() > 960:
				img.resize(960, int(img.get_height() * 960.0 / img.get_width()), Image.INTERPOLATE_BILINEAR)
			_pending["_image"] = img
	_open_dialog()


func _open_dialog() -> void:
	_dialog_open = true
	_text.text = ""
	_pick_type("bug")
	var t: Dictionary = _pending.get("target", {})
	var what := "nothing in particular"
	if not t.is_empty():
		what = String(t.get("name", "?"))
		var cands: Array = t.get("candidates", [])
		if not cands.is_empty() and String(cands[0].get("scene", "")) != "":
			what += "   -   " + String(cands[0]["scene"]).get_file()
		elif String(t.get("scene", "")) != "":
			what += "   -   " + String(t["scene"]).get_file()
	_info.text = "Pointing at: " + what
	_panel.visible = true
	_target.visible = false
	_ring.visible = false
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# the game waits for the note box where pausing is allowed; a running cinematic is left alone (it would fall out of step)
	var hud = world.get("hud")
	_prev_paused = get_tree().paused
	if hud != null and hud.allow_pause and not _prev_paused:
		get_tree().paused = true
	_held_player = false
	if world.get("player") and world.player.controls_enabled:
		_prev_controls = true
		world.player.controls_enabled = false              # (typing must not walk the player about)
		_held_player = true
	_text.grab_focus()


func _close_dialog() -> void:
	if not _dialog_open:
		_panel.visible = false
		return
	_dialog_open = false
	_panel.visible = false
	_target.visible = active
	_ring.visible = active
	if get_tree().paused and not _prev_paused:
		get_tree().paused = false
	if _held_player and world.get("player"):
		world.player.controls_enabled = true
	_held_player = false
	Input.mouse_mode = _prev_mouse


func _save_pending() -> void:
	var note := add_note(_type, _text.text, _pending)
	_close_dialog()
	_pending = {}
	_refresh_banner()
	_add_marker(note)


## Writes a note (also used by the test). `data` is what _start_note collected.
func add_note(type: String, text: String, data: Dictionary = {}) -> Dictionary:
	var id := 1
	for n in notes:
		id = maxi(id, int(n.get("id", 0)) + 1)
	var note := {"id": id, "status": "open", "type": type, "text": text.strip_edges(), "created": Time.get_datetime_string_from_system(false, true),
		"engine": Engine.get_version_info().get("string", ""), "play_time_s": int(Game.play_time)}
	note["chapter"] = {"number": Game.chapter_number(), "name": Game.chapter_name(Game.chapter_number())}
	var step: Dictionary = Game.current_step()
	note["objective"] = {"id": String(step.get("id", "")), "text": String(step.get("text", ""))}
	var fl: Array = []
	for k in Game.flags:
		if Game.flags[k]:
			fl.append(String(k))
	fl.sort()
	note["flags"] = fl
	for k in ["target", "camera", "player"]:
		if data.has(k):
			note[k] = data[k]
	var img: Image = data.get("_image")
	if img != null:
		DirAccess.make_dir_recursive_absolute(shot_dir)
		var fn := "note_%03d.png" % id
		img.save_png(shot_dir + "/" + fn)
		note["screenshot"] = fn
	notes.append(note)
	_save()
	return note


# ------------------------------------------------------------------ markers in the world
func _rebuild_markers() -> void:
	if _markers == null or not is_instance_valid(_markers):
		return
	for c in _markers.get_children():
		c.queue_free()
	for n in notes:
		_add_marker(n)


func _add_marker(note: Dictionary) -> void:
	if _markers == null or not is_instance_valid(_markers) or not _markers.is_inside_tree():
		return
	var pos: Variant = null
	var t: Dictionary = note.get("target", {})
	if t.has("hit_position"):
		pos = t["hit_position"]
	elif note.has("camera"):
		pos = note["camera"]["position"]
	if pos == null:
		return
	var l := Label3D.new()
	var st := String(note.get("status", "open"))
	l.text = "#%d %s" % [int(note.get("id", 0)), String(note.get("type", "")).to_upper()]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.outline_size = 8
	l.modulate = {"open": Color(1.0, 0.86, 0.3), "fixed": Color(0.4, 1.0, 0.5), "wontfix": Color(0.65, 0.65, 0.65)}.get(st, Color(1, 1, 1))
	l.shaded = false
	_markers.add_child(l)
	l.global_position = Vector3(pos[0], pos[1], pos[2]) + Vector3(0, 0.25, 0)
