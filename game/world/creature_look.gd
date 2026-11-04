extends RefCounted
class_name VeilCreatureLook
## THE VEIL - how the giant creatures are drawn in the town (one place, used by the supermarket encounter and the
## death cinematic). The Colossus (and, with apply_ground, the Hounds) keeps its own Pack 07 textures but goes through colossus_veil.gdshader: dim fixed
## moonlight (street lamps cannot blow its huge low-texel faces out to white), dark dirty bone instead of the
## atlas's light bone colours, contrast and colour sinking into the mist with height and distance, and the upper
## leg dissolving into the mist ceiling. Scene fog still applies on top.

const VEIL_SHADER := preload("res://game/world/colossus_veil.gdshader")


static func apply_colossus(c: Node3D, ground_y: float) -> int:
	return _apply(c, ground_y, {})


## Street-level creatures (Hounds): the same controlled look - their own textures, dim fixed moonlight instead of
## lamp blow-out, fading into the mist with distance - but no height concealment (they are never tall).
static func apply_ground(c: Node3D, ground_y: float) -> int:
	return _apply(c, ground_y, {"conceal_start": 50.0, "conceal_end": 60.0, "dissolve_start": 900.0, "dissolve_end": 1000.0,
		"albedo_mul": 0.8, "key_energy": 0.6, "ambient": 0.3, "emission_energy": 0.2})


static func _apply(c: Node3D, ground_y: float, params: Dictionary) -> int:
	var n := 0
	for mi in c.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i) as BaseMaterial3D
			var sm := ShaderMaterial.new()
			sm.shader = VEIL_SHADER
			if src:
				sm.set_shader_parameter("albedo_tex", src.albedo_texture)
				sm.set_shader_parameter("emission_tex", src.emission_texture if src.emission_enabled else null)
			sm.set_shader_parameter("ground_y", ground_y)
			for k in params:
				sm.set_shader_parameter(k, params[k])
			m.set_surface_override_material(i, sm)
			n += 1
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n
