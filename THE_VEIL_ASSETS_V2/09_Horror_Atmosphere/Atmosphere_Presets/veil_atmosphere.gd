## THE VEIL - minimal environment-state switcher (presentation only; no story, AI, quests or controls).
##
##   $VeilAtmosphere.set_state(VeilAtmosphere.State.VEIL_ACTIVE)       # tweened over transition_time
##   $VeilAtmosphere.apply_preset(load(".../LGT_Empty_Supermarket.tres"), true)   # any lighting preset, instant
##
## It drives: the WorldEnvironment (sky, ambient, fog), the DirectionalLight3D, the VeilMist node, lamps in
## group "veil_streetlight" (Light3D energy) and "veil_flicker" (VeilFlicker amount), set dressing in group
## "veil_corruption" (visible when its meta "veil_level" <= preset.corruption_level), and particle effects in
## groups "veil_rain" / "veil_dust" / "veil_leaves".
class_name VeilAtmosphere
extends Node

enum State { NORMAL, UNEASY, VEIL_APPROACHING, VEIL_ACTIVE, CORRUPTED }

@export var state: State = State.NORMAL
@export var states: Array = []                 # VeilAtmospherePreset per State (NORMAL..CORRUPTED)
## Existing lamps (e.g. the 23 "StreetLight_NN" OmniLights of the Pack 02 town scene) are found by name and get a
## VeilFlicker attached at runtime - the town scene itself is never modified.
@export var streetlight_name_prefix := "StreetLight_"
@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export var mist: Node3D
@export var transition_time := 6.0
## disable other WorldEnvironment / DirectionalLight3D nodes in the level (e.g. the Pack 02 town's own) so this rig is the only sky + sun
@export var take_over_environment := true

var current: VeilAtmospherePreset
var _tween: Tween
var _lamp_base := {}
var _instant := false

func _ready() -> void:
	if take_over_environment:
		_take_over(get_tree().root)
	if world_environment and world_environment.environment:
		world_environment.environment = world_environment.environment.duplicate(true)
	for l in get_tree().get_nodes_in_group("veil_streetlight"):
		if l is Light3D:
			_lamp_base[l] = l.light_energy
	if streetlight_name_prefix != "":
		var flicker_script := load("res://THE_VEIL_ASSETS_V2/09_Horror_Atmosphere/Lighting/veil_flicker.gd")
		var i := 0
		for l in _find_lights(get_tree().root):
			if not l.has_node("VeilFlicker"):
				var f: Node = flicker_script.new()
				f.name = "VeilFlicker"
				f.set("seed", 17 + i * 31)
				f.set("amount", 0.0)
				l.add_child(f)
			i += 1
	set_state(state, true)

func _find_lights(n: Node) -> Array:
	var out := []
	if n is Light3D and String(n.name).begins_with(streetlight_name_prefix):
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_lights(c))
	return out

func set_state(s: State, instant := false) -> void:
	state = s
	if s < states.size() and states[s]:
		apply_preset(states[s], instant)

func apply_preset(p: VeilAtmospherePreset, instant := false) -> void:
	current = p
	if _tween:
		_tween.kill()
	_tween = null
	_instant = instant or transition_time <= 0.0 or not is_inside_tree()
	var env := world_environment.environment if world_environment else null
	if env:
		env.background_mode = Environment.BG_SKY if p.background_is_sky else Environment.BG_COLOR
		env.background_color = p.background_color
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_go(env, "ambient_light_color", p.ambient_color)
		_go(env, "ambient_light_energy", p.ambient_energy)
		env.fog_enabled = p.fog_enabled
		_go(env, "fog_light_color", p.fog_color)
		_go(env, "fog_density", p.fog_density)
		_go(env, "fog_height", p.fog_height)
		_go(env, "fog_height_density", p.fog_height_density)
		env.fog_sky_affect = p.fog_sky_affect
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky: ProceduralSkyMaterial = env.sky.sky_material
			_go(sky, "sky_top_color", p.sky_top)
			_go(sky, "sky_horizon_color", p.sky_horizon)
			_go(sky, "ground_horizon_color", p.ground_horizon)
			_go(sky, "ground_bottom_color", p.ground_bottom)
	if sun:
		_go(sun, "light_color", p.sun_color)
		_go(sun, "light_energy", p.sun_energy)
		_go(sun, "rotation_degrees", Vector3(p.sun_pitch, p.sun_yaw, 0.0))
		sun.shadow_enabled = p.sun_shadows
		sun.directional_shadow_max_distance = p.shadow_distance
	if mist and mist.has_method("set_density"):
		mist.visible = p.mist_enabled
		_go(mist, "density", p.mist_density if p.mist_enabled else 0.0)
		_go(mist, "color", p.mist_color)
		_go(mist, "height", p.mist_height)
		mist.speed = p.mist_speed
		mist.cards = p.mist_cards
	for l in _lamp_base:
		if is_instance_valid(l):
			_go(l, "light_energy", _lamp_base[l] * p.streetlight_energy)
	for f in get_tree().get_nodes_in_group("veil_flicker"):
		if f.has_method("set_flicker_amount"):
			f.set_flicker_amount(p.flicker_amount)
			f.set_energy_scale(p.streetlight_energy)
	for n in get_tree().get_nodes_in_group("veil_corruption"):
		if n is Node3D:
			n.visible = int(n.get_meta("veil_level", 1)) <= p.corruption_level
	for g in [["veil_rain", p.rain], ["veil_dust", p.dust], ["veil_leaves", p.leaves]]:
		for e in get_tree().get_nodes_in_group(g[0]):
			if e is CPUParticles3D:
				e.emitting = g[1]
			if e is Node3D:
				e.visible = g[1]

## instant: assign now; otherwise tween over transition_time (one parallel tween per state change)
func _go(obj: Object, prop: String, value) -> void:
	if _instant:
		obj.set(prop, value)
		return
	if _tween == null:
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(obj, prop, value, transition_time)

func _take_over(n: Node) -> void:
	if n is WorldEnvironment and n != world_environment:
		n.environment = null
	elif n is DirectionalLight3D and n != sun:
		n.visible = false
	for c in n.get_children():
		_take_over(c)
