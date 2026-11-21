shader_type spatial;
render_mode vertex_lighting, cull_back;
// THE VEIL - wind in the trees and the grass. Same look as the original material (its albedo texture, per-vertex lighting, scissor alpha); the vertices bend
// from the ground up: slow gusts that sweep through the woods (each instance at its own phase, from its world position), a faster flutter in the leaves.
// `veil_wind` (a global) is 1 on a normal evening and rises after the Veil comes (the trees thrash).
global uniform float veil_wind;
uniform sampler2D albedo_tex : source_color, FILTER_HINT, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float height = 8.0;          // the model's height (m): what "the top" is
uniform float bend = 0.045;          // sideways travel of the top, as a fraction of the height, at wind 1
uniform float flutter = 0.35;        // leaf shake (m at the top)
uniform bool scissor = false;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float up = clamp(VERTEX.y / height, 0.0, 1.5);
	float k = up * up;
	float ph = origin.x * 0.31 + origin.z * 0.23;
	float gust = sin(TIME * 0.55 + ph) * 0.6 + sin(TIME * 1.3 + ph * 1.7) * 0.4 + 0.35 * sin(TIME * 0.17 + origin.x * 0.02 + origin.z * 0.015);
	float w = veil_wind;
	vec3 sway = vec3(gust * bend * height * w, 0.0, (gust * 0.55 + sin(TIME * 0.8 + ph * 0.6) * 0.3) * bend * height * w * 0.8);
	vec3 leaf = vec3(sin(TIME * 5.1 + VERTEX.x * 3.0 + ph), sin(TIME * 4.3 + VERTEX.z * 3.0 + ph * 1.3) * 0.4, sin(TIME * 4.7 + VERTEX.y * 2.0 + ph * 0.7)) * flutter * k * w * 0.5;
	VERTEX += (sway + leaf) * k;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * tint;
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	if (scissor) {
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		ALPHA = c.a;
	}
}
