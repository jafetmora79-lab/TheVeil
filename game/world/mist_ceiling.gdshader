// THE VEIL - mist ceiling layer: a huge horizontal sheet of churning, unnatural mist (unshaded, alpha blended,
// value-noise fbm in world space, slow drift). Four of these stacked 9-20 m up swallow anything taller than the
// houses when seen from below. Cheap: no textures, no screen / depth reads (Compatibility + Web friendly).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.24, 0.26, 0.27, 1.0);
uniform float density = 0.6;
uniform float seed = 0.0;
uniform float scale = 0.035;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * vnoise(p); p = p * 2.03 + vec2(13.1, 7.7); a *= 0.5; }
	return v;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * scale;
	float t = TIME * 0.025;
	float n = fbm(p + vec2(t, -t * 0.7)) * 0.65 + fbm(p * 2.1 - vec2(t * 1.3, t * 0.4)) * 0.35;
	float edge = 1.0 - smoothstep(0.32, 0.5, length(UV - vec2(0.5)));          // fade before the sheet ends
	float a = smoothstep(0.28, 0.78, n) * density * edge;
	ALBEDO = tint.rgb * (0.85 + 0.3 * n);
	ALPHA = clamp(a, 0.0, 0.92);
}
