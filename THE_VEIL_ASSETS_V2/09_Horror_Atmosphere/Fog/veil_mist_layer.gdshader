// THE VEIL - mist layer (Compatibility renderer safe: no depth/screen textures, no volumetrics).
// Horizontal sheets of slowly crawling, pixel-quantised noise. Alpha fades near the camera (avoids heavy
// overdraw in the player's face) and towards the sheet edge, so a few stacked sheets read as deep layered mist.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform vec4 mist_color : source_color = vec4(0.62, 0.66, 0.64, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float noise_scale = 0.045;          // noise tiles per metre
uniform vec2 drift = vec2(0.012, 0.007);    // tiles per second (slow, unsettling crawl)
uniform float near_fade = 2.5;              // metres: fully transparent at the camera
uniform float near_full = 9.0;
uniform float far_fade = 55.0;              // metres from the sheet centre where it fades out
uniform float pixel_steps = 6.0;            // alpha quantisation (pixel-art banding)

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * noise_scale;
	float n1 = texture(noise_tex, p + drift * TIME).r;
	float n2 = texture(noise_tex, p * 2.3 - drift.yx * TIME * 1.7 + vec2(0.37, 0.11)).r;
	float n = clamp(n1 * 0.65 + n2 * 0.55 - 0.18, 0.0, 1.0);
	n = floor(n * pixel_steps) / pixel_steps;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float d = distance(world_pos, cam);
	float near_a = smoothstep(near_fade, near_full, d);
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float edge_a = 1.0 - smoothstep(far_fade * 0.6, far_fade, distance(world_pos.xz, centre.xz));
	ALBEDO = mist_color.rgb * (0.88 + 0.12 * n);
	ALPHA = clamp(n * density * near_a * edge_a, 0.0, 0.92);
}
