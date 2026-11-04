// THE VEIL - soft pulsing rim highlight, used as a material_overlay on objectives (groceries, doors, NPCs).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.32, 1.0);
uniform float strength = 0.85;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float pulse = 0.55 + 0.45 * sin(TIME * 3.2);
	ALBEDO = glow_color.rgb * (rim * 0.9 + 0.12) * pulse * strength;
}
