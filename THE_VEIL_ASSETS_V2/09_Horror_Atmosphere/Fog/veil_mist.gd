## THE VEIL - layered supernatural mist that follows the active camera (horizontal position only).
## Stacked unshaded sheets (veil_mist_layer.gdshader) give depth and slow crawling movement; a capped
## CPUParticles3D set of camera-facing fog cards adds drifting volume at mid distance. Works in the
## Compatibility renderer; cost = a few transparent sheets + <= 32 cards.
extends Node3D

@export_range(0.0, 1.0) var density := 0.6: set = set_density
@export var color := Color(0.62, 0.66, 0.64): set = set_color
@export var height := 1.4: set = set_height
@export var speed := 1.0: set = set_speed
@export var cards := 16: set = set_cards
@export var follow_camera := true

const LAYER_HEIGHTS := [0.25, 0.55, 1.0]     # relative to `height`
const LAYER_DENSITY := [1.0, 0.7, 0.45]

func _ready() -> void:
	_apply()

func _process(_d: float) -> void:
	if follow_camera:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var p := cam.global_position
			global_position = Vector3(p.x, global_position.y, p.z)

func set_density(v: float) -> void:
	density = v
	_apply()

func set_color(v: Color) -> void:
	color = v
	_apply()

func set_height(v: float) -> void:
	height = v
	_apply()

func set_speed(v: float) -> void:
	speed = v
	_apply()

func set_cards(v: int) -> void:
	cards = v
	_apply()

func _apply() -> void:
	if not is_inside_tree():
		return
	var i := 0
	for layer in $Layers.get_children():
		if layer is MeshInstance3D and layer.material_override is ShaderMaterial:
			var m: ShaderMaterial = layer.material_override
			m.set_shader_parameter("density", density * LAYER_DENSITY[min(i, 2)])
			m.set_shader_parameter("mist_color", color)
			m.set_shader_parameter("drift", Vector2(0.012, 0.007) * speed * (1.0 + 0.4 * i))
			layer.position.y = height * LAYER_HEIGHTS[min(i, 2)]
			layer.visible = density > 0.01
			i += 1
	var c: CPUParticles3D = $FogCards
	c.emitting = cards > 0 and density > 0.05
	if cards > 0:
		c.amount = clampi(cards, 1, 32)
	c.position.y = height * 0.6
	if c.mesh and c.mesh.material is StandardMaterial3D:
		var cm: StandardMaterial3D = c.mesh.material
		cm.albedo_color = Color(color.r, color.g, color.b, clampf(density * 0.55, 0.0, 0.6))
