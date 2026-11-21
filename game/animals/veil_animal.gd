extends Node3D
class_name VeilAnimal
## THE VEIL - the woodland animals (Meshy models in game/prototypes/animals/): a deer, a rabbit, a raven.
## The deer and the rabbit play the clips that came with their models (idle / walk / run, the deer's leap); the raven came without any clip, so its flight is
## posed here: the wings beat from the shoulders (down-stroke fast, up-stroke slow), the legs tuck, the body rocks and banks into the turn.
##   var a := VeilAnimal.spawn(parent, "deer", position, yaw)
##   a.walk_to(p) / a.run_to(p) / a.idle()          (deer, rabbit)
##   a.fly_circle(centre, radius, height, speed)    (raven)
## Models face +Z. Feet are kept on the ground by measuring the lowest toe every frame (the clips move their root).
## The sizes are estimates (the models are normalised): a deer ~1.1 m at the shoulder, a rabbit ~0.45 m long, a raven ~0.45 m long.

signal arrived

const DEFS := {
	"deer": {"glb": "res://game/prototypes/animals/ANI_deer.glb", "scale": 2.0,
		"clips": {"idle": "fawn_idle04", "walk": "deer_walk", "run": "fawn_run01", "leap": "fawn_run02"},
		"speed": {"walk": 1.5, "run": 9.0}, "toes": ["frontToe.L", "frontToe.R", "rearToe.L", "rearToe.R"]},
	"rabbit": {"glb": "res://game/prototypes/animals/ANI_rabbit.glb", "scale": 0.62,
		"clips": {"idle": "rabbit_ANIM_Rabbit_IdleAlertBreathe", "walk": "rabbit_ANIM_Rabbit_Walk", "run": "rabbit_ANIM_Rabbit_Gallop"},
		"speed": {"walk": 0.7, "run": 5.0}, "toes": ["frontToe.L", "frontToe.R", "rearToe.L", "rearToe.R"]},
	"raven": {"glb": "res://game/prototypes/animals/ANI_raven.glb", "scale": 0.2, "clips": {}, "speed": {}, "toes": []},
}
const RAVEN_WING_BONES := {"Bone_017": 1.0, "Bone_019": -1.0, "Bone_026": 1.0, "Bone_024": -1.0}      # shoulder bones: right (+x), left (-x); the second pair are the inner feathers
const RAVEN_LEG_BONES := ["Bone_011", "Bone_015"]

var kind := ""
var model: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var def: Dictionary = {}
var state := "idle"                       ## idle / walk / run / leap / fly
var threat := Vector3.INF                 ## where the thing it fears is (set by whoever manages it)
var shy_distance := 0.0                   ## runs when the threat is nearer than this
var _clip := ""
var _target := Vector3.INF
var _speed_key := "walk"
var _ground_k := 0.0
var _toes: Array = []
var _yaw := 0.0
var _hold := false                        ## keep the model's own height (the leap)
# raven
var _centre := Vector3.ZERO
var _radius := 20.0
var _height := 20.0
var _fly_speed := 8.0
var _ang := 0.0
var _t := 0.0
var _rest_g: Array = []
var _bone_of := {}


static func spawn(parent: Node, which: String, at: Vector3, yaw := 0.0) -> VeilAnimal:
	var a := VeilAnimal.new()
	a.name = "Animal_" + which
	a.kind = which
	parent.add_child(a)
	a.global_position = at
	a._yaw = yaw
	a.rotation.y = yaw
	a._build()
	return a


func _build() -> void:
	def = DEFS[kind]
	var ps := load(def["glb"]) as PackedScene
	model = ps.instantiate() as Node3D
	VeilSarahMeshyProto.psx_look(model)
	model.scale = Vector3.ONE * float(def["scale"])
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		ap = aps[0] as AnimationPlayer
		var own := AnimationLibrary.new()                  # (a library of its own: the imported one is shared by every copy of the model)
		for c in ap.get_animation_list():
			var an := ap.get_animation(c).duplicate() as Animation
			an.loop_mode = Animation.LOOP_LINEAR
			own.add_animation(c, an)
		for ln in ap.get_animation_library_list():
			ap.remove_animation_library(ln)
		ap.add_animation_library("", own)
		ap.stop()
	for tn in def["toes"]:
		var i := skel.find_bone(tn)
		if i >= 0:
			_toes.append(i)
	if kind == "raven":
		for i in skel.get_bone_count():
			_rest_g.append(skel.get_bone_global_rest(i).basis)
			_bone_of[skel.get_bone_name(i)] = i
		model.position.y = 0.0
	else:
		idle()


func clip_name(short: String) -> String:
	return String(def["clips"].get(short, ""))


func _play(short: String, speed := 1.0) -> void:
	var c := clip_name(short)
	if c == "" or ap == null or not ap.has_animation(c):
		return
	if c != _clip:
		_clip = c
		ap.play(c, 0.15)
	ap.speed_scale = speed


func idle() -> void:
	state = "idle"
	_target = Vector3.INF
	_play("idle")


func walk_to(p: Vector3) -> void:
	state = "walk"
	_target = p
	_speed_key = "walk"
	_play("walk")


func run_to(p: Vector3) -> void:
	state = "run"
	_target = p
	_speed_key = "run"
	_play("run")


## The deer's leap (its own clip): `run_to` with the leap clip, for the jump over the road.
func leap_to(p: Vector3) -> void:
	state = "leap"
	_target = p
	_speed_key = "run"
	_play("leap")


func fly_circle(centre: Vector3, radius: float, height: float, speed: float) -> void:
	state = "fly"
	_centre = centre
	_radius = radius
	_height = height
	_fly_speed = speed
	_ang = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	if kind == "raven":
		_fly(delta)
		return
	if state == "idle" and threat.is_finite() and shy_distance > 0.0 and global_position.distance_to(threat) < shy_distance:
		var away := (global_position - threat) * Vector3(1, 0, 1)
		run_to(global_position + away.normalized() * 40.0)
	if _target.is_finite() and state in ["walk", "run", "leap"]:
		var to := (_target - global_position) * Vector3(1, 0, 1)
		var d := to.length()
		if d < 0.4:
			idle()
			arrived.emit()
			return
		var want := atan2(to.x, to.z)
		_yaw = lerp_angle(_yaw, want, clampf(delta * (9.0 if state != "walk" else 4.0), 0.0, 1.0))
		rotation.y = _yaw
		var v: float = float(def["speed"][_speed_key]) if def["speed"].has(_speed_key) else 1.0
		global_position += Vector3(sin(_yaw), 0, cos(_yaw)) * minf(v * delta, d)
		_follow_ground(delta)
	else:
		_follow_ground(delta)
	_feet(delta)


func _follow_ground(_delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 3.0, global_position - Vector3.UP * 4.0, 1)
	var h := space.intersect_ray(q)
	if not h.is_empty():
		global_position.y = (h["position"] as Vector3).y


## The lowest toe (model space, this frame) sits on the ground.
func _feet(delta: float) -> void:
	if _toes.is_empty() or _hold or state == "leap":
		return
	var low := 1e9
	for i in _toes:
		low = minf(low, skel.get_bone_global_pose(i).origin.y)
	_ground_k = lerpf(_ground_k, -low * float(def["scale"]), clampf(delta * 12.0, 0.0, 1.0))
	model.position.y = _ground_k


# ------------------------------------------------------------------ the raven's flight
func _fly(delta: float) -> void:
	var w := _fly_speed / maxf(_radius, 1.0)
	_ang += w * delta
	var p := _centre + Vector3(cos(_ang) * _radius, _height + sin(_ang * 0.7 + 1.0) * 2.5, sin(_ang) * _radius)
	var vel := (p - global_position)
	if vel.length() > 0.001 and global_position != Vector3.ZERO:
		var dir := vel.normalized()
		global_basis = Basis.looking_at(-dir, Vector3.UP)                  # (the model faces +Z)
		var bank := clampf(w * 2.2, 0.0, 0.5) * 1.0
		global_basis = global_basis * Basis(Vector3.BACK, -bank)             # leans into the circle
	global_position = p
	_flap()


func _bone_rot(name: String, r: Basis) -> void:
	var i: int = _bone_of.get(name, -1)
	if i < 0:
		return
	var par := skel.get_bone_parent(i)
	var pg: Basis = _rest_g[par] if par >= 0 else Basis.IDENTITY
	var local := pg.inverse() * (r * (_rest_g[i] as Basis))
	skel.set_bone_pose_rotation(i, local.get_rotation_quaternion())


func _flap() -> void:
	var f := 6.2                                                         # beats per second (a crow: about 3-4; slightly slow-motion for the camera)
	var ph := _t * f * TAU * 0.5
	var s := sin(ph)
	var shape := s * (1.0 if s > 0.0 else 0.8)
	var glide := 0.5 + 0.5 * sin(_t * 0.45)                               # now and then it stops beating and glides
	var amp := lerpf(0.95, 0.12, smoothstep(0.82, 1.0, glide))
	var base := deg_to_rad(82.0)
	for bn in RAVEN_WING_BONES:
		var side: float = RAVEN_WING_BONES[bn]
		var inner: bool = bn in ["Bone_026", "Bone_024"]
		var ang := base + shape * amp * deg_to_rad(52.0 if not inner else 38.0)
		_bone_rot(bn, Basis(Vector3.BACK, ang * side))
	for lg in RAVEN_LEG_BONES:
		_bone_rot(lg, Basis(Vector3.RIGHT, deg_to_rad(72.0)))
	model.position.y = sin(ph - 0.6) * 0.04 * float(def["scale"]) * 5.0
