extends Node3D
class_name VeilTentacleMound
## THE VEIL - the broken ground a street tentacle comes up through: a low-poly ring of displaced dirt heaved up
## round a dark hole, with tilted slabs of the street's own asphalt on its rim. Built in code (a dozen-odd
## triangles per ring), at street level; `grow(k)` 0..1 heaves it up as the surface breaks.

const SEG := 11
var road_mat: Material
var _rng := RandomNumberGenerator.new()
var _body: MeshInstance3D
var _slabs: Array[MeshInstance3D] = []


## The street's own surface material under `at` (the road mesh the ray hits), or null.
static func road_material(space: PhysicsDirectSpaceState3D, at: Vector3) -> Material:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at - Vector3.UP * 1.0, 1))
	if hit.is_empty():
		return null
	var n: Node = hit["collider"]
	for i in 3:
		if n == null:
			break
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			return (n as MeshInstance3D).get_active_material(0)
		for c in n.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh:
				return (c as MeshInstance3D).get_active_material(0)
		n = n.get_parent()
	return null


static func make(parent: Node, at: Vector3, seed_value: int, grown := 1.0) -> VeilTentacleMound:
	var m := VeilTentacleMound.new()
	m.name = "TentacleMound"
	m._rng.seed = seed_value
	parent.add_child(m)
	m.global_position = at
	m.road_mat = road_material(m.get_world_3d().direct_space_state, at)
	m._build()
	m.grow(grown)
	return m


func _build() -> void:
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.17, 0.13, 0.1)
	dirt.roughness = 1.0
	var hole := StandardMaterial3D.new()
	hole.albedo_color = Color(0.02, 0.018, 0.016)
	hole.roughness = 1.0
	var asphalt: Material = road_mat
	if asphalt == null:
		var a := StandardMaterial3D.new()
		a.albedo_color = Color(0.2, 0.2, 0.21)
		a.roughness = 1.0
		asphalt = a
	# rings: hole edge (below street), crest (jagged, raised), outer (flush with the street)
	var r_hole := 0.34
	var r_crest := 0.66
	var r_out := 1.3
	var inner: Array[Vector3] = []
	var crest: Array[Vector3] = []
	var outer: Array[Vector3] = []
	for i in SEG:
		var a := TAU * i / SEG + _rng.randf_range(-0.12, 0.12)
		var d := Vector3(cos(a), 0, sin(a))
		inner.append(d * r_hole * _rng.randf_range(0.9, 1.1) + Vector3(0, -0.06, 0))
		crest.append(d * r_crest * _rng.randf_range(0.85, 1.15) + Vector3(0, _rng.randf_range(0.16, 0.34), 0))
		outer.append(d * r_out * _rng.randf_range(0.85, 1.15) + Vector3(0, 0.01, 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(dirt)
	for i in SEG:
		var j := (i + 1) % SEG
		_quad(st, inner[i], inner[j], crest[j], crest[i])      # the inner slope, down into the hole
		_quad(st, crest[i], crest[j], outer[j], outer[i])      # the outer slope, down to the street
	st.generate_normals()
	var mesh := st.commit()
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	st2.set_material(hole)
	var c := Vector3(0, -0.12, 0)
	for i in SEG:
		var j := (i + 1) % SEG
		_tri(st2, c, inner[j], inner[i])
	st2.generate_normals()
	st2.commit(mesh)
	_body = MeshInstance3D.new()
	_body.name = "Mound"
	_body.mesh = mesh
	add_child(_body)
	# slabs of broken street, tilted up on the crest (the street's own material)
	for i in 7:
		var a := TAU * i / 7.0 + _rng.randf_range(-0.25, 0.25)
		var d := Vector3(cos(a), 0, sin(a))
		var s := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(_rng.randf_range(0.28, 0.5), 0.07, _rng.randf_range(0.22, 0.4))
		s.mesh = bm
		s.material_override = asphalt
		add_child(s)
		s.position = d * _rng.randf_range(0.62, 0.95) + Vector3(0, 0.12, 0)
		s.basis = Basis(Vector3.UP, a) * Basis(Vector3(0, 0, 1), _rng.randf_range(0.35, 0.7))   # leaning out
		s.set_meta("rest", s.transform)
		_slabs.append(s)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# wound so the face points up / outward (the mound is seen from above)
	var n := (b - a).cross(c - a)
	if n.y < 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)


## 0 = flat street (just cracked), 1 = fully heaved up.
func grow(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if _body:
		_body.scale = Vector3(lerpf(0.55, 1.0, k), maxf(k, 0.02), lerpf(0.55, 1.0, k))
	for s in _slabs:
		var r: Transform3D = s.get_meta("rest")
		s.transform = Transform3D(r.basis.scaled(Vector3.ONE * maxf(k, 0.05)), Vector3(r.origin.x * lerpf(0.5, 1.0, k), r.origin.y * k, r.origin.z * lerpf(0.5, 1.0, k)))
