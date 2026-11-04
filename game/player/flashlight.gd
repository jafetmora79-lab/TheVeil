extends Node
class_name VeilFlashlight
## THE VEIL - hand flashlight with batteries (first survival tool; Phase 4).
## Attach to the player once the "flashlight" item is owned. F toggles, R swaps in a spare battery.
## State lives in Game.world_state["flashlight"] = {charge, spares, on}, so the existing save system keeps it.
## Tuning comes from game/data/phase4.json ("flashlight"): placeholder values, deliberately forgiving.

signal changed(charge: float, spares: int, on: bool)

const STATE_KEY := "flashlight"

var cfg := {"battery_seconds": 420.0, "start_charge": 1.0, "low_warning": 0.2, "flicker_below": 0.08,
	"range": 18.0, "angle_deg": 30.0, "energy": 2.4, "color": [1.0, 0.94, 0.82]}
var player: Node3D
var spot: SpotLight3D
var charge := 1.0
var spares := 0
var on := false
var _ui: CanvasLayer
var _bar: ColorRect
var _bar_bg: ColorRect
var _label: Label
var _flick_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p: Node3D, c: Dictionary) -> void:
	player = p
	for k in c:
		cfg[k] = c[k]
	for a in [["flashlight", KEY_F], ["reload", KEY_R]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
			var ev := InputEventKey.new()
			ev.physical_keycode = a[1]
			InputMap.action_add_event(a[0], ev)
	spot = SpotLight3D.new()
	spot.name = "FlashlightBeam"
	spot.spot_range = float(cfg["range"])
	spot.spot_angle = float(cfg["angle_deg"])
	spot.spot_attenuation = 0.9
	spot.spot_angle_attenuation = 1.6
	var col: Array = cfg["color"]
	spot.light_color = Color(col[0], col[1], col[2])
	spot.shadow_enabled = false
	spot.position = Vector3(0.18, -0.12, 0.0)
	spot.visible = false
	(p.get("camera") as Node3D).add_child(spot)
	_build_ui()
	var st: Dictionary = Game.world_state.get(STATE_KEY, {})
	charge = float(st.get("charge", cfg["start_charge"]))
	spares = int(st.get("spares", 0))
	set_on(bool(st.get("on", false)))


func add_spares(n: int) -> void:
	spares += n
	_store()


func set_on(v: bool) -> void:
	on = v and charge > 0.0
	spot.visible = on
	_store()


func reload() -> bool:
	if spares <= 0 or charge >= 0.999:
		return false
	spares -= 1
	charge = 1.0
	Sfx.play("pickup", player.global_position, -8.0, 0.8)
	_store()
	return true


func _store() -> void:
	Game.world_state[STATE_KEY] = {"charge": charge, "spares": spares, "on": on}
	_refresh_ui()
	changed.emit(charge, spares, on)


func _unhandled_input(e: InputEvent) -> void:
	if player == null or not player.visible or not player.get("controls_enabled"):
		return
	if e.is_action_pressed("flashlight"):
		set_on(not on)
		Sfx.play("pickup", player.global_position, -14.0, 2.2)
	elif e.is_action_pressed("reload"):
		reload()


func _process(delta: float) -> void:
	if player == null:
		return
	_ui.visible = player.visible and (on or charge < float(cfg["low_warning"]))
	if not on:
		return
	charge = maxf(charge - delta / maxf(float(cfg["battery_seconds"]), 1.0), 0.0)
	var e := float(cfg["energy"])
	if charge <= 0.0:
		set_on(false)
		return
	if charge < float(cfg["flicker_below"]):          # a dying battery sputters before it goes
		_flick_t -= delta
		if _flick_t <= 0.0:
			_flick_t = _rng.randf_range(0.04, 0.4)
			spot.light_energy = e * (_rng.randf_range(0.05, 0.6) if _rng.randf() < 0.5 else 1.0) * 0.6
	else:
		spot.light_energy = e * lerpf(0.55, 1.0, clampf(charge / 0.3, 0.0, 1.0))
	if Engine.get_process_frames() % 30 == 0:
		_store()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 9
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.06, 0.08, 0.1, 0.8)
	_bar_bg.size = Vector2(120, 10)
	_bar_bg.anchor_left = 1.0
	_bar_bg.anchor_right = 1.0
	_bar_bg.anchor_top = 1.0
	_bar_bg.anchor_bottom = 1.0
	_bar_bg.position = Vector2(-160, -84)
	root.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.size = Vector2(116, 6)
	_bar.position = Vector2(2, 2)
	_bar_bg.add_child(_bar)
	_label = VeilUI.label("", 14, VeilUI.MUTED)
	_label.position = Vector2(0, -22)
	_bar_bg.add_child(_label)
	_ui.visible = false


func _refresh_ui() -> void:
	if _bar == null:
		return
	_bar.size.x = 116.0 * clampf(charge, 0.0, 1.0)
	_bar.color = Color(0.85, 0.32, 0.25) if charge < float(cfg["low_warning"]) else Color(0.655, 0.831, 0.80)
	var t := "FLASHLIGHT %d%%  ·  spares %d" % [roundi(charge * 100.0), spares]
	if charge < float(cfg["low_warning"]) and spares > 0:
		t += "  ·  R to change"
	_label.text = t
