extends Node3D
## THE VEIL - inside the video game store: a small floating [E] over each real interaction (an Interactable under
## the store with a prompt showing), only within reach (6 m), gone once it is used/taken or its prompt is cleared.

const REACH := 6.0
var world: Node
var _marks := {}                       ## Interactable -> Label3D
var _t := 0.0


func setup(w: Node) -> void:
	world = w


func _process(delta: float) -> void:
	_t -= delta
	if world == null or world.game_shop == null or _t > 0.0:
		return
	_t = 0.25
	var p: Vector3 = world.player.global_position
	var cine: bool = world.get("_cine") and is_instance_valid(world.get("_cine"))
	var near: bool = world.player.visible and not cine and world.game_shop.global_position.distance_to(p) < 30.0
	for it in world.game_shop.find_children("*", "Interactable", true, false):
		var i := it as Interactable
		var npc: bool = i.get_parent() is CharacterBody3D or String(i.get("kind")) == "talk"    # people: no marker
		var want: bool = near and not npc and not i.taken and i.collision_layer != 0 and i.get_prompt() != "" \
			and i.global_position.distance_to(p) < REACH
		var m: Label3D = _marks.get(i)
		if want and m == null:
			m = Label3D.new()
			m.text = "[E]"
			m.font_size = 28
			m.pixel_size = 0.004
			m.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			m.no_depth_test = false
			m.modulate = Color(1.0, 0.85, 0.45, 0.85)
			m.outline_size = 6
			add_child(m)
			_marks[i] = m
		if m:
			m.visible = want
			if want:
				m.global_position = i.global_position + Vector3(0, 0.55, 0)
	for k in _marks.keys():
		if not is_instance_valid(k):
			(_marks[k] as Node).queue_free()
			_marks.erase(k)
