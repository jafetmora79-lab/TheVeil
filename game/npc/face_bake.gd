class_name VeilFaceBake
extends RefCounted
## THE VEIL - baked expressions on a Mixamo-rigged NPC's OWN head texture (game/tools/compose_expressions.py + bake_expression_patches.gd).
## The head's material becomes a small shader: texel = mix(original texel, patch texel, patch alpha). A patch holds ONLY the texels of the eyes, brows and mouth (feathered), mapped onto the
## model's own UV layout through the exact projection the face crop was made with, so there is no second surface, no overlay and no seam; neutral shows the untouched original texture.
const SHADER := preload("res://game/npc/face_bake.gdshader")
const NAMES := ["blink", "talk_small", "talk_wide", "scared", "angry", "worried"]
var material: ShaderMaterial
var patches := {}
var state := "neutral"


static func apply(model: Node3D, slug: String) -> VeilFaceBake:
	var jf := FileAccess.open("res://game/prototypes/npc_meshy/face_bake/%s/rect.json" % slug, FileAccess.READ)
	if jf == null:
		return null
	var rect: Dictionary = JSON.parse_string(jf.get_as_text())
	var mi: MeshInstance3D
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
			break
	if mi == null:
		return null
	var src := mi.get_active_material(0) as BaseMaterial3D
	if src == null or src.albedo_texture == null:
		return null
	var b := VeilFaceBake.new()
	b.material = ShaderMaterial.new()
	b.material.shader = SHADER
	b.material.set_shader_parameter("base_tex", src.albedo_texture)
	# the same texture with the painted brows and eyes wiped (filled with the skin above and below): under every expression, so no old feature survives beneath the new ones
	var bj := FileAccess.open("res://game/prototypes/npc_meshy/face_fit/%s_clean.json" % slug, FileAccess.READ)
	var clean_tex: Texture2D = src.albedo_texture
	if bj != null:
		var data: Dictionary = JSON.parse_string(bj.get_as_text())
		var img := Image.new()
		img.copy_from(src.albedo_texture.get_image())
		if img.is_compressed():
			img.decompress()
		var flat: Array = data["patch"]
		for i in range(0, flat.size(), 5):
			img.set_pixel(int(flat[i]), int(flat[i + 1]), Color8(int(flat[i + 2]), int(flat[i + 3]), int(flat[i + 4])))
		clean_tex = ImageTexture.create_from_image(img)
	b.material.set_shader_parameter("clean_tex", clean_tex)
	var tw: float = rect["tex"][0]
	var th: float = rect["tex"][1]
	b.material.set_shader_parameter("rect", Vector4(float(rect["x"]) / tw, float(rect["y"]) / th, float(rect["w"]) / tw, float(rect["h"]) / th))
	b.material.set_shader_parameter("amount", 0.0)
	for n in NAMES:
		b.patches[n] = load("res://game/prototypes/npc_meshy/face_bake/%s/patch_%s.png" % [slug, n])
	b.patches["neutral"] = null
	mi.set_surface_override_material(0, b.material)
	model.set_meta("face_bake", b)
	return b


## state: "neutral" (the original texture) or one of NAMES
func show(s: String) -> void:
	state = s
	if s == "neutral" or not patches.has(s) or patches[s] == null:
		material.set_shader_parameter("amount", 0.0)
		return
	material.set_shader_parameter("patch_tex", patches[s])
	material.set_shader_parameter("amount", 1.0)
