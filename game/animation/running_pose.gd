extends RefCounted
## Skeleton-space rotations relative to the animator's arms-down rest pose.
## Configure lengths once from the rig, then reuse `output` to avoid frame allocations.
const BONES = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm",
	"LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
	"LeftFoot", "RightFoot", "LeftToes", "RightToes"]
const LEGS = [["LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftUpperArm", "LeftLowerArm"],
	["RightUpperLeg", "RightLowerLeg", "RightFoot", "RightUpperArm", "RightLowerArm"]]
const STRIDE = 1.96
const CONTACT = 0.38

static func bounce(phase: float, weight: float) -> float:
	var t := fposmod(phase / TAU, 0.5) * 2.0
	return (-0.14 + 0.045 * pow(sin(PI * t), 2.0)) * clampf(weight, 0.0, 1.0)

## Ankle target relative to its neutral location. During contact its speed exactly
## cancels a root advancing STRIDE metres per cycle. Swing joins with equal velocity.
static func foot_target(phase: float) -> Vector2:
	var t := fposmod(phase / TAU, 1.0)
	if t <= CONTACT:
		return Vector2(STRIDE * (CONTACT * 0.5 - t), 0.0)
	var u := (t - CONTACT) / (1.0 - CONTACT)
	var edge := STRIDE * CONTACT * 0.5
	var tangent := -STRIDE * (1.0 - CONTACT)
	var x := (2.0 * u * u * u - 3.0 * u * u + 1.0) * -edge
	x += (u * u * u - 2.0 * u * u + u) * tangent
	x += (-2.0 * u * u * u + 3.0 * u * u) * edge
	x += (u * u * u - u * u) * tangent
	return Vector2(x, 0.27 * pow(sin(PI * u), 2.0))

static func sample(phase: float, weight: float, bone_names: Array,
		forward: Vector3, up: Vector3, right: Vector3,
		thigh: float, shin: float, hip_to_ankle: float, neutral: Vector3, output: Dictionary) -> Dictionary:
	var w := clampf(weight, 0.0, 1.0)
	for bone in bone_names:
		output[bone] = Quaternion.IDENTITY
	output["Spine"] = Quaternion(right, deg_to_rad(-10.0 * w))
	output["Chest"] = Quaternion(right, deg_to_rad(-5.0 * w))
	output["UpperChest"] = Quaternion(up, deg_to_rad(4.0 * sin(phase) * w))
	output["Neck"] = Quaternion(right, deg_to_rad(7.0 * w))
	output["Head"] = Quaternion(right, deg_to_rad(5.0 * w))
	for side_index in 2:
		var names: Array = LEGS[side_index]
		var p := phase + float(side_index) * PI
		var target := foot_target(p)
		target.x += neutral.z
		var height := hip_to_ankle + bounce(phase, 1.0) - target.y
		var distance := minf(Vector2(target.x, height).length(), thigh + shin - 0.0001)
		var hip := atan2(target.x, height) + acos(clampf(
			(thigh * thigh + distance * distance - shin * shin) / (2.0 * thigh * distance), -1.0, 1.0))
		var knee := acos(clampf((thigh * thigh + shin * shin - distance * distance) / (2.0 * thigh * shin), -1.0, 1.0)) - PI
		output[names[0]] = Quaternion(right, (hip - neutral.x) * w)
		output[names[1]] = Quaternion(right, (knee - neutral.y) * w)
		output[names[2]] = Quaternion(right, -(hip + knee - neutral.x - neutral.y) * w)
		# Arms trail the leg/torso cycle by 0.18 rad, with elbows always flexed forward.
		var pump := sin(p - 0.18)
		output[names[3]] = Quaternion(right, deg_to_rad((-12.0 - 34.0 * pump) * w))
		output[names[4]] = Quaternion(right, deg_to_rad((78.0 + 12.0 * pump) * w))
	return output
