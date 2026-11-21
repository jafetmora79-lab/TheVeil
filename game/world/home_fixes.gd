class_name VeilHomeFixes
extends RefCounted
## Fixes to the player's home found in the review notes (2026-11-21, notes #2-#5). Applied once when the world is built (the house comes from a shared asset pack scene, so the
## fixes are made on the instance, not in the pack).
##   #2 the first dining chair stood turned a quarter turn: its back did not face away from the table
##   #3 the brick chimney stack stood right behind the south window (x 51.1-52.1: bricks filled the pane): it is moved along the wall to the free stretch between the two windows
##   #4 the curtain rod hung across the middle of the window: the curtains are raised so the rod is above the window and they hang to below the sill
##   #5 the roof's shingle surface dipped 0.33 m below the ceiling into the rooms (a grey band across the ceiling): that part is lifted onto the ceiling plane

const FENCE := "res://THE_VEIL_ASSETS_V2/03_Residential/Exterior_Modules/RES_Ext_Wall_2m_Planks.glb"
const CEILING_Y := 3.36                 # world-y of the interior ceiling (house floor 0.75, ceiling 3.35)
const ROOM_X := Vector2(44.7, 53.84)    # the rooms' floor plan, inside the walls (world x / z)
const ROOM_Z := Vector2(502.3, 514.9)
const CHIMNEY_SHIFT := 1.95            # metres along the south wall (toward -x) from the window to the free wall between the windows
const LOWEST := 2.6                     # only members hanging between here and the ceiling count

static func apply(home: Node3D) -> Dictionary:
	var report := {}
	var furn := home.get_node_or_null("Furniture")
	if furn:
		var chair := furn.get_node_or_null("DiningChair_Wood_01") as Node3D
		if chair:
			chair.rotation.y = -PI * 0.5                      # (its mate, _02, is a quarter turn the other way: back to the west; this one is on the east side of the table)
			report["chair"] = true
		var cur := furn.get_node_or_null("Curtains_Gingham_01") as Node3D
		if cur:
			cur.position.y += 0.25                            # rod above the window's top edge, panels down past the sill
			report["curtains"] = true
	var house := home.get_node_or_null("House/RES_PlayerHome")
	if house:
		var ext := house.find_child("RES_PlayerHome_Exterior", true, false) as MeshInstance3D
		if ext and ext.mesh:
			report["roof_lifted"] = _lift_roof(ext)
	return report


## The roof planes dip below the ceiling: their low edges (eaves) run 0.2 - 0.5 m inside the rooms, which showed as a long grey band across the ceiling (found by painting the
## trim surface by area and by leaving surfaces out). The low corners of the LARGE roof triangles (trim underside and shingles, > 2 m2) are lifted onto the ceiling plane, where
## the plaster ceiling hides them; small trim (window / door heads) is left alone. Returns how many vertices moved.
static func _lift_roof(mi: MeshInstance3D) -> int:
	var src := mi.mesh
	var out := ArrayMesh.new()
	var moved := 0
	var inv := mi.global_transform.affine_inverse()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var mat := src.surface_get_material(s)
		if mat != null and mat.resource_name == "M_Arch_BrickRed":                  # the chimney stack: off the window, 1.95 m along the wall (world x)
			var cv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var shift: Vector3 = inv.basis * Vector3(-CHIMNEY_SHIFT, 0, 0)
			for i in cv.size():
				cv[i] += shift
			arr[Mesh.ARRAY_VERTEX] = cv
			moved += 1000
		if mat != null and (mat.resource_name == "M_Arch_TrimPainted" or mat.resource_name == "M_Arch_RoofShinglesDarkGray"):
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var big := {}
			for t in range(0, idx.size() - 2, 3):
				var a: Vector3 = mi.global_transform * vs[idx[t]]
				var b: Vector3 = mi.global_transform * vs[idx[t + 1]]
				var c: Vector3 = mi.global_transform * vs[idx[t + 2]]
				if (b - a).cross(c - a).length() * 0.5 > 2.0:
					big[idx[t]] = true
					big[idx[t + 1]] = true
					big[idx[t + 2]] = true
			for vi in big:
				var w: Vector3 = mi.global_transform * vs[vi]
				if w.y < CEILING_Y and w.y > LOWEST:
					w.y = CEILING_Y
					vs[vi] = inv * w
					moved += 1
			arr[Mesh.ARRAY_VERTEX] = vs
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arr)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	mi.mesh = out
	return moved
