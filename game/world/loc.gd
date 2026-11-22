class_name VeilLoc
extends RefCounted
## Words baked into pictures (signs, stencils, the town map) are drawn from ONE text table per language by game/tools/blender/make_chapter16_signs.py (review note #68: a Spanish version is
## coming; nothing with letters is drawn by hand). `tex("plaque")` is the picture for the current language, English when that language has none. The current language is Game.language ("en", "es").
const DIR := "res://game/prototypes/ch16/tex/"


static func language() -> String:
	var g = Engine.get_main_loop().root.get_node_or_null("Game") if Engine.get_main_loop() else null
	var l := String(g.get("language")) if g != null and g.get("language") != null else "en"
	return l if l != "" else "en"


static func tex(name: String) -> Texture2D:
	for l in [language(), "en"]:
		var p := DIR + "%s_%s.png" % [name, l]
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null


## A flat textured sign quad (facing +Z of its node), `size` metres, with a thin dark backing.
static func sign_quad(parent: Node3D, name: String, size: Vector2, xf: Transform3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Sign_" + name
	parent.add_child(root)
	root.global_transform = xf
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x + 0.04, size.y + 0.04, 0.02)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.1, 0.1, 0.11)
	bm.material = bmat
	back.mesh = bm
	root.add_child(back)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.8
	qm.material = m
	q.mesh = qm
	q.position = Vector3(0, 0, 0.0115)
	root.add_child(q)
	return root
