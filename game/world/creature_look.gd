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


## The Skitter: its own textures pushed down to charcoal / dirty dark bone (its atlas reads pale grey-white under
## the street lamps), dim fixed moonlight, no emission glow; it reads in the fog by silhouette and movement.
static func apply_skitter(c: Node3D, ground_y: float) -> int:
	return _apply(c, ground_y, {"conceal_start": 50.0, "conceal_end": 60.0, "dissolve_start": 900.0, "dissolve_end": 1000.0,
		"albedo_mul": 0.3, "key_energy": 0.42, "ambient": 0.2, "emission_energy": 0.0, "distance_fade": 0.045})


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


## (QA-005) The Skitter's shipped clips: Crawl (slow), Scuttle_Fast (fast), Idle_Twitch (still), Attack_Lunge.
## Plays the one for `mode` ("idle", "crawl", "scuttle", "attack"; "auto" picks by speed) with its playback speed
## matched to how fast the body actually moves (m/s). Returns the AnimationPlayer (or null).
const SKITTER_CLIPS := {"idle": "Idle_Twitch", "crawl": "Crawl", "scuttle": "Scuttle_Fast", "attack": "Attack_Lunge"}
const SKITTER_NATIVE := {"Crawl": 1.2, "Scuttle_Fast": 5.0}        # m/s each clip's stride covers at speed 1.0


static func skitter_anim(c: Node3D, mode: String, speed := 0.0, blend := 0.15) -> AnimationPlayer:
	var aps := c.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		return null
	var ap := aps[0] as AnimationPlayer
	if mode == "auto":
		mode = "idle" if speed < 0.15 else ("crawl" if speed < 2.4 else "scuttle")
	var clip: String = SKITTER_CLIPS.get(mode, "Idle_Twitch")
	if not ap.has_animation(clip):
		return ap
	var a := ap.get_animation(clip)
	if clip != "Attack_Lunge" and a.loop_mode == Animation.LOOP_NONE:
		a.loop_mode = Animation.LOOP_LINEAR
	ap.speed_scale = clampf(speed / float(SKITTER_NATIVE[clip]), 0.5, 2.2) if SKITTER_NATIVE.has(clip) else 1.0
	if ap.current_animation != clip:
		ap.play(clip, blend)
	return ap
