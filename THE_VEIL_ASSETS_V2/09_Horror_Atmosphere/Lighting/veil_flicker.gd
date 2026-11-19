## THE VEIL - flicker for any Light3D (child of the light, or point `light` at it).
## Modes: STEADY, STREETLIGHT (sputters and drops out), FLUORESCENT (fast buzz, occasional strobe),
## DYING (dim, long outages), COLD_PULSE (slow breathing). `amount` 0..1 scales how unstable it is; the
## atmosphere system sets it on every node in the "veil_flicker" group. Optional emissive mesh follows the light.
extends Node

enum Mode { STEADY, STREETLIGHT, FLUORESCENT, DYING, COLD_PULSE }

@export var mode: Mode = Mode.STREETLIGHT
@export_range(0.0, 1.0) var amount := 1.0
@export var light: Light3D
@export var emissive_mesh: GeometryInstance3D
@export var seed := 1
@export var energy_scale := 1.0

var _rng := RandomNumberGenerator.new()
var _base := 1.0
var _t := 0.0
var _out := 0.0
var _mat: StandardMaterial3D
var _mat_base := 1.0

func _ready() -> void:
	add_to_group("veil_flicker")
	if light == null and get_parent() is Light3D:
		light = get_parent()
	if light:
		_base = light.light_energy
	_rng.seed = seed
	if emissive_mesh and emissive_mesh.material_override is StandardMaterial3D:
		_mat = emissive_mesh.material_override.duplicate()
		emissive_mesh.material_override = _mat
		_mat_base = _mat.emission_energy_multiplier

func set_flicker_amount(a: float) -> void:
	amount = clampf(a, 0.0, 1.0)

func set_energy_scale(s: float) -> void:
	energy_scale = s

func _process(delta: float) -> void:
	if light == null:
		return
	_t += delta
	var f := 1.0
	match mode:
		Mode.STREETLIGHT:
			if _out > 0.0:
				_out -= delta
				f = 0.08
			elif _rng.randf() < 0.012 * amount:
				_out = _rng.randf_range(0.05, 0.6) * amount
			else:
				f = 1.0 - amount * 0.12 * absf(sin(_t * 23.0) * sin(_t * 7.3))
		Mode.FLUORESCENT:
			f = 1.0 - amount * 0.18 * float(_rng.randf() < 0.35)
			if _rng.randf() < 0.004 * amount:
				_out = 0.12
			if _out > 0.0:
				_out -= delta
				f = 0.25 if int(_t * 30.0) % 2 == 0 else 1.0
		Mode.DYING:
			if _out > 0.0:
				_out -= delta
				f = 0.0
			elif _rng.randf() < 0.02 * amount:
				_out = _rng.randf_range(0.3, 2.0) * amount
			else:
				f = 0.55 + 0.1 * sin(_t * 3.0)
		Mode.COLD_PULSE:
			f = 0.75 + 0.25 * sin(_t * 1.1) * amount
		_:
			f = 1.0
	light.light_energy = _base * energy_scale * f
	if _mat:
		_mat.emission_energy_multiplier = _mat_base * energy_scale * f
