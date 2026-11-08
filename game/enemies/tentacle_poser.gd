extends Node
class_name VeilTentaclePoser
## THE VEIL - builds a Mist Tentacle's pose in view, bone by bone (T_01 .. T_10), instead of playing a canned clip:
## per bone a bend in the tentacle's side plane (`curl`, about the bone's Z: a circle facing the player) and in its
## forward plane (`lean`, about X: towards / away from whatever the tentacle's +Z faces). `weight` 1 = this pose,
## 0 = the clip's pose (blended per bone, so handing back to the AnimationPlayer never snaps).

var sk: Skeleton3D
var bones: PackedInt32Array = []
var curl: PackedFloat32Array = []
var lean: PackedFloat32Array = []
var weight := 1.0
var straight := false                     ## true: bends start from a straight chain (the rest pose's own curl dropped)
var _rest := {}
var _written := {}
var _clip := {}


static func attach(tentacle: Node) -> VeilTentaclePoser:
	var sks := tentacle.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var p := VeilTentaclePoser.new()
	p.name = "Poser"
	p.sk = sks[0] as Skeleton3D
	for i in range(1, 11):
		var b := p.sk.find_bone("T_%02d" % i)
		if b >= 0:
			p.bones.append(b)
			p._rest[b] = p.sk.get_bone_rest(b).basis.get_rotation_quaternion()
	p.curl.resize(p.bones.size())
	p.lean.resize(p.bones.size())
	tentacle.add_child(p)
	p.process_priority = 90                      # after the clip, before the writhe (VeilTentacleWiggle: 100)
	p.apply()
	return p


func set_all(c: float, l: float) -> void:
	for i in bones.size():
		curl[i] = c
		lean[i] = l


## Bones from index `from` on (0 = T_01): `c` / `l` each; the ones below get `c_low` / `l_low`.
func set_split(from: int, c_low: float, l_low: float, c: float, l: float) -> void:
	for i in bones.size():
		curl[i] = c if i >= from else c_low
		lean[i] = l if i >= from else l_low


func _process(_d: float) -> void:
	apply()


func apply() -> void:
	if sk == null or not is_instance_valid(sk):
		return
	for i in bones.size():
		var b := bones[i]
		var now := sk.get_bone_pose_rotation(b)
		var clip: Quaternion = _clip.get(b, _rest[b]) if _written.has(b) and now.is_equal_approx(_written[b]) else now
		if weight >= 0.999:
			clip = _rest[b]
		_clip[b] = clip
		var base_q: Quaternion = Quaternion.IDENTITY if straight else (_rest[b] as Quaternion)
		var mine: Quaternion = base_q * Quaternion(Vector3.BACK, curl[i]) * Quaternion(Vector3.RIGHT, lean[i])
		var q := clip.slerp(mine.normalized(), clampf(weight, 0.0, 1.0)).normalized()
		sk.set_bone_pose_rotation(b, q)
		if weight >= 0.999:
			var o: Vector3 = sk.get_bone_rest(b).origin
			# straight: each bone's offset laid along its parent's +Y (the model's own offsets carry its curl)
			sk.set_bone_pose_position(b, Vector3(0, o.length(), 0) if straight and i > 0 else o)
		_written[b] = q


## World position of the tip (end of T_10) for the pose now applied.
func tip() -> Vector3:
	sk.force_update_all_bone_transforms()
	var a := sk.get_bone_global_pose(bones[bones.size() - 2]).origin
	var b := sk.get_bone_global_pose(bones[bones.size() - 1]).origin
	return sk.global_transform * (b + (b - a))
