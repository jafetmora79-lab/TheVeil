extends Node3D
class_name VeilColossusLegBlockers
## THE VEIL - the Colossus's legs are solid where a person could reach them: a capsule along each shin (lower leg
## bone to foot bone) and one down the foot to the road, following the animation every physics frame. Only for
## while the creature stands in the street (freed with it). Nothing above ~14 m is given collision.

const LEGS := [["Leg_FL_Lower", "Leg_FL_Foot"], ["Leg_FR_Lower", "Leg_FR_Foot"], ["Leg_HL_Lower", "Leg_HL_Foot"],
	["Leg_HR_Lower", "Leg_HR_Foot"]]
const SHIN_R := 0.9
const FOOT_R := 1.3
const REACH := 14.0

var sk: Skeleton3D
var ground_y := 0.0
var _parts: Array = []                 ## [lower bone, foot bone, shin body, shin shape, foot body, foot shape]


static func attach(creature: Node3D, skeleton: Skeleton3D, ground: float) -> Node3D:
	var b = (load("res://game/enemies/colossus_leg_blockers.gd") as GDScript).new()
	b.name = "LegBlockers"
	b.sk = skeleton
	b.ground_y = ground
	creature.add_child(b)
	return b


func _ready() -> void:
	top_level = true
	for leg in LEGS:
		var lo := sk.find_bone(String(leg[0]))
		var ft := sk.find_bone(String(leg[1]))
		if lo < 0 or ft < 0:
			continue
		var shin := _body(SHIN_R)
		var foot := _body(FOOT_R)
		_parts.append([lo, ft, shin[0], shin[1], foot[0], foot[1]])


func _body(r: float) -> Array:
	var b := AnimatableBody3D.new()
	b.sync_to_physics = false
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = r * 2.0 + 0.1
	cs.shape = cap
	b.add_child(cs)
	add_child(b)
	return [b, cap]


func _physics_process(_d: float) -> void:
	for p in _parts:
		var a: Vector3 = sk.global_transform * sk.get_bone_global_pose(int(p[0])).origin
		var f: Vector3 = sk.global_transform * sk.get_bone_global_pose(int(p[1])).origin
		var g := Vector3(f.x, ground_y, f.z)
		if a.y - ground_y > REACH:                        # only the reachable part of the shin
			a = f.lerp(a, clampf((REACH - (f.y - ground_y)) / maxf(a.y - f.y, 0.01), 0.0, 1.0))
		_place(p[2], p[3], a, f, SHIN_R)
		_place(p[4], p[5], f, g + Vector3(0, FOOT_R * 0.5, 0), FOOT_R)


func _place(b: AnimatableBody3D, cap: CapsuleShape3D, from: Vector3, to: Vector3, r: float) -> void:
	var d := to - from
	var seg := d.length()
	if seg < 0.05:
		d = Vector3.UP
		seg = 0.05
	cap.height = seg + r * 2.0
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	b.global_transform = Transform3D(Basis(x, y, z), (from + to) * 0.5)
