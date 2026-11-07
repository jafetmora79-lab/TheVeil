// THE VEIL - collectible highlight (material_overlay): a faint warm rim that pulses slowly, strongest at the
// silhouette. Additive, unshaded, cheap (Compatibility / Web / Android). Applied only while the player aims at it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec3 rim_color : source_color = vec3(1.0, 0.82, 0.5);
uniform float strength = 0.5;

void fragment() {
	float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	ALBEDO = rim_color * (0.12 + pow(rim, 2.0) * 0.9) * strength * pulse;
}
