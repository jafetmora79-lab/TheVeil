extends SceneTree
## THE VEIL - the sedan's body material uses the URSC standard_opaque shader (the first use of addons/ursc), and the
## glass / lights keep theirs. Headless; it checks the wiring, not the look (that needs the owner's eyes).
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var car = load("res://game/vehicles/player_sedan.gd").new()
	world.add_child(car)
	await physics_frame
	if not car.RETRO_BODY:                              # switched off: the imported materials stay
		ok("retro_off_keeps_original_materials", car.retro_surfaces == 0)
		print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
		quit(1 if fails > 0 else 0)
		return
	ok("body_surfaces_replaced", car.retro_surfaces >= 1, str(car.retro_surfaces))
	var shaded := 0
	var glass_kept := 0
	for mi in car.model.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for i in m.get_surface_count():
			var ov := (mi as MeshInstance3D).get_surface_override_material(i)
			var base := m.surface_get_material(i)
			if ov is ShaderMaterial and (ov as ShaderMaterial).shader == car.RETRO_SHADER:
				shaded += 1
				ok("texture_kept", (ov as ShaderMaterial).get_shader_parameter("albedo_texture") != null)
			elif base != null and String(base.resource_name) in ["M_Veh_Glass", "M_Veh_Lights"]:
				glass_kept += 1
	ok("count_matches", shaded == car.retro_surfaces, "%d / %d" % [shaded, car.retro_surfaces])
	ok("glass_and_lights_untouched", glass_kept >= 1, str(glass_kept))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
