extends Node3D
class_name VeilDoorwayTentacle
## THE VEIL - the loading-door tentacle: its own 3D creature for a doorway, not a tilted copy of the street one.
## A low-poly tapered tube (8 sides, Mist Tentacle material) skinned to its own 14-bone chain. Its root is buried
## outside, below the dock; the body lies along a path that runs under the roll-up door's gap and into the bay.
## Movement is follow-the-leader along that path: `head` (metres of body past the root) grows -> the TIP comes
## through first and every segment behind it follows the same line through the opening; the root never moves.
## `writhe` adds a travelling sideways wave (none at the root, most at the tip). Built and posed in code.

const SOURCE := "res://THE_VEIL_ASSETS_V2/07_Creatures/Godot_Scenes/CRT_MistTentacle_Medium.tscn"
const BONES := 14
const SEG := 0.34                         ## metres per bone: 4.76 m of body
const SIDES := 8
const RINGS_PER_BONE := 3
const R_BASE := 0.17
const R_TIP := 0.025

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var path: PackedVector3Array = []        ## local (parent frame) polyline, root first, densely sampled
var _cum: PackedFloat32Array = []
var head := 0.0                           ## body length out along the path (0 = all in the root)
var writhe := 0.0                         ## 0..~1.5
var writhe_hz := 4.0
var _phase := 0.0
var report := {}


static func create(parent: Node3D) -> VeilDoorwayTentacle:
	var t := VeilDoorwayTentacle.new()
	t.name = "DoorwayTentacle"
	parent.add_child(t)
	t._build()
	return t


func length() -> float:
	return BONES * SEG


func _material() -> Material:
	var ps := load(SOURCE) as PackedScene
	if ps == null:
		return null
	var src := ps.instantiate()
	var m: Material = null
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh and mesh.get_surface_count() > 0:
			m = mesh.surface_get_material(0)
			break
	src.free()
	return m


func _build() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	for i in BONES:
		skeleton.add_bone("D_%02d" % i)
		if i > 0:
			skeleton.set_bone_parent(i, i - 1)
		skeleton.set_bone_rest(i, Transform3D(Basis(), Vector3(0, 0 if i == 0 else SEG, 0)))
	skeleton.reset_bone_poses()
	var skin := Skin.new()
	for i in BONES:
		skin.add_named_bind("D_%02d" % i, Transform3D(Basis(), Vector3(0, -i * SEG, 0)))
	# the tube, bind pose straight up +Y, weights blended between neighbouring bones
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	var rings := BONES * RINGS_PER_BONE
	for r in rings + 1:
		var y := float(r) / RINGS_PER_BONE * SEG
		var k := clampf(y / (BONES * SEG), 0.0, 1.0)
		var rad := lerpf(R_BASE, R_TIP, pow(k, 0.85)) * (1.0 + 0.08 * sin(r * 1.7))   # a slightly knotted taper
		var bf := y / SEG
		var b0 := clampi(int(floor(bf)), 0, BONES - 1)
		var b1 := clampi(b0 + 1, 0, BONES - 1)
		var w1 := clampf(bf - b0, 0.0, 1.0) if b1 != b0 else 0.0
		for s in SIDES + 1:
			var a := TAU * s / SIDES
			var n := Vector3(cos(a), 0, sin(a))
			verts.append(n * rad + Vector3(0, y, 0))
			norms.append(n)
			uvs.append(Vector2(float(s) / SIDES, k * 4.0))
			bones.append_array([b0, b1, 0, 0])
			weights.append_array([1.0 - w1, w1, 0.0, 0.0])
	for r in rings:
		for s in SIDES:
			var a0 := r * (SIDES + 1) + s
			var a1 := a0 + 1
			var c0 := a0 + SIDES + 1
			var c1 := c0 + 1
			idx.append_array([a0, c0, a1, a1, c0, c1])
	# a blunt cap at the tip
	var tip_i := verts.size()
	verts.append(Vector3(0, rings / float(RINGS_PER_BONE) * SEG + 0.04, 0))
	norms.append(Vector3.UP)
	uvs.append(Vector2(0.5, 4.0))
	bones.append_array([BONES - 1, 0, 0, 0])
	weights.append_array([1.0, 0.0, 0.0, 0.0])
	var top := rings * (SIDES + 1)
	for s in SIDES:
		idx.append_array([top + s, tip_i, top + s + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := _material()
	if mat:
		mesh.surface_set_material(0, mat)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Body"
	mesh_instance.mesh = mesh
	mesh_instance.skin = skin
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.extra_cull_margin = 6.0             # (posed far from its bind box)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	report["triangles"] = idx.size() / 3


## The line the body follows, in this node's frame: Catmull-Rom through `pts` (root first), sampled every 5 cm.
func set_path(pts: Array) -> void:
	path = PackedVector3Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		var steps := maxi(2, int(p1.distance_to(p2) / 0.05))
		for k in steps:
			var t := float(k) / steps
			var t2 := t * t
			var t3 := t2 * t
			path.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	path.append(pts[n - 1])
	_cum = PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		_cum.append(_cum[i - 1] + path[i].distance_to(path[i - 1]))


func path_length() -> float:
	return _cum[_cum.size() - 1] if _cum.size() > 0 else 0.0


## The point `s` metres along the path (clamped to the ends).
func at(s: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO
	if s <= 0.0:
		return path[0]
	var hi := _cum.bsearch(s)
	if hi >= path.size():
		return path[path.size() - 1]
	var lo := maxi(hi - 1, 0)
	var span := _cum[hi] - _cum[lo]
	return path[lo].lerp(path[hi], (s - _cum[lo]) / span if span > 0.0001 else 0.0)


## Where each bone joint is now: the tip at `head`, every joint SEG behind it along the path (joints that would be
## behind the root stay bunched in it, out of sight), plus the writhe.
func joints() -> PackedVector3Array:
	var out := PackedVector3Array()
	var start := head - BONES * SEG
	for i in BONES + 1:
		var s := start + i * SEG
		var p := at(maxf(s, 0.0))
		if writhe > 0.0 and s > 0.3:
			var k := clampf((s - 0.3) / 2.5, 0.0, 1.0)
			var ahead := at(s + 0.05) - at(s - 0.05)
			var side := ahead.cross(Vector3.UP).normalized() if ahead.length() > 0.001 else Vector3.RIGHT
			var up := side.cross(ahead).normalized() if ahead.length() > 0.001 else Vector3.UP
			p += side * sin(_phase - i * 0.55) * 0.11 * writhe * k + up * sin(_phase * 1.4 - i * 0.7) * 0.035 * writhe * k
		out.append(p)
	return out


func _process(delta: float) -> void:
	_phase += TAU * writhe_hz * delta
	pose()


## Bones onto the joints: each bone at joint i, its +Y towards joint i+1.
func pose() -> void:
	if path.is_empty():
		return
	var j := joints()
	var parent_global := Transform3D()
	var up_hint := Vector3.UP                      # (a round tube: the roll about its own axis does not show)
	for i in BONES:
		var a: Vector3 = j[i]
		var b: Vector3 = j[i + 1]
		var y := b - a
		if y.length() < 0.0001:
			y = Vector3.UP * 0.0001 if i == 0 else parent_global.basis.y
		y = y.normalized()
		var x := up_hint.cross(y)
		if x.length() < 0.01:
			x = Vector3.RIGHT
		x = x.normalized()
		var z := x.cross(y).normalized()
		var g := Transform3D(Basis(x, y, z), a)
		var local := g if i == 0 else parent_global.affine_inverse() * g
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		parent_global = g
	report["tip"] = to_global(j[BONES])


func tip_global() -> Vector3:
	return to_global(joints()[BONES])
