extends SceneTree
## dev tool: what each chapter-select start gives the player (inventory, flags, position, sidearm, map)
const CS := preload("res://game/chapters/chapter_select.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	for n in range(2, 17):
		var ok_: bool = CS.prepare(game, n)
		var inv: Array = game.inventory.duplicate()
		inv.sort()
		var sa: Dictionary = game.world_state.get("sidearm", {})
		print("AUDIT ch%d ok=%s step=%s chap=%s pos=%s inv=%s" % [n, ok_, game.current_step().get("id", ""), game.chapter_number(), game.player_state.get("pos", []), inv])
		print("AUDIT      gun=%s sidearm=%s map=%s flashlight_state=%s stock=%s c5=%s lost=%s repaired=%s car=%s" % [game.has_item("handgun"), sa, game.has_flag("map_acquired"), game.world_state.get("flashlight", {}), game.world_state.get("shelter_stock", {}), game.has_flag("c5_started"), game.has_flag("ch9_supermarket_lost"), game.has_flag("vehicle_repaired"), (game.vehicle_state as Dictionary).get("pos", [])])
	quit(0)
