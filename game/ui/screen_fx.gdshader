// THE VEIL - full-screen "film look" (CanvasLayer under the HUD, Compatibility-renderer safe):
// a soft vignette, a faint barrel curve, a whisper of colour fringing toward the edges, and fine moving film grain
// that is stronger in the shadows. `danger` (0..1) deepens the vignette and pulls the colour toward red as health falls.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.36;
uniform float smoothness = 0.64;
uniform float grain = 0.05;
uniform float distortion = 0.02;
uniform float aberration = 0.0012;
uniform float danger = 0.0;
uniform float bloom = 0.32;             // soft glow around bright lights (the Compatibility renderer has no built-in glow)
uniform float bloom_threshold = 0.74;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	vec2 duv = clamp(0.5 + c * (1.0 + distortion * r2 * 4.0), vec2(0.001), vec2(0.999));
	vec2 ab = c * aberration * 4.0;
	vec3 col = vec3(texture(screen_tex, duv + ab).r, texture(screen_tex, duv).g, texture(screen_tex, duv - ab).b);
	// bloom: 16 taps on two rings round the pixel, only the part above the threshold, added back softly
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 dir = vec2(cos(a) * SCREEN_PIXEL_SIZE.x, sin(a) * SCREEN_PIXEL_SIZE.y);
		glow += max(texture(screen_tex, duv + dir * 5.0).rgb - vec3(bloom_threshold), vec3(0.0));
		glow += max(texture(screen_tex, duv + dir * 13.0).rgb - vec3(bloom_threshold), vec3(0.0)) * 0.7;
	}
	col += glow * bloom / 8.0;
	// vignette: 0 in the middle of the screen, 1 in the corners
	float d = length(c) * 1.4142;
	float vig = smoothstep(1.0 - smoothness, 1.0, d);
	col *= 1.0 - (vignette + danger * 0.35) * vig;
	// pain: the edges flush red
	col = mix(col, col * vec3(1.25, 0.55, 0.5), danger * vig * 0.6);
	// film grain, re-seeded every few frames, a little heavier in the dark
	vec2 seed = floor(FRAGCOORD.xy) + floor(TIME * 24.0) * vec2(37.0, 17.0);
	float n = hash(seed) - 0.5;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col += n * grain * (1.15 - lum);
	COLOR = vec4(col, 1.0);
}
