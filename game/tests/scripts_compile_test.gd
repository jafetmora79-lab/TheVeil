extends SceneTree
## Every story script compiles with the autoloads present (a parse error elsewhere only shows when a chapter loads).
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	var bad := 0
	for p in ["res://game/world/chapter9.gd", "res://game/world/evacuation.gd", "res://game/world/chapter10.gd", "res://game/world/scene_mover.gd", "res://game/world/chapter8.gd", "res://game/world/chapter7.gd", "res://game/world/chapter6.gd", "res://game/npc/npc_animator.gd",
			"res://game/encounters/run_struggle.gd", "res://game/world/gondola_aisle.gd", "res://game/ui/storage_panel.gd"]:
		var s := load(p) as GDScript
		var good := s != null and s.can_instantiate()
		print("TEST compile_%s %s" % [p.get_file(), "PASS" if good else "FAIL"])
		if not good:
			bad += 1
	print("RESULT %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	quit()
