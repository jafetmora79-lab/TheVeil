extends Node3D
## THE VEIL - floating road arrows for the opening drive (home -> the video game store), at the route's turns
## (the section ends in world_data.json "route_sections"): a dim amber arrow above the road pointing the way on.
## Shown only while driving there (left_house, not reached_town), never in a cinematic; each hides once passed.

var world: Node
var arrows: Array = []                 ## [{node, at: Vector3, passed}]


func setup(w: Node) -> void:
	world = w
	var f := FileAccess.open("res://game/world/world_data.json", FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if not (d is Dictionary):
		return
	var route: Array = d.get("route", [])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.72, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.75
	for sec in ["A_residential", "C_county_road", "B_transition", "D_commercial"]:
		var end: Array = d["route_sections"][sec][1]
		var j := _index(route, Vector2(end[0], end[1]))
		if j < 0 or j >= route.size() - 1:
			continue
		var here := Vector2(route[j][0], route[j][1])
		var ahead := Vector2(route[mini(j + 3, route.size() - 1)][0], route[mini(j + 3, route.size() - 1)][1])
		var dir := (ahead - here).normalized()
		var at := Vector3(here.x, _ground(Vector3(here.x, 0, here.y)) + 2.6, here.y) - Vector3(dir.x, 0, dir.y) * 6.0
		var n := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.55
		cone.height = 1.6
		cone.radial_segments = 4
		n.mesh = cone
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		n.global_position = at
		n.look_at(at + Vector3(dir.x, 0, dir.y), Vector3.UP)
		n.rotate_object_local(Vector3.RIGHT, -PI * 0.5)        # the cone's tip (+y) along the way on
		n.visible = false
		arrows.append({"node": n, "at": at, "dir": Vector3(dir.x, 0, dir.y), "passed": false})


func _index(route: Array, p: Vector2) -> int:
	for i in route.size():
		if Vector2(route[i][0], route[i][1]).distance_to(p) < 0.5:
			return i
	return -1


func _ground(p: Vector3) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 60, 0), p - Vector3(0, 20, 0), 1))
	return (hit["position"] as Vector3).y if hit else 0.0


func active() -> bool:
	return Game.has_flag("left_house") and not Game.has_flag("reached_town")


func _process(_d: float) -> void:
	if world == null or arrows.is_empty():
		return
	var on: bool = active() and not (world.get("_cine") and is_instance_valid(world.get("_cine")))
	var cam := get_viewport().get_camera_3d()
	var me: Vector3 = cam.global_position if cam else world.player.global_position     # in the car or on foot
	for a in arrows:
		if not a["passed"] and (me - a["at"]).dot(a["dir"]) > 4.0 and Vector2(me.x - a["at"].x, me.z - a["at"].z).length() < 40.0:
			a["passed"] = true                                 # driven past it: gone
		(a["node"] as Node3D).visible = on and not a["passed"]
		if (a["node"] as Node3D).visible:
			(a["node"] as Node3D).position.y = a["at"].y + sin(Time.get_ticks_msec() * 0.003) * 0.15
	if Game.has_flag("reached_town"):
		queue_free()                                           # the drive is over
