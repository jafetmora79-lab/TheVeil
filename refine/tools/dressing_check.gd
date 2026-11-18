extends SceneTree
## Loads the real World and reports which houses were dressed and how many nodes/lights; no collision bodies may be added.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("Game").new_game()
	var w = load("res://game/scenes/World.tscn").instantiate()
	root.add_child(w)
	for i in 30: await process_frame
	var n := 0
	for h in w.get_node("Residential/Houses").get_children():
		var d = h.get_node_or_null("VeilDressing")
		if d:
			n += 1
			var bodies: int = d.find_children("*", "CollisionObject3D", true, false).size()
			print("DRESSED ", h.name, " ", h.get_meta("veil_house", {}).get("name", ""), " children=", d.get_child_count(), " collision_bodies=", bodies)
	print("RESULT dressed_houses=", n)
	quit()
