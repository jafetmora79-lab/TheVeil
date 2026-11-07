extends RefCounted
class_name VeilStairAssist
## THE VEIL - solid invisible collision for residential stairs, added over the houses at load (the visible stairs and
## the house models are untouched).
## The houses' own stair collision is two one-sided faces: a ramp, and a guard along the open side whose face points
## OUT of the stair. A capsule on the stair met the guard's back: no stop at the rail, half through it, caught there,
## or over the edge and shut out by the same face. And under the flight the ramp did not stop anyone at all.
## Here each flight gets a solid ramp in the same plane (it ends level with both floors: no lip, no gap, no step),
## and each open side a solid guard. Both are convex, so they block from either side, the player and the survivors
## alike. The guard stops short of both ends, so nothing catches at the foot or on the landing.
## Data: game/data/house_stairs.json, keyed by the house's design (meta "veil_house"), in the house's own frame.

const DATA := "res://game/data/house_stairs.json"
const RAMP_DEPTH := 0.25        ## solid under the ramp plane
const GUARD_H := 1.0            ## above the ramp
const GUARD_T := 0.1            ## thickness
const GUARD_IN := 0.08          ## inner face this far in from the stair's edge (2 cm inside the old one-sided face)
const GUARD_FOOT := 0.3         ## clear of the first step
const GUARD_TOP := 0.05         ## clear of the landing


static func apply(houses: Node) -> int:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (data is Dictionary):
		return 0
	var n := 0
	for h in houses.get_children():
		var info: Dictionary = h.get_meta("veil_house", {})
		if info.is_empty():
			continue
		var key := String(info.get("design", "")) + ("_Mirror" if info.get("mirrored", false) else "")
		if data.has(key):
			_add(h as Node3D, data[key])
			n += 1
	return n


static func _add(house: Node3D, flights: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "StairAssist"
	body.collision_layer = 1
	body.collision_mask = 0
	house.add_child(body)
	for f in flights:
		var o: Array = f["origin"]
		var xf := Transform3D(Basis(Vector3.UP, float(f["yaw"])), Vector3(o[0], o[1], o[2]))
		var w := float(f["width"])
		var l := float(f["run"])
		var h := float(f["height"])
		# the ramp: top face exactly the house's own ramp plane, foot to landing
		var dn := Vector3.DOWN * RAMP_DEPTH
		var a := Vector3(0, 0, -0.05)
		var b := Vector3(w, 0, -0.05)
		var c := Vector3(w, h, l)
		var d := Vector3(0, h, l)
		_prism(body, xf, PackedVector3Array([a, b, c, d, a + dn, b + dn, c + dn, d + dn]))
		for side in f["open"]:
			var x_in := w - GUARD_IN if side == "r" else GUARD_IN
			var x_out := x_in + GUARD_T if side == "r" else x_in - GUARD_T
			var z0 := GUARD_FOOT
			var z1 := l - GUARD_TOP
			var y0 := z0 / l * h - 0.02
			var y1 := z1 / l * h - 0.02
			var up := Vector3.UP * GUARD_H
			# both ends cut back at 45 degrees on the stair side: a capsule walking close to the rail meets a slope
			# that turns it onto the stair, not a square end it stops dead against (that end caught anyone hugging
			# the rail at the first step, and near the landing)
			var cut := GUARD_T * 3.0
			var p0 := Vector3(x_in, y0 + cut / l * h, z0 + cut)
			var p1 := Vector3(x_in, y1 - cut / l * h, z1 - cut)
			var p2 := Vector3(x_out, y1, z1)
			var p3 := Vector3(x_out, y0, z0)
			_prism(body, xf, PackedVector3Array([p0, p1, p2, p3, p0 + up, p1 + up, p2 + up, p3 + up]))


static func _prism(body: StaticBody3D, xf: Transform3D, points: PackedVector3Array) -> void:
	var s := ConvexPolygonShape3D.new()
	s.points = points
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = xf
	body.add_child(cs)
