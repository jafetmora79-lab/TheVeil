extends SceneTree
## Pictures of the reworked rooms.  godot --path . --resolution 960x540 --script res://game/tests/story_rooms_shots.gd -- which=station|house dir=<folder>
var world
var cam: Camera3D
var dir := "C:/Users/Themo/AppData/Local/Temp/roomshots"
func _initialize() -> void:
	_run.call_deferred()
func shot(name: String, from: Vector3, to: Vector3, fov := 70.0) -> void:
	cam.fov = fov
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
func _run() -> void:
	var which := "station"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("which="): which = a.substr(6)
		if a.begins_with("dir="): dir = a.substr(4)
	DirAccess.make_dir_recursive_absolute(dir)
	var game = root.get_node("Game")
	var dlg = root.get_node("Dialogue")
	dlg.auto_confirm = true
	var DEV = load("res://game/chapters/setups/dev_chapter12.gd") if which == "station" else (load("res://game/chapters/setups/dev_chapter13.gd") if which == "district" else (load("res://game/chapters/setups/dev_chapter15.gd") if which == "finale" else load("res://game/chapters/setups/dev_chapter14.gd")))
	DEV.prepare(game)
	if which == "station":
		game.flags["ch12_noah_na"] = true
	world = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(world)
	for i in 90: await process_frame
	var p4 = world.phase4
	var c5 = p4.chapter5; var c6 = c5.chapter6; var c7 = c6.chapter7; var c8 = c7.chapter8; var c9 = c8.chapter9; var c10 = c9.chapter10; var c11 = c10.chapter11
	var c12 = c11.chapter12
	if world.get("hud"):
		world.hud.visible = false
	cam = Camera3D.new()
	cam.far = 200.0
	world.add_child(cam)
	cam.current = true
	world.player.visible = false
	if which == "district":
		var c13 = c12.chapter13
		var D = c13.D
		await shot("di_street", D.call(Vector3(-2.0, 1.7, 36.0)), D.call(Vector3(2.0, 1.8, 44.0)), 70.0)
		await shot("di_gate_closed", D.call(Vector3(0.0, 1.7, 39.0)), D.call(Vector3(0.0, 1.6, 44.0)), 65.0)
		await shot("di_fence", D.call(Vector3(-14.0, 1.7, 20.0)), D.call(Vector3(-19.5, 1.5, 34.0)), 65.0)
		c13._open_gate(true)
		await shot("di_gate_open", D.call(Vector3(0.0, 1.7, 39.0)), D.call(Vector3(0.0, 1.6, 44.0)), 65.0)
		await shot("di_courtyard", D.call(Vector3(0.0, 1.7, 50.0)), D.call(Vector3(0.0, 2.0, 76.0)), 70.0)
		await shot("di_hut", D.call(Vector3(2.0, 1.6, 71.0)), D.call(Vector3(0.0, 1.2, 76.0)), 62.0)
		await shot("di_hut_wide", D.call(Vector3(-8.0, 2.4, 62.0)), D.call(Vector3(0.0, 1.8, 76.0)), 70.0)
		await shot("di_office", D.call(Vector3(-2.0, 1.7, 38.0)), D.call(Vector3(8.0, 1.5, 42.0)), 70.0)
		await shot("di_office_out", D.call(Vector3(2.0, 1.7, 33.0)), D.call(Vector3(9.0, 1.5, 40.0)), 70.0)
		await shot("di_office_in1", D.call(Vector3(6.8, 1.6, 40.0)), D.call(Vector3(11.9, 1.5, 39.4)), 75.0)
		await shot("di_office_in2", D.call(Vector3(11.2, 1.6, 40.6)), D.call(Vector3(6.0, 1.4, 40.0)), 75.0)
		await shot("di_signs", D.call(Vector3(0.0, 1.7, 36.0)), D.call(Vector3(0.0, 1.8, 44.0)), 80.0)
	elif which == "finale":
		var c13 = c12.chapter13
		var c14 = c13.chapter14
		var c15 = c14.chapter15
		# light the chamber (the game lights it with the flashlight and the mist; this is only to see the models)
		var lt := OmniLight3D.new()
		lt.light_energy = 2.5
		lt.omni_range = 40.0
		world.add_child(lt)
		var UL = c13.UL
		lt.global_position = UL.call(Vector3(12.0, 6.0, 74.0))
		var lt2 := OmniLight3D.new()
		lt2.light_energy = 1.5
		lt2.omni_range = 25.0
		world.add_child(lt2)
		lt2.global_position = UL.call(Vector3(12.0, 3.0, 40.0))
		await shot("fi_chamber", UL.call(Vector3(12.0, 2.0, 63.5)), UL.call(Vector3(12.0, 3.0, 88.0)), 75.0)
		await shot("fi_seal", UL.call(Vector3(12.0, 1.8, 76.0)), UL.call(Vector3(12.0, 3.2, 87.0)), 65.0)
		await shot("fi_ctrl_a", UL.call(Vector3(0.0, 1.7, 70.0)), UL.call(Vector3(-3.2, 1.0, 74.0)), 60.0)
		await shot("fi_ctrl_c", UL.call(Vector3(12.0, 1.7, 74.5)), UL.call(Vector3(12.0, 1.1, 80.4)), 60.0)
		c15._control_done_look("A")
		c15._control_done_look("C")
		await create_timer(2.2).timeout
		await shot("fi_ctrl_c_done", UL.call(Vector3(12.0, 1.7, 74.5)), UL.call(Vector3(12.0, 1.1, 80.4)), 60.0)
		await shot("fi_pillars", UL.call(Vector3(12.0, 1.7, 64.0)), UL.call(Vector3(1.0, 4.0, 80.0)), 70.0)
		await shot("fi_doorway", UL.call(Vector3(12.0, 1.7, 33.0)), UL.call(Vector3(12.0, 2.0, 40.0)), 65.0)
	elif which == "station":
		c12._set_power(true, true)
		c12._slide_now(c12.access_door, false)
		var L = c12.L
		await shot("st_office", L.call(Vector3(-3.2, 1.7, 0.9)), L.call(Vector3(2.0, 1.0, 4.2)))
		await shot("st_office2", L.call(Vector3(3.4, 1.8, 5.4)), L.call(Vector3(-2.5, 1.2, 1.5)))
		await shot("st_control", L.call(Vector3(-3.5, 1.8, 10.2)), L.call(Vector3(6.5, 1.2, 12.0)))
		await shot("st_panel_off", L.call(Vector3(4.6, 1.5, 12.0)), L.call(Vector3(6.5, 1.2, 12.0)), 60.0)
		c12._panel_state(true)
		await shot("st_panel_on", L.call(Vector3(4.6, 1.5, 12.0)), L.call(Vector3(6.5, 1.2, 12.0)), 60.0)
		await shot("st_access_closed", L.call(Vector3(0.0, 1.7, 23.0)), L.call(Vector3(0.0, 1.5, 28.0)), 65.0)
		c12._slide_now(c12.access_door, true)
		await shot("st_access_open", L.call(Vector3(0.0, 1.7, 23.0)), L.call(Vector3(0.0, 1.0, 30.0)), 65.0)
		await shot("st_tunnel", L.call(Vector3(0.0, -4.3, 56.0)), L.call(Vector3(6.0, -4.5, 61.0)), 70.0)
		await shot("st_seal", L.call(Vector3(11.0, -4.3, 61.0)), L.call(Vector3(16.0, -4.7, 61.0)), 70.0)
		await shot("st_vent_closed", L.call(Vector3(21.2, -4.9, 63.2)), L.call(Vector3(24.0, -5.4, 64.7)), 60.0)
		c12._grate_burst = true
		if c12.grate:
			c12.grate.rotation.x = deg_to_rad(-100.0)
			c12.grate.position.y -= 0.25
		for i in 3:
			c12._spawn_skitter("S%d" % i, c12.L(Vector3(22.6 - 0.6 * i, -6.0, 64.2 + 0.5 * i)))
		await shot("st_vent_open", L.call(Vector3(21.2, -4.9, 63.2)), L.call(Vector3(24.0, -5.4, 64.7)), 60.0)
	else:
		var c12b = c12
		var c13 = c12b.chapter13
		var c14 = c13.chapter14
		var hl = c14.hl
		for k in ["front", "window", "back"]:
			c14._place_defense(k, true)
		c14._spread()
		await shot("hs_front", hl.call(Vector3(-1.6, 1.6, 7.4)), hl.call(Vector3(0.9, 1.1, 3.5)), 70.0)
		await shot("hs_window", hl.call(Vector3(-0.6, 1.7, 6.8)), hl.call(Vector3(-1.4, 1.5, 3.3)), 70.0)
		await shot("hs_back", hl.call(Vector3(1.4, 1.6, 8.6)), hl.call(Vector3(-2.2, 1.1, 11.6)), 70.0)
		await shot("hs_room", hl.call(Vector3(-2.7, 2.0, 11.0)), hl.call(Vector3(0.5, 0.9, 6.0)), 80.0)
		await shot("hs_room2", hl.call(Vector3(2.7, 2.0, 4.1)), hl.call(Vector3(-0.5, 0.9, 8.0)), 80.0)
	print("ROOMS done ", which)
	quit()
