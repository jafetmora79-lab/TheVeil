extends Node3D
class_name VeilRadio
## THE VEIL - reusable tabletop radio (Pack 03 RES_Radio: display + power-LED nodes). Interacted with in place.
##   var r := VeilRadio.new(); parent.add_child(r); r.setup(static_stream); r.used.connect(...)
##   await r.play_broadcast("dialogue_id")   # LED on, display flickers, static, the lines, then quiet again
## Any approved broadcast is just another dialogue id: the model and behaviour never change.

signal used(by: Node)

const MODEL := preload("res://THE_VEIL_ASSETS_V2/03_Residential/Furniture/RES_Radio.glb")

var interactable: Interactable
var hiss: AudioStreamPlayer3D           ## quiet static while it sits there untuned
var on := false
var broadcasts := 0
var _display: GeometryInstance3D
var _led: GeometryInstance3D
var _m_display: StandardMaterial3D
var _m_led: StandardMaterial3D
var _t := 0.0


func setup(static_stream: AudioStream, prompt := "") -> void:
	var m := MODEL.instantiate() as Node3D
	m.name = "Model"
	add_child(m)
	_display = _geo(m.find_child("Radio_Display", true, false))
	_led = _geo(m.find_child("Radio_LED", true, false))
	_m_display = StandardMaterial3D.new()
	_m_display.albedo_color = Color(0.08, 0.1, 0.07)
	_m_display.emission_enabled = true
	_m_display.emission = Color(0.55, 0.85, 0.45)
	_m_display.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_m_led = StandardMaterial3D.new()
	_m_led.albedo_color = Color(0.15, 0.03, 0.02)
	_m_led.emission_enabled = true
	_m_led.emission = Color(1.0, 0.25, 0.12)
	for g in [[_display, _m_display], [_led, _m_led]]:
		if g[0]:
			(g[0] as GeometryInstance3D).material_override = g[1]
	_set_lit(false)
	interactable = Interactable.attach(m, {"kind": "custom", "label": "Radio", "prompt_text": prompt})
	interactable.used.connect(func(b): used.emit(b))
	hiss = AudioStreamPlayer3D.new()
	hiss.name = "Static"
	hiss.stream = static_stream
	hiss.volume_db = -16.0
	hiss.unit_size = 3.0
	hiss.max_distance = 22.0
	add_child(hiss)


func _geo(n: Node) -> GeometryInstance3D:
	if n is GeometryInstance3D:
		return n
	if n:
		for c in n.find_children("*", "GeometryInstance3D", true, false):
			return c
	return null


func _set_lit(v: bool) -> void:
	on = v
	if _m_led:
		_m_led.emission_energy_multiplier = 2.2 if v else 0.0
	if _m_display:
		_m_display.emission_energy_multiplier = 1.0 if v else 0.0


func _process(delta: float) -> void:
	if on and _m_display:
		_t += delta
		# a subtle, uneven flicker of the frequency display while it plays
		_m_display.emission_energy_multiplier = 0.85 + 0.15 * sin(_t * 23.0) * sin(_t * 7.3) + (0.25 if fmod(_t, 1.7) < 0.06 else 0.0)


## Plays an approved broadcast (a dialogue id; "[STATIC]" lines are static bursts) and returns when it is over.
func play_broadcast(id: String) -> void:
	broadcasts += 1
	hiss.stop()
	_set_lit(true)
	Dialogue.say(id, false, true)
	await get_tree().process_frame
	while Dialogue.is_busy():
		await get_tree().process_frame
	_set_lit(false)                       # quiet again: no hiss, no light


func idle_hiss(v: bool) -> void:
	if v and not hiss.playing:
		hiss.play()
	elif not v and hiss.playing:
		hiss.stop()
