extends RefCounted
class_name VeilViewHands
## THE VEIL - the first-person hands that hold the handgun: a right hand in a firm grip (palm on the right of the
## grip, three fingers wrapping the front strap, thumb forward along the left of the frame, index laid straight
## along the frame above the trigger guard) and a left support hand (palm on the left, fingers under the right
## hand's, thumb forward), each with a forearm in a jacket sleeve running off the bottom corners of the view.
## Blocky on purpose, like the handgun model itself. Built in the gun's own space (origin at the base of the
## grip, +Y up, the muzzle toward -Z), so the hands move with the gun. The support hand sits on its own node so
## a reload can take it down to the magazine and back.

const SKIN := Color(0.82, 0.68, 0.58)
const SKIN_SHADE := Color(0.68, 0.54, 0.45)
const SLEEVE := Color(0.17, 0.19, 0.22)
const CUFF := Color(0.26, 0.28, 0.31)

var root: Node3D
var support: Node3D
var _mats := {}


func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		m.metallic_specular = 0.0
		m.emission_enabled = true                       # a little self-light: hands read as skin even in the dim, foggy streets
		m.emission = c
		m.emission_energy_multiplier = 0.5
		_mats[k] = m
	return _mats[k]


func _box(parent: Node3D, size: Vector3, center: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = center
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A forearm: wrist -> along `dir`, the first stretch bare skin, then the jacket sleeve with a cuff.
func _arm(parent: Node3D, wrist: Vector3, dir: Vector3, length := 0.34) -> void:
	var d := dir.normalized()
	var skin_len := 0.05
	var cuff_len := 0.022
	var sleeve_len := length - skin_len - cuff_len
	var basis := Basis.looking_at(-d, Vector3.UP)          # the box's local -Z points along the arm
	# box z extends toward +Z of the local frame; position the centre along d
	_box(parent, Vector3(0.036, 0.034, skin_len), wrist + d * skin_len * 0.5, SKIN_SHADE).basis = basis
	_box(parent, Vector3(0.046, 0.044, cuff_len), wrist + d * (skin_len + cuff_len * 0.5), CUFF).basis = basis
	_box(parent, Vector3(0.050, 0.050, sleeve_len), wrist + d * (skin_len + cuff_len + sleeve_len * 0.5), SLEEVE).basis = basis


func build(gun: Node3D) -> void:
	root = Node3D.new()
	root.name = "Hands"
	gun.add_child(root)
	# ---- right hand: palm on the right of the grip, web over the back strap
	var r := Node3D.new()
	r.name = "RightHand"
	root.add_child(r)
	_box(r, Vector3(0.030, 0.056, 0.040), Vector3(0.0285, 0.046, 0.054), SKIN)                 # palm
	_box(r, Vector3(0.036, 0.034, 0.022), Vector3(0.002, 0.083, 0.076), SKIN)                  # web of the hand, over the back strap
	for i in 3:                                                                                  # middle, ring, little finger
		var y := 0.066 - 0.019 * i
		_box(r, Vector3(0.048 - 0.003 * i, 0.017, 0.019), Vector3(0.004, y, 0.0175), SKIN)
		_box(r, Vector3(0.004, 0.017, 0.012), Vector3(-0.018 - 0.0015 * i, y, 0.0125), SKIN_SHADE)    # finger tips curling round to the left
	_box(r, Vector3(0.012, 0.013, 0.062), Vector3(0.0195, 0.0685, 0.0), SKIN)                  # index, straight along the frame
	_box(r, Vector3(0.012, 0.014, 0.052), Vector3(-0.0195, 0.081, 0.018), SKIN)                # thumb, forward along the left
	_box(r, Vector3(0.016, 0.022, 0.030), Vector3(-0.0185, 0.080, 0.062), SKIN)                # thumb base
	_arm(r, Vector3(0.012, 0.058, 0.090), Vector3(0.20, -0.40, 1.0))
	# ---- left support hand: palm on the left, fingers under the right hand's, thumb forward
	support = Node3D.new()
	support.name = "SupportHand"
	root.add_child(support)
	var l := support
	_box(l, Vector3(0.030, 0.050, 0.036), Vector3(-0.0285, 0.030, 0.050), SKIN)                # palm
	for i in 2:
		var y := 0.0145 + 0.0 - 0.0 + 0.0
		y = 0.030 - 0.017 * i - 0.0
		_box(l, Vector3(0.046, 0.016, 0.017), Vector3(-0.004, 0.016 + 0.0 - 0.0 * i + (0.015 if i == 0 else 0.0) - 0.0, 0.0165), SKIN_SHADE if i == 1 else SKIN)
	_box(l, Vector3(0.012, 0.013, 0.050), Vector3(-0.0265, 0.064, 0.012), SKIN)                # thumb forward, over the right thumb
	_arm(l, Vector3(-0.028, 0.018, 0.074), Vector3(-0.24, -0.42, 1.0))


## Take the support hand off the grip (reload): `drop` 0..1 moves it down and back to the magazine base.
func set_support(drop: float, spread := 0.0) -> void:
	if support:
		support.position = Vector3(-0.012 * spread, -0.07 * drop, 0.03 * drop)
		support.rotation = Vector3(0.0, 0.0, 0.0)
