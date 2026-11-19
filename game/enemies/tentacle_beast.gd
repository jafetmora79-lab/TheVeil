extends Node3D
class_name VeilTentacleBeast
## THE VEIL - the Meshy tentacle beast with its shader walk (enemies/tentacle_beast_walk.gdshaderinc). No skeleton: the
## walk is a vertex shader, and this node mirrors the shader's leg maths so the game can ask where a foot is.
##   var b := VeilTentacleBeast.new(); b.height = 60.0; add_child(b)        # about 60 m tall
## `veil` = the Colossus encounter's dark mist look (tentacle_beast_veil.gdshader) instead of the plain lit preview.
## The animation clock is `anim_time` (seconds). `speed_scale` > 0 advances it by itself; `seek(t)` sets it.
## One cycle lasts 1 / walk_speed; each leg plants once per cycle, the diagonal pairs half a cycle apart.

const MODEL := "res://THE_VEIL_ASSETS_V2/07_Creatures/Tentacle_Beast/Tentacle_Beast.glb"
const SHADER_PLAIN := preload("res://game/enemies/tentacle_beast_walk.gdshader")
const SHADER_VEIL := preload("res://game/enemies/tentacle_beast_veil.gdshader")
const MODEL_HEIGHT := 0.78            ## the mesh's own height (y -0.39 .. 0.39)

# the shader's leg constants (tentacle_beast_walk.gdshaderinc) and the feet's rest tips, in model space
const HIP := Vector3(0.25, 0.04, 0.18)
const KNEE := Vector3(0.27, -0.17, 0.33)
const LEG_LEN := 0.42
const LOWER_LEN := 0.21
const FOOT_REST := {                       # key: (side, front/back) -> toe tip at rest
	"1,1": Vector3(0.34, -0.39, 0.40), "-1,1": Vector3(-0.35, -0.39, 0.39),
	"1,-1": Vector3(0.29, -0.39, -0.37), "-1,-1": Vector3(-0.25, -0.39, -0.36)}
const TOES := [Vector3(0, 0, 0), Vector3(0.05, 0, 0.04), Vector3(-0.05, 0, 0.04)]

@export var height := 6.0
@export var walk_speed := 0.5                 ## step cycles per second
@export var step_swing := 0.065              ## model units the foot moves forward / back
@export var knee_fold := 0.7
@export var veil := false
@export var veil_ground := 0.0               ## veil look: world y of the road
@export var anim_time := -1.0 : set = _set_anim_time
var speed_scale := 0.0                       ## > 0: the clock runs by itself (1 = real time)

var material: ShaderMaterial
var meshes: Array[MeshInstance3D] = []
var model: Node3D
var _blockers: Array[CollisionShape3D] = []
var blocker_body: StaticBody3D


func _ready() -> void:
	var ps := load(MODEL) as PackedScene
	if ps == null:
		push_warning("VeilTentacleBeast: model missing")
		return
	model = ps.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	model.scale = Vector3.ONE * (height / MODEL_HEIGHT)
	model.position.y = height * 0.5                    # feet on the origin
	material = ShaderMaterial.new()
	material.shader = SHADER_VEIL if veil else SHADER_PLAIN
	material.set_shader_parameter("walk_speed", walk_speed)
	material.set_shader_parameter("step_swing", step_swing)
	material.set_shader_parameter("knee_fold", knee_fold)
	material.set_shader_parameter("anim_time", maxf(anim_time, 0.0) if veil else anim_time)
	if veil:
		material.set_shader_parameter("ground_y", veil_ground)
	var tex_set := false
	for mi in model.find_children("*", "MeshInstance3D", true, false):
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
		(mi as MeshInstance3D).extra_cull_margin = 2.0 * height / 6.0     # (the shader moves vertices)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if veil else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		meshes.append(mi)


func _process(delta: float) -> void:
	if speed_scale != 0.0:
		seek(maxf(anim_time, 0.0) + delta * speed_scale)
	if blocker_body != null:
		_update_blockers()


func seek(t: float) -> void:
	anim_time = t


func _set_anim_time(v: float) -> void:
	anim_time = v
	if material:
		material.set_shader_parameter("anim_time", maxf(v, 0.0) if veil else v)


## The speed (m/s) the whole creature must travel at for its planted feet not to slide (at speed_scale 1).
func ground_speed() -> float:
	return 4.0 * step_swing * walk_speed * height / MODEL_HEIGHT


func cycle_length() -> float:
	return 1.0 / walk_speed


# ---------------------------------------------------------------- feet (the shader's leg maths, on the CPU)
func _phase_offset(side: float, fb: float) -> float:
	return 0.0 if side * fb > 0.0 else 0.5


## Model-space position of a point `rest` of the leg (side +-1, fb +-1: front / back) at animation time t.
func leg_point_local(side: float, fb: float, rest: Vector3, t: float) -> Vector3:
	var u := fposmod(t * walk_speed + _phase_offset(side, fb), 1.0)
	var foot_z := 0.0
	var lift := 0.0
	if u < 0.5:
		foot_z = step_swing * (1.0 - 4.0 * u)
	else:
		var s := (u - 0.5) * 2.0
		foot_z = step_swing * (-1.0 + 2.0 * smoothstep(0.0, 1.0, s))
		lift = sin(PI * s)
	var beta := knee_fold * lift
	var alpha := -(foot_z + LOWER_LEN * sin(beta)) / LEG_LEN
	var kp := Vector3(KNEE.x * side, KNEE.y, KNEE.z * fb)
	var hp := Vector3(HIP.x * side, HIP.y, HIP.z * fb)
	var p := Basis(Vector3.RIGHT, beta) * (rest - kp) + kp
	p = Basis(Vector3.RIGHT, alpha) * (p - hp) + hp
	return p


## World position of a leg's toe tip(s) at time t, using this node's current transform.
func toes_world(side: float, fb: float, t: float) -> Array:
	var base: Vector3 = FOOT_REST["%d,%d" % [int(side), int(fb)]]
	var out: Array = []
	for off in TOES:
		var local := leg_point_local(side, fb, base + Vector3(off.x * side, 0, off.z * fb), t)
		out.append(model.global_transform * local)
	return out


func tips_world(side := 1.0, fb := 1.0) -> Array:
	return toes_world(side, fb, maxf(anim_time, 0.0))


func min_tip_y(side := 1.0, fb := 1.0) -> float:
	var y := INF
	for p in tips_world(side, fb):
		y = minf(y, (p as Vector3).y)
	return y


## The time at which a leg touches down (the end of its swing) for the `k`-th time (k >= 1).
func touchdown_time(side: float, fb: float, k: int) -> float:
	return (float(k) - _phase_offset(side, fb)) / walk_speed


## The torso's centre in the world (for "the body is up in the mist").
func body_world() -> Vector3:
	return model.global_transform * Vector3(0, 0.1, 0)


# ---------------------------------------------------------------- solid legs
## Four invisible solid columns that follow the feet (xz), so nobody walks through a leg in the street.
func attach_blockers(radius := 2.4, tall := 20.0) -> StaticBody3D:
	blocker_body = StaticBody3D.new()
	blocker_body.name = "LegBlockers"
	blocker_body.collision_layer = 1
	blocker_body.collision_mask = 0
	var root_node := get_parent()
	root_node.add_child(blocker_body)
	for i in 4:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = tall
		cs.shape = sh
		blocker_body.add_child(cs)
		_blockers.append(cs)
	_update_blockers()
	return blocker_body


func _update_blockers() -> void:
	var legs := [[1.0, 1.0], [-1.0, 1.0], [1.0, -1.0], [-1.0, -1.0]]
	for i in 4:
		var tips := tips_world(legs[i][0], legs[i][1])
		var p: Vector3 = tips[0]
		_blockers[i].global_position = Vector3(p.x, veil_ground + (_blockers[i].shape as CylinderShape3D).height * 0.5, p.z)
		_blockers[i].disabled = false


func _exit_tree() -> void:
	if blocker_body != null and is_instance_valid(blocker_body):
		blocker_body.queue_free()
