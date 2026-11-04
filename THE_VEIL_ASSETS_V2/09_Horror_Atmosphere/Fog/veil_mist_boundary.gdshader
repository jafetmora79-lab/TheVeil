// THE VEIL - mist boundary curtain: a recognisable wall where normal Greyhaven ends and the Veil begins.
// Vertical columns of crawling noise, densest at ground level, cold-tinted, slowly breathing.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.55, 0.60, 0.62, 1.0);
uniform vec4 edge_color : source_color = vec4(0.30, 0.32, 0.40, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.85;
uniform float rise_speed = 0.03;
uniform float breathe = 0.15;
uniform float pixel_steps = 5.0;
uniform float curtain_height = 14.0;     // mesh height (centred on its origin, like CylinderMesh)

varying float local_h;

void vertex() {
	local_h = clamp((VERTEX.y + curtain_height * 0.5) / curtain_height, 0.0, 1.0);   // 0 at the ground
}

void fragment() {
	vec2 uv = UV * vec2(6.0, 1.0);
	float n1 = texture(noise_tex, vec2(uv.x, uv.y * 0.6 - TIME * rise_speed)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 1.7 + 0.3, uv.y * 1.1 + TIME * rise_speed * 0.6)).r;
	float n = clamp(n1 * 0.7 + n2 * 0.5 - 0.1, 0.0, 1.0);
	n = floor(n * pixel_steps) / pixel_steps;
	float height_fade = 1.0 - smoothstep(0.25, 1.0, local_h);
	float pulse = 1.0 - breathe + breathe * sin(TIME * 0.35 + UV.x * 6.2831);
	ALBEDO = mix(edge_color.rgb, base_color.rgb, n);
	ALPHA = clamp((0.35 + 0.65 * n) * height_fade * density * pulse, 0.0, 0.95);
}
