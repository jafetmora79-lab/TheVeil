extends Node
## Review note #133: the street mailboxes can be checked (E). Mostly junk mail and bills; now and then something a person could use. Each box is decided once by where it stands (the same every time)
## and remembered in Game.world_state["mailboxes"] (never twice, and a load never rolls it again).
const LOOT := [["", 0.38], ["energy_snack", 0.20], ["batteries", 0.12], ["water_bottle", 0.10], ["canned_food", 0.08], ["painkillers", 0.04], ["note", 0.08]]
const JUNK := ["Junk mail, a flyer and a gas bill.", "A pizza menu and a postcard from nobody.", "Empty. Dust and a dead moth.", "Bills, all of them overdue.", "A catalogue from before all this."]
const NOTES := ["A letter: \"Please, if anyone is reading this, we went north. Do not stay.\"", "A child's drawing of a house, and a very tall thing next to it."]
var world: Node
var its := {}


func setup(w: Node) -> void:
	world = w
	for n in w.find_children("SP_Mailbox_Residential*", "Node3D", true, false):
		if (n as Node3D).get_child_count() > 0:
			_attach(n as Node3D)


func _key(n: Node3D) -> String:
	return "%d:%d" % [roundi(n.global_position.x), roundi(n.global_position.z)]


func _done() -> Dictionary:
	if not Game.world_state.has("mailboxes"):
		Game.world_state["mailboxes"] = {}
	return Game.world_state["mailboxes"]


func _attach(n: Node3D) -> void:
	var it := Interactable.attach(n, {"kind": "custom", "label": "Mailbox", "prompt_text": "[E] Check the Mailbox"})
	var key := _key(n)
	it.collision_layer = 0 if _done().has(key) else 8
	it.prompt_text = "" if _done().has(key) else "[E] Check the Mailbox"
	it.used.connect(func(_b): _open(n, it, key))
	its[key] = it


func _roll(key: String) -> String:
	var r := float(absi(hash(key)) % 1000) / 1000.0
	var acc := 0.0
	for e in LOOT:
		acc += float(e[1])
		if r < acc:
			return String(e[0])
	return ""


func _open(n: Node3D, it: Interactable, key: String) -> void:
	if _done().has(key):
		return
	var what := _roll(key)
	_done()[key] = what if what != "" else "junk"
	it.collision_layer = 0
	it.prompt_text = ""
	Sfx.play("door_open", n.global_position + Vector3(0, 1.0, 0), -8.0, 1.2)
	var text := String(JUNK[absi(hash(key)) % JUNK.size()])
	if what == "note":
		text = String(NOTES[absi(hash(key)) % NOTES.size()])
	elif what != "":
		if what == "batteries" and world.get("phase4") != null and world.phase4.has_method("_got_batteries"):
			world.phase4._got_batteries(1)
		else:
			Game.add_item(what)
		Sfx.play("pickup", n.global_position + Vector3(0, 1.0, 0), -4.0)
		text = "In the mailbox: " + String(Game.item_info(what).get("name", what)).to_lower() + "."
	if world.hud and world.hud.has_method("set_hint"):
		world.hud.set_hint(text)
		world.get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(world.hud) and world.hud.hint.text == text:
				world.hud.set_hint(""))
