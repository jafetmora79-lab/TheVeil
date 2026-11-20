class_name VeilTripodEye
extends Node3D
## THE VEIL - the tripod creature's eye. Add it as a child of the MON_tripod model: the pod (its own bone, "Eye") turns to watch `target`, glows and breathes,
## lights the street orange, and on `beam_on` fires a thin beam at the target. The slit is the only lit part of the pod's texture.
var target: Node3D
var beam_on := false
var level := 1.0                       ## 0..1: how awake / bright the eye is
var max_angle := 1.15                  ## radians the pod may turn from straight ahead
var skel: Skeleton3D
var eye := -1
var mesh: MeshInstance3D
var glow: StandardMaterial3D
var light: OmniLight3D
var beam: MeshInstance3D
var _dir: Vector3
var _t := 0.0
var _beam_k := 0.0
var search_on := false                 ## the eye as a searchlight: a spotlight and a faint cone of light along where it looks
var spot: SpotLight3D
var cone: MeshInstance3D
var _cone_mat: ShaderMaterial
var _search_k := 0.0
var ground_y := 0.0
const CONE_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float k = 1.0;
void fragment() {
	float a = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.1) * 0.45 * k * smoothstep(4.0, 30.0, length(VERTEX));
	ALBEDO = vec3(1.0, 0.74, 0.40);
	ALPHA = a;
}
"""


func _ready() -> void:
	var m := get_parent()
	skel = m.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	eye = skel.find_bone("Eye")
	for n in m.find_children("*", "MeshInstance3D", true, false):
		mesh = n as MeshInstance3D
	if mesh and mesh.mesh and mesh.mesh.get_surface_count() > 1:
		var src := mesh.get_active_material(1) as StandardMaterial3D
		if src:
			glow = src.duplicate() as StandardMaterial3D
			glow.emission_enabled = true
			glow.emission = Color(1.0, 0.62, 0.3)
			glow.emission_texture = glow.albedo_texture
			glow.emission_energy_multiplier = 2.0
			mesh.set_surface_override_material(1, glow)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.18)
	light.omni_range = 16.0
	light.shadow_enabled = false
	add_child(light)
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.radial_segments = 6
	cyl.height = 1.0
	beam.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(1.0, 0.36, 0.06, 0.55)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.top_level = true
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	spot = SpotLight3D.new()
	spot.light_color = Color(1.0, 0.72, 0.4)
	spot.spot_range = 170.0
	spot.spot_angle = 6.0
	spot.spot_attenuation = 0.4
	spot.light_energy = 0.0
	spot.shadow_enabled = false
	add_child(spot)
	cone = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 5.0
	cm.height = 10.0
	cm.radial_segments = 12
	cone.mesh = cm
	var sh := Shader.new()
	sh.code = CONE_SHADER
	_cone_mat = ShaderMaterial.new()
	_cone_mat.shader = sh
	cone.material_override = _cone_mat
	cone.top_level = true
	cone.visible = false
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone)
	_dir = Vector3(0, 0, -1)


func eye_world_pos() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(eye).origin


func _process(delta: float) -> void:
	if skel == null or eye < 0:
		return
	_t += delta
	var par := skel.get_bone_parent(eye)
	var pg := skel.get_bone_global_pose(par)
	var base := pg.basis * skel.get_bone_rest(eye).basis             # the pod's basis with no turn of its own
	var f_rest := Vector3(0, 0, -1)
	var f_now := (base * (skel.get_bone_global_rest(eye).basis.inverse() * f_rest)).normalized()
	var head := pg * skel.get_bone_rest(eye).origin
	if target != null:
		var want := ((skel.global_transform.affine_inverse() * target.global_position) - head).normalized()
		var ang := f_now.angle_to(want)
		if ang > max_angle:
			want = f_now.slerp(want, max_angle / ang)
		_dir = _dir.slerp(want, 1.0 - exp(-5.0 * delta)).normalized()
	else:
		_dir = _dir.slerp(f_now, 1.0 - exp(-3.0 * delta)).normalized()
	var q := Quaternion(f_now, _dir)
	skel.set_bone_pose_rotation(eye, (base.inverse() * Basis(q) * base).get_rotation_quaternion())
	# glow, breathing, light
	var pulse := 0.8 + 0.2 * sin(_t * 2.4) + 0.08 * sin(_t * 9.7)
	_beam_k = move_toward(_beam_k, 1.0 if beam_on else 0.0, delta * 4.0)
	if glow:
		glow.emission_energy_multiplier = (0.9 + 1.6 * _beam_k) * pulse * level
	var pos := eye_world_pos()
	var fwd := (skel.global_transform.basis * (skel.get_bone_global_pose(eye).basis * (skel.get_bone_global_rest(eye).basis.inverse() * f_rest))).normalized()
	light.global_position = pos + fwd * 0.9
	light.light_energy = (0.6 + 2.6 * _beam_k) * pulse * level
	if _beam_k > 0.01 and target != null:
		var p0 := pos + fwd * 0.55
		var p1 := target.global_position
		var d := p1 - p0
		var len := d.length()
		beam.visible = true
		(beam.mesh as CylinderMesh).height = len
		var w := _beam_k * (1.0 + 0.35 * sin(_t * 38.0))
		beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, d / len)).scaled(Vector3(w, 1.0, w)), (p0 + p1) * 0.5)
	else:
		beam.visible = false
	# the searchlight
	_search_k = move_toward(_search_k, 1.0 if search_on else 0.0, delta * 2.5)
	if _search_k > 0.01:
		var sp := pos + fwd * 0.6
		spot.global_position = sp
		spot.look_at(sp + fwd, Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT)
		spot.light_energy = 9.0 * _search_k * pulse
		var tl := 160.0
		if fwd.y < -0.02:
			tl = minf(160.0, (sp.y - ground_y) / -fwd.y)
		(cone.mesh as CylinderMesh).height = tl
		(cone.mesh as CylinderMesh).bottom_radius = 0.2 + tl * 0.075
		_cone_mat.set_shader_parameter("k", _search_k)
		cone.visible = true
		cone.global_transform = Transform3D(Basis(Quaternion(Vector3.DOWN, fwd)), sp + fwd * tl * 0.5)
	else:
		spot.light_energy = 0.0
		cone.visible = false
