extends Node
## THE VEIL - what the tripod Colossus leaves behind. It watches the three foot bones of the walk; every time a foot that was lifted comes down it
## presses a footprint into the ground (a dark crater with a raised rim of churned soil, a few cracks and thrown clods), puffs dust, and takes
## out the trees under the foot: each one is cut out of the forest (VeilScatter.knock_trees), a stump is left and the tree itself falls over, away from the foot.
## Nothing built is ever touched: a foot that would come down on a house, a wall, a car or a lamp post leaves no mark there.
## Footprints are drawn from code (no asset).
##   var st = load("res://game/enemies/colossus_stomps.gd").attach(tripod, scatter_or_null)         ## on a VeilTripodColossus; free it (or the tripod) to stop
signal stomped(pos: Vector3, radius: float)

const FOOT_BONES := ["Leg_B_Foot", "Leg_L_Foot", "Leg_R_Foot"]
const LIFT := 1.2                       ## (model units) a foot above this is "in the air"
const CONTACT := [0.16, 1.0, 1.05]      ## a lifted foot back under this height has TOUCHED DOWN (end of its swing; the back foot bottoms out lower than the sides)
const MAX_PRINTS := 80
const FOOT_R := 0.9                     ## footprint radius per unit of the Colossus' scale (a 40 m one: 3 m)

var tripod: Node3D
var scatter: Node                       ## the VeilScatter (or null: no trees to fell)
var ground_y := 0.15
var enabled := true
var play_sound := false                 ## the stomp's own thud (leave off where the scene already plays step sounds)
var camera_shake := true                ## the view shakes with each landing, less the further it is
var _shake := 0.0
var dip := 0.16                         ## how far the body sinks on a landing, as a share of the Colossus' scale
var prints: Array[Node3D] = []
var count := 0                          ## stomps that left a mark
var blocked_count := 0                  ## stomps that landed on something built (no mark)
var felled := 0
var _sk: Skeleton3D
var _bones: Array[int] = []
var _lifted := [false, false, false]
var _scale := 1.0
var _mat: StandardMaterial3D
var _bark: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


static func attach(t: Node3D, trees: Node = null) -> Node:
	var s = (load("res://game/enemies/colossus_stomps.gd") as GDScript).new()
	s.name = "Stomps"
	s.tripod = t
	s.scatter = trees
	t.add_child(s)
	return s


func _ready() -> void:
	process_priority = 100                 # after the AnimationPlayer has posed this frame
	_rng.seed = 7731
	var m: Node3D = tripod.get("model")
	if m == null:
		return
	var sks := m.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	_sk = sks[0] as Skeleton3D
	for b in FOOT_BONES:
		_bones.append(_sk.find_bone(b))
	var gy = tripod.get("eye")
	if gy:
		ground_y = gy.ground_y
	_scale = float(tripod.get("height")) / 12.0
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 1.0
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_bark = StandardMaterial3D.new()
	_bark.albedo_color = Color(0.19, 0.13, 0.09)
	_bark.roughness = 1.0
	_bark.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX


func _process(dt: float) -> void:
	if _shake > 0.0:
		var cam := get_viewport().get_camera_3d()
		_shake = maxf(_shake - dt * 2.2, 0.0)
		if cam:
			cam.h_offset = randf_range(-1.0, 1.0) * _shake * _shake * 0.5
			cam.v_offset = randf_range(-1.0, 1.0) * _shake * _shake * 0.5
	if not enabled or _sk == null:
		return
	for i in _bones.size():
		if _bones[i] < 0:
			continue
		var pose := _sk.get_bone_global_pose(_bones[i])
		var y := pose.origin.y
		if y > LIFT:
			_lifted[i] = true
		elif _lifted[i] and y < CONTACT[i]:
			_lifted[i] = false
			_land(_sk.global_transform * pose.origin)


# ------------------------------------------------------------------ a foot comes down
func _land(world_pos: Vector3) -> void:
	var r := FOOT_R * _scale
	var at := Vector3(world_pos.x, ground_y, world_pos.z)
	if _on_structure(at, r):
		blocked_count += 1
		return
	count += 1
	var host := _host()
	var fp := _make_print(r)
	host.add_child(fp)
	fp.global_position = at
	fp.rotation.y = _rng.randf() * TAU
	prints.append(fp)
	while prints.size() > MAX_PRINTS:
		var old: Node3D = prints.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_dust(host, at, r)
	_ring(host, at, r)
	_sink()
	if play_sound:
		Sfx.play("colossus_step", at + Vector3(0, 1, 0), 6.0, 0.55)
	_clods(host, at, r)
	if scatter != null and scatter.has_method("knock_trees"):
		for tr in scatter.knock_trees(at, r * 1.25):
			_fell(host, tr, at, r)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera_shake and cam != null:
		_shake = maxf(_shake, clampf(1.0 / maxf(cam.global_position.distance_to(at) / (r * 9.0), 1.0), 0.0, 1.0))
	stomped.emit(at, r)


func _host() -> Node:
	return scatter.get_parent() if scatter != null and scatter.get_parent() != null else (tripod.get_parent() if tripod.get_parent() else tripod)


## Anything built under the foot? A thin cylinder just above the ground against the physics world; the forest's own trunks and the ground are ignored.
func _on_structure(at: Vector3, r: float) -> bool:
	if not tripod.is_inside_tree():
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r * 0.9
	cyl.height = 2.0
	q.shape = cyl
	q.transform = Transform3D(Basis(), at + Vector3(0, 1.8, 0))     # (its bottom is 0.8 m up: the ground and low kerbs are not "built")
	for hit in tripod.get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c = hit.get("collider")
		if c is StaticBody3D:
			var n := String((c as Node).name)
			if n.ends_with("_Collision"):
				continue                                   # a tree trunk (the Colossus walks through the forest)
			return true
	return false


# ------------------------------------------------------------------ the footprint
func _make_print(r: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Footprint"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spokes := 14
	var radii := [0.0, 0.5, 0.88, 1.12, 1.5]                       # centre, floor, inner wall, rim crest, outer slope
	var heights := [0.02, 0.03, 0.10, 0.16, 0.0]                   # in units of r (the crest is the highest)
	var cols := [Color(0.045, 0.036, 0.03), Color(0.06, 0.048, 0.038), Color(0.12, 0.095, 0.07), Color(0.2, 0.15, 0.1), Color(0.13, 0.115, 0.08)]
	var jr: Array = []
	var jh: Array = []
	for i in spokes:
		jr.append(_rng.randf_range(0.82, 1.2))
		jh.append(_rng.randf_range(0.6, 1.35))
	var ring: Array = []
	for k in radii.size():
		var pts: Array = []
		for i in spokes:
			var a := TAU * i / spokes
			var rr: float = radii[k] * r * (jr[i] if k > 0 else 1.0)
			pts.append([Vector3(cos(a) * rr, heights[k] * r * (jh[i] if k > 1 else 1.0) + 0.03, sin(a) * rr), cols[k].lerp(Color(0.02, 0.02, 0.02), _rng.randf() * 0.25)])
		ring.append(pts)
	for k in radii.size() - 1:
		for i in spokes:
			var j := (i + 1) % spokes
			var a0: Array = ring[k][i]
			var a1: Array = ring[k][j]
			var b0: Array = ring[k + 1][i]
			var b1: Array = ring[k + 1][j]
			for tri in ([[a0, b0, b1]] if k == 0 else [[a0, b0, b1], [a0, b1, a1]]):
				for v in tri:
					st.set_color(v[1])
					st.add_vertex(v[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# cracks run out of the rim across the ground
	var cs := SurfaceTool.new()
	cs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in 7:
		var a := _rng.randf() * TAU
		var d0 := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d0.z, 0, d0.x) * r * 0.05
		var l0 := r * 1.35
		var l1 := r * _rng.randf_range(1.9, 2.8)
		var pts := [d0 * l0 - side, d0 * l0 + side, d0 * l1 + side * 0.2, d0 * l1 - side * 0.2]
		for idx in [0, 1, 2, 0, 2, 3]:
			cs.set_color(Color(0.03, 0.025, 0.02))
			cs.add_vertex(pts[idx] + Vector3(0, 0.05, 0))
	cs.generate_normals()
	var cm := MeshInstance3D.new()
	cm.mesh = cs.commit()
	cm.material_override = _mat
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cm)
	return root


## a puff of dust off the ground, short and low
func _dust(host: Node, at: Vector3, r: float) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 26
	p.lifetime = 2.6
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = r * 0.8
	p.initial_velocity_max = r * 2.2
	p.gravity = Vector3(0, -0.8, 0)
	p.damping_min = 1.2
	p.damping_max = 2.0
	p.scale_amount_min = r * 0.7
	p.scale_amount_max = r * 1.5
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.18, 0.15, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	p.mesh = sm
	host.add_child(p)
	p.global_position = at + Vector3(0, 0.3, 0)
	p.emitting = true
	get_tree().create_timer(4.0).timeout.connect(p.queue_free)


## clods of earth thrown out of the print: they fly, drop and stay
func _clods(host: Node, at: Vector3, r: float) -> void:
	for i in 7:
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz := r * _rng.randf_range(0.06, 0.16)
		bm.size = Vector3(sz, sz * 0.7, sz * 1.2)
		bm.material = _bark if i % 2 == 0 else _mat
		c.mesh = bm
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(c)
		var a := _rng.randf() * TAU
		var d := r * _rng.randf_range(1.3, 3.2)
		var dest := at + Vector3(cos(a) * d, sz * 0.3, sin(a) * d)
		c.global_position = at + Vector3(0, 0.4, 0)
		c.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)
		var tw := c.create_tween()
		tw.tween_property(c, "global_position:x", dest.x, 0.7)
		tw.parallel().tween_property(c, "global_position:z", dest.z, 0.7)
		tw.parallel().tween_property(c, "global_position:y", at.y + r * _rng.randf_range(0.8, 1.8), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "global_position:y", dest.y, 0.38).set_delay(0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ------------------------------------------------------------------ a felled tree: a stump, and the tree falling over away from the foot
func _fell(host: Node, tr: Dictionary, foot: Vector3, r: float) -> void:
	felled += 1
	var base: Vector3 = tr["pos"]
	var stump := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.5
	cm.height = _rng.randf_range(0.7, 1.4)
	cm.radial_segments = 6
	cm.rings = 1
	cm.material = _bark
	stump.mesh = cm
	stump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(stump)
	stump.global_position = base + Vector3(0, cm.height * 0.5, 0)
	stump.rotation.y = _rng.randf() * TAU
	stump.rotation.z = _rng.randf_range(-0.12, 0.12)
	var ps = load(String(tr["scene"])) if String(tr["scene"]) != "" else null
	if ps == null:
		return
	var tree := (ps as PackedScene).instantiate() as Node3D
	var pivot := Node3D.new()
	host.add_child(pivot)
	pivot.add_child(tree)
	pivot.global_position = base
	tree.rotation.y = tr["yaw"]
	var away := Vector3(base.x - foot.x, 0, base.z - foot.z)
	away = away.normalized() if away.length() > 0.05 else Vector3.RIGHT
	away = away.rotated(Vector3.UP, _rng.randf_range(-0.35, 0.35))
	var axis := Vector3.UP.cross(away).normalized()
	var land := _rng.randf_range(1.38, 1.5)
	var tw := pivot.create_tween()
	tw.tween_method(func(a: float): pivot.basis = Basis(axis, a), 0.0, land, _rng.randf_range(0.9, 1.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(_rng.randf_range(0.05, 0.35))
	tw.tween_method(func(a: float): pivot.basis = Basis(axis, a), land, land - 0.07, 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(a: float): pivot.basis = Basis(axis, a), land - 0.07, land, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## the weight of the step: the whole body drops into the landing leg and comes back up slowly
func _sink() -> void:
	var m: Node3D = tripod.get("model")
	if m == null:
		return
	var base := m.position
	var tw := create_tween()
	tw.tween_property(m, "position:y", base.y - dip * _scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "position:y", base.y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## a ring of dust that rolls out of the footprint along the ground
func _ring(host: Node, at: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.5
	cm.radial_segments = 16
	cm.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.26, 0.23, 0.18, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = m
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = at + Vector3(0, 0.3, 0)
	mi.scale = Vector3(r, 1.0, r)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(r * 4.5, 1.6, r * 4.5), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 1.1)
	tw.tween_callback(mi.queue_free)
