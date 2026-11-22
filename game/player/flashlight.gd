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
	add_to_group("veil_flashlight")                  # the inventory screen finds it for its item actions
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
	if true:                                            # (no batteries any more: review note #30)
		return false
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
	var sa := get_tree().get_first_node_in_group("veil_sidearm")
	if sa and sa.drawn():
		return                                          # the handgun is drawn: F fires and R reloads it instead
	if e.is_action_pressed("flashlight"):
		set_on(not on)
		Sfx.play("pickup", player.global_position, -14.0, 2.2)
	elif e.is_action_pressed("reload"):
		reload()


## The flashlight in the player's hand: raised into the lower right while it is on, gripped by a right hand (fingers
## round the barrel, thumb on the switch), trailing the view a little when you turn and rocking with the walk. The beam
## comes out of the lens, wherever the hand has it. Lowered away when switched off, while the handgun is drawn, or in a scene.
const FLASH_MODEL := "res://THE_VEIL_ASSETS_V2/08_Inventory/Story_Items/INV_Flashlight.glb"
const VIEW_REST := Vector3(0.15, -0.17, -0.34)
var _view: Node3D
var _lens: Node3D
var _up := 0.0
var _vtime := 0.0
var _lag := Vector2.ZERO
var _last_yaw := 0.0
var _last_pitch := 0.0


func _ensure_view() -> void:
	if _view and is_instance_valid(_view):
		return
	var ps := load(FLASH_MODEL) as PackedScene
	var cam := player.get("camera") as Camera3D
	if ps == null or cam == null:
		return
	_view = Node3D.new()
	_view.name = "FlashlightView"
	cam.add_child(_view)
	var body := Node3D.new()                              # origin on the barrel's axis
	body.position = Vector3(0, -0.031, 0)
	_view.add_child(body)
	var model := ps.instantiate()
	VeilViewHands.strip_physics(model)                    # the model's pickup collision body must not push the player
	body.add_child(model)
	for gi in body.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hands := VeilViewHands.new()
	hands.build_cylinder_grip(body)
	_lens = Node3D.new()
	_lens.position = Vector3(0, 0.031, -0.108)
	body.add_child(_lens)
	_view.visible = false


func _update_view(delta: float) -> void:
	var sa := get_tree().get_first_node_in_group("veil_sidearm")
	var show: bool = on and player.visible and bool(player.get("controls_enabled")) and not (sa and sa.drawn()) \
		and DisplayServer.get_name() != "headless"
	_up = move_toward(_up, 1.0 if show else 0.0, delta / 0.2)
	if _up <= 0.001:
		if _view and is_instance_valid(_view):
			_view.visible = false
		spot.position = Vector3(0.18, -0.12, 0.0)           # no hand in view: the beam from the shoulder, as before
		spot.rotation = Vector3.ZERO
		return
	_ensure_view()
	if _view == null:
		return
	_view.visible = true
	_vtime += delta
	var e := smoothstep(0.0, 1.0, _up)
	var pos := VIEW_REST + Vector3(0, -0.26, 0.05) * (1.0 - e)
	var v: Vector3 = player.get("velocity") * Vector3(1, 0, 1)
	var walk := clampf(v.length() / 4.0, 0.0, 1.0)
	pos += Vector3(sin(_vtime * 4.2) * 0.010 * walk, absf(sin(_vtime * 8.4)) * -0.009 * walk + sin(_vtime * 1.4) * 0.003, 0.0)
	var pitch := 0.10
	var run := clampf((v.length() - 3.4) / 0.9, 0.0, 1.0)
	pos += Vector3(0.0, -0.05, 0.04) * run                      # carried lower while running
	pitch -= 0.18 * run
	var yaw_now: float = player.rotation.y
	var pitch_now: float = float(player.get("_pitch"))
	_lag += Vector2(wrapf(yaw_now - _last_yaw, -PI, PI), pitch_now - _last_pitch) * 0.5
	_last_yaw = yaw_now
	_last_pitch = pitch_now
	_lag = _lag.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0)).clamp(Vector2(-0.2, -0.2), Vector2(0.2, 0.2))
	pos += Vector3(_lag.x * 0.2, -_lag.y * 0.13, 0.0)
	_view.position = pos
	_view.basis = Basis(Vector3.RIGHT, pitch + _lag.y * 0.5) * Basis(Vector3.UP, -0.05 + _lag.x * 0.7)
	if _lens:
		spot.global_transform = _lens.global_transform         # the beam leaves the lens


func _process(delta: float) -> void:
	if player == null:
		return
	_update_view(delta)
	_ui.visible = false                                 # no charge bar: the flashlight never runs out (review note #30)
	charge = 1.0
	if not on:
		return
	spot.light_energy = float(cfg["energy"])


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
