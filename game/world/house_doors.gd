extends RefCounted
## The houses that cannot be searched (review note #58): their front doors used to be plain scenery. Each now answers [E] with the reason it stays shut: stuck / barred, too wrecked to be worth entering,
## or something moving inside (the Skitters). One reason per house, fixed (so it never changes between visits); the explorable houses (game/data/scavenge_houses.json) are left alone.
const REASONS := {
	"locked": ["house_locked_1", "house_locked_2"],
	"wrecked": ["house_wrecked_1", "house_wrecked_2"],
	"skitters": ["house_skitters_1", "house_skitters_2"],
}


static func reason_of(house: Node3D) -> String:
	if house.find_child("DestroyedCol", true, false) != null or String(house.name).contains("shellcrawler"):
		return "wrecked"                                   # a house a Shellcrawler / the collapse got to
	var h := absi(String(house.name).hash())
	return "skitters" if h % 4 == 0 else "locked"


static func apply(world: Node) -> Dictionary:
	var report := {"doors": 0}
	var houses := world.get_node_or_null("Residential/Houses")
	if houses == null:
		return report
	var spec: Dictionary = (load("res://game/world/scavenge_house.gd") as GDScript).load_specs().get("houses", {})
	for h in houses.get_children():
		if not (h is Node3D) or spec.has(String(h.name)):
			continue
		var d := h.find_child("INT_Door_Front", true, false) as Node3D
		if d == null or d.get_node_or_null("Interact") != null:
			continue
		var why := reason_of(h as Node3D)
		var it := Interactable.attach(d, {"kind": "custom", "label": "Door", "prompt_text": "[E] Try the Door"})
		it.set_meta("why", why)
		var hn := String(h.name)
		var tries := [0]
		it.used.connect(func(_by):
			var ids: Array = REASONS[why]
			var at: Vector3 = d.global_position + Vector3(0, 1.0, 0)
			match why:
				"locked": Sfx.play("door_close", at, -6.0, 1.7)
				"wrecked": Sfx.play("door_close", at, -4.0, 0.5)
				"skitters": Sfx.bank_at("ss_retreat", at, -4.0, 8.0)
			Dialogue.say(String(ids[tries[0] % ids.size()]), false, true)
			tries[0] += 1)
		report["doors"] += 1
	return report
