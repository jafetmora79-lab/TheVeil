extends Node3D
class_name VeilTentacleBeast
## THE VEIL - the Meshy tentacle beast with its shader walk (enemies/tentacle_beast_walk.gdshader).
## Loads the GLB, swaps its material for the walk shader (keeping the texture) and scales it. No skeleton.
##   var b := VeilTentacleBeast.new(); b.height = 9.0; add_child(b)      # about 9 m tall in the world
## `anim_time` >= 0 freezes the animation at that time (previews, tests).

const MODEL := "res://THE_VEIL_ASSETS_V2/07_Creatures/Tentacle_Beast/Tentacle_Beast.glb"
const SHADER := preload("res://game/enemies/tentacle_beast_walk.gdshader")
const MODEL_HEIGHT := 0.78            ## the mesh's own height (y -0.39 .. 0.39)

@export var height := 6.0
@export var walk_speed := 1.1
@export var anim_time := -1.0 : set = _set_anim_time

var material: ShaderMaterial
var meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	var ps := load(MODEL) as PackedScene
	if ps == null:
		push_warning("VeilTentacleBeast: model missing")
		return
	var m := ps.instantiate() as Node3D
	m.name = "Model"
	add_child(m)
	m.scale = Vector3.ONE * (height / MODEL_HEIGHT)
	m.position.y = height * 0.5                    # feet on the origin
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("walk_speed", walk_speed)
	material.set_shader_parameter("anim_time", anim_time)
	var tex_set := false
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		if not tex_set:
			for i in mesh.get_surface_count():
				var base := mesh.surface_get_material(i) as BaseMaterial3D
				if base and base.albedo_texture:
					material.set_shader_parameter("albedo_tex", base.albedo_texture)
					tex_set = true
					break
		(mi as MeshInstance3D).material_override = material
		(mi as MeshInstance3D).extra_cull_margin = 2.0     # (the shader moves vertices: keep it from culling early)
		meshes.append(mi)


func _set_anim_time(v: float) -> void:
	anim_time = v
	if material:
		material.set_shader_parameter("anim_time", v)
