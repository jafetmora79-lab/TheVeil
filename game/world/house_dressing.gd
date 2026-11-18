extends RefCounted
class_name VeilHouseDressing
## THE VEIL - "lived-in, then abandoned" dressing for the Pack 03 houses, added at load as extra non-colliding nodes
## (the house models, their colliders, doors and triggers are untouched). Props come from game/world/dressing/VEIL_HouseKit.glb
## (Blender: tools/build_house_kit.py) and a few Pack 02 vegetation GLBs. Layouts are per design, in the house's own frame:
## +X right, +Y up, the front of the house towards -Z, the front door at about (0.3, 0.6, 2.4).
## apply(house) is idempotent. Cheap: ~340 triangles of kit, small meshes, one warm porch light, no shadows.

const KIT := "res://game/world/dressing/VEIL_HouseKit.glb"
const VEG := "res://THE_VEIL_ASSETS_V2/02_Town/Vegetation/%s.glb"
const STREET := "res://THE_VEIL_ASSETS_V2/02_Town/Street_Props/%s.glb"
static var _meshes := {}                    ## kit piece name -> Mesh
static var _mats := {}                      ## shared nearest-filtered materials


static func supported(design: String) -> bool:
	return LAYOUTS.has(design)


static func apply(house: Node3D) -> bool:
	var info: Dictionary = house.get_meta("veil_house", {})
	var layout = LAYOUTS.get(String(info.get("design", "")), null)
	if layout == null or house.get_node_or_null("VeilDressing") != null:
		return false
	# only where the front door really is where the layout expects it (Ranch A/B); other colourways are skipped, never guessed
	var mirror := -1.0 if info.get("mirrored", false) else 1.0
	var ok := false
	for d in info.get("doors", []):
		if d.get("name", "") == "INT_Door_Front":
			var c: Array = d["center"]
			ok = absf(float(c[0]) - 0.3 * mirror) < 0.35 and absf(float(c[2]) - 2.4) < 0.35
	if not ok:
		return false
	_load_kit()
	var root := Node3D.new()
	root.name = "VeilDressing"
	root.add_to_group("house_dressing")
	house.add_child(root)
	for e in layout:
		var n: Node3D = _make(e)
		if n == null:
			continue
		var p: Array = e["at"]
		n.position = Vector3(p[0] * mirror, p[1], p[2])
		n.rotation_degrees.y = float(e.get("yaw", 0.0)) * mirror
		if e.has("tilt"):
			n.rotation_degrees.z = float(e["tilt"])
		if e.has("scale"):
			n.scale = Vector3.ONE * float(e["scale"])
		root.add_child(n)
		if e.has("light"):
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.72, 0.4)
			l.light_energy = float(e["light"])
			l.omni_range = 7.5
			l.shadow_enabled = false
			l.position = n.position + Vector3(0, -0.1, -0.7)
			root.add_child(l)
	return true


static func _load_kit() -> void:
	if not _meshes.is_empty():
		return
	var scn := (load(KIT) as PackedScene).instantiate()
	for m in scn.find_children("*", "MeshInstance3D", true, false):
		_meshes[m.name] = m.mesh
	scn.free()


static func _material_for(piece: String) -> Material:
	var alpha := piece.begins_with("Moss") or piece.begins_with("Grime") or piece.begins_with("Stain")
	var key := "A" if alpha else "O"
	if _mats.has(key):
		return _mats[key]
	var src := (_meshes[piece] as Mesh).surface_get_material(0) as BaseMaterial3D
	var m := src.duplicate() as StandardMaterial3D
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.metallic = 0.0
	if not alpha:
		m.albedo_color = Color(1.45, 1.45, 1.5)
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func _make(e: Dictionary) -> Node3D:
	var piece := String(e["p"])
	if _meshes.has(piece):
		var mi := MeshInstance3D.new()
		mi.mesh = _meshes[piece]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if piece == "PorchLamp":
			var g := StandardMaterial3D.new()
			g.albedo_color = Color(1, 0.8, 0.45)
			g.emission_enabled = true
			g.emission = Color(1.0, 0.7, 0.32)
			g.emission_energy_multiplier = 1.6
			mi.material_override = g
		else:
			mi.material_override = _material_for(piece)
		return mi
	var path: String = (VEG if piece.begins_with("VG_") else STREET) % piece
	if ResourceLoader.exists(path):
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		for b in inst.find_children("*", "CollisionObject3D", true, false):     # dressing never blocks anything
			b.get_parent().remove_child(b)
			b.free()
		return inst
	return null


## Ranch (single storey, garage on the left, porch and front door centre). Front = -Z.
const LAYOUTS := {
	"Ranch": [
		{"p": "Slab_B", "at": [0.3, 0.0, -1.0], "yaw": 2}, {"p": "Slab_A", "at": [0.35, 0.0, -2.0], "yaw": -4},
		{"p": "Slab_A", "at": [0.2, 0.0, -3.0], "yaw": 7, "tilt": 2}, {"p": "Slab_B", "at": [0.4, 0.0, -4.0], "yaw": -3},
		{"p": "Slab_A", "at": [0.3, 0.0, -5.05], "yaw": 5}, {"p": "Slab_B", "at": [0.45, 0.0, -6.1], "yaw": -8, "tilt": -2},
		{"p": "Slab_B", "at": [0.3, 0.0, -7.1], "yaw": 3},
		{"p": "VG_Weeds", "at": [0.9, 0.0, -2.5], "scale": 0.8}, {"p": "VG_Weeds", "at": [-0.3, 0.0, -4.6], "scale": 0.9},
		{"p": "VG_TallGrassClump", "at": [1.1, 0.0, -6.0]},
		{"p": "DoorMat", "at": [0.3, 0.6, 1.35], "yaw": 3}, {"p": "Pot_Dead", "at": [-0.95, 0.6, 1.2]},
		{"p": "Pot_Tipped", "at": [1.65, 0.6, 1.0], "yaw": 140}, {"p": "Newspapers", "at": [1.05, 0.6, 0.55], "yaw": 20},
		{"p": "Newspapers", "at": [1.9, 0.0, -2.0], "yaw": -35}, {"p": "VG_FallenLeaves", "at": [-0.4, 0.6, 0.6]},
		{"p": "PorchLamp", "at": [1.15, 2.15, 2.03], "light": 1.5},
		{"p": "TrashBags", "at": [-6.0, 0.0, 1.0], "yaw": 25}, {"p": "TrashCan_Tipped", "at": [-6.6, 0.0, -0.8], "yaw": 70},
		{"p": "Bike_Fallen", "at": [3.9, 0.0, -3.2], "yaw": 70},
		{"p": "VG_TallGrassClump", "at": [-5.2, 0.0, 1.6]}, {"p": "VG_TallGrassClump", "at": [3.0, 0.0, 1.5]}, {"p": "VG_TallGrassClump", "at": [5.4, 0.0, 1.0]},
		{"p": "VG_IvyPatch", "at": [4.4, 0.0, 2.0]}, {"p": "VG_DeadVegetation", "at": [-1.8, 0.0, 0.8]},
		{"p": "VG_Bush", "at": [2.7, 0.0, 1.5], "scale": 0.9}, {"p": "VG_Bush", "at": [5.6, 0.0, 0.9], "scale": 1.1},
		{"p": "Moss_Flat", "at": [0.4, 0.07, -1.4], "yaw": 20}, 
		{"p": "Grime_Streaks", "at": [-4.6, 0.3, 1.99]}, {"p": "Grime_Streaks", "at": [3.0, 0.7, 1.99]},
		{"p": "SP_Mailbox_Residential", "at": [-1.6, 0.0, -9.6]},
	],
}
