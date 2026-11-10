extends SceneTree
## THE VEIL - Chapter 6 "Prepare for the search": the SUPPLIES marker and the check are at the shelter supply crate
## (not the old service-desk stash); the town map has its aerial sheets (town + Maple Ave); Maple Ave houses open
## for looting. Headless, short.
##   godot --headless --path . --fixed-fps 60 --script res://game/tests/ch6_supplies_map_test.gd

const DEV := preload("res://game/chapters/setups/dev_chapter6.gd")
const MAPLE := ["EXT_HOUSE_04", "EXT_HOUSE_37", "EXT_HOUSE_31", "EXT_HOUSE_25", "EXT_HOUSE_36", "EXT_HOUSE_03", "EXT_HOUSE_16"]
var fails := 0


func ok(name: String, cond: bool, detail := "") -> void:
	print("TEST %s %s %s" % [name, "PASS" if cond else "FAIL", detail])
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()
	create_timer(200.0).timeout.connect(func():
		print("RESULT FAIL (watchdog)")
		quit(1))


func _run() -> void:
	var game := root.get_node("Game")
	root.get_node("Dialogue").auto_confirm = true
	DEV.prepare(game)
	var w: Node = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	await frames(200)
	var ex = w.expedition
	var c5 = w.phase4.chapter5
	var c6 = c5.chapter6 if c5 else null
	ok("chapter6_live", c6 != null)
	game.flags.erase("ch6_eddie_ready")
	game.flags["ch6_marcus_briefing_complete"] = true
	game.flags["ch6_eddie_talked"] = true
	await frames(30)
	ok("c6_pending_at_crate", ex.c6_check_pending() and ex.supply_chest.prompt_text == "[E] Check the Supplies", ex.supply_chest.prompt_text)
	c6._update_marker()
	var tgt = w.hud._mk_target
	var crate: Vector3 = (ex.supply_chest as Node3D).global_position
	ok("marker_on_crate", tgt is Vector3 and (tgt as Vector3).distance_to(crate) < 1.5, "%s vs %s" % [str(tgt), str(crate)])
	ok("stash_prompt_off", String(c5.its["stash"].prompt_text) == "")
	ex._use_supply_chest(w.player)
	await frames(10)
	ok("supplies_checked", game.has_flag("ch6_eddie_ready"))
	if w.hud.inv_panel.visible:
		w.hud.inv_panel.close()
	await frames(40)
	ok("crate_back_to_normal", not ex.c6_check_pending() and ex.supply_chest.prompt_text == "[E] Shelter Supplies")
	# the map: aerial sheets for both views
	var nm = w.get("nav_map")
	if nm == null:
		nm = w.find_child("*NavMap*", true, false)
	ok("map_textures", nm != null and nm._tex.has("town") and nm._tex.has("north") and nm._tex["town"] is Texture2D, str(nm._tex.keys() if nm else []))
	if nm:
		var t: Texture2D = nm._tex.get("town")
		var v: Rect2 = nm.VIEWS["town"]
		ok("map_aspect_town", t != null and absf(float(t.get_width()) / t.get_height() - v.size.x / v.size.y) < 0.01)
		nm.view = "north"
		var nt: Texture2D = nm._tex.get("north")
		var nv: Rect2 = nm.VIEWS["north"]
		ok("map_aspect_north", nt != null and absf(float(nt.get_width()) / nt.get_height() - nv.size.x / nv.size.y) < 0.01)
	# Maple Ave: the new explorable houses open (single storey, furnished, loot inside)
	var opened: Array = MAPLE.filter(func(z): return ex.houses.has(z) and ex.houses[z] != null)
	ok("maple_houses_open", opened.size() == MAPLE.size(), str(opened))
	var loot_ok := true
	for z in opened:
		loot_ok = loot_ok and (ex.houses[z].loot as Dictionary).size() >= 1
	ok("maple_loot_inside", loot_ok)
	ok("maple_on_map", nm != null and MAPLE.all(func(z): return nm.houses.has(z) and nm.accessible(z)))
	print("RESULT %s fails=%d" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
