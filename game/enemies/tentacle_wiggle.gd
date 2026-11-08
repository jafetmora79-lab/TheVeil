extends Node
class_name VeilTentacleWiggle
## THE VEIL - an organic writhe layered on a Mist Tentacle's own clips: a travelling wave along its bone chain
## (T_01 .. T_10), side to side with a smaller up-and-down, stronger towards the tip and almost nothing at the
## base (so the part hidden outside a door or under the ground stays put). Set `intensity` (0 = still) and `speed`
## from the scene that owns the tentacle; both ease towards their targets so changes never snap.
## Runs after the AnimationPlayer each frame (high process priority) and bends whatever pose the clip left, never
## its own previous output (so a paused or finished clip does not accumulate the bend).

var intensity := 0.0          ## target 0..~1.6
var speed := 3.0              ## target wave frequency (Hz)
var amp := 0.085              ## radians per bone at full intensity, at the tip
var vertical := 0.3           ## up-and-down share of the side-to-side bend (kept small: door gap, floor)
var sk: Skeleton3D
var _cur := 0.0
var _hz := 3.0
var _phase := 0.0
var _bones: PackedInt32Array = []
var _base := {}               ## bone -> the clip's pose under the bend
var _written := {}            ## bone -> what this node last wrote
var frames := 0               ## (tests) frames bent


static func attach(tentacle: Node) -> VeilTentacleWiggle:
	var sks := tentacle.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var w := VeilTentacleWiggle.new()
	w.name = "Wiggle"
	w.sk = sks[0] as Skeleton3D
	tentacle.add_child(w)
	return w


func _ready() -> void:
	process_priority = 100                     # after the clip has posed the bones this frame
	if sk == null:
		return
	for i in range(1, 11):
		var b := sk.find_bone("T_%02d" % i)
		if b >= 0:
			_bones.append(b)


func _process(delta: float) -> void:
	if sk == null or not is_instance_valid(sk) or _bones.is_empty():
		return
	_cur = move_toward(_cur, intensity, delta * 4.0)
	_hz = move_toward(_hz, speed, delta * 6.0)
	_phase += TAU * _hz * delta
	var n := _bones.size()
	for i in n:
		var b := _bones[i]
		var now := sk.get_bone_pose_rotation(b)
		var base: Quaternion = _base[b] if _written.has(b) and now.is_equal_approx(_written[b]) else now
		_base[b] = base
		if _cur <= 0.001:
			if _written.has(b):
				sk.set_bone_pose_rotation(b, base)   # back to the clip's own pose
				_written.erase(b)
			continue
		var k := float(i) / float(maxi(n - 1, 1))
		var a := amp * _cur * (0.15 + 0.85 * k)
		var side := sin(_phase - i * 0.38) * a
		var up := sin(_phase * 1.63 - i * 0.5 + 1.1) * a * vertical
		var q := (base * Quaternion(Vector3.RIGHT, side) * Quaternion(Vector3.BACK, up)).normalized()
		sk.set_bone_pose_rotation(b, q)
		_written[b] = q
	if _cur > 0.001:
		frames += 1
