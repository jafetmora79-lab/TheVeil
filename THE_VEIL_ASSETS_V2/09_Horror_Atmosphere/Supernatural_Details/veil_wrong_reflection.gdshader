// THE VEIL - "wrong" reflection for windows and mirrors (no screen texture needed).
// A dim, cold glass with a slow distortion band and a faint dark smear that drifts against the viewing
// direction - the reflection never quite matches the room. Subtle by default (strength 0.35).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D glass_tex : source_color, filter_nearest;
uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(0.32, 0.38, 0.40, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform float speed = 0.05;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec2 uv = UV;
	float band = texture(noise_tex, vec2(uv.y * 0.8 + TIME * speed, 0.5)).r;
	uv.x += (band - 0.5) * 0.06 * strength;
	vec3 g = texture(glass_tex, uv).rgb;
	float smear = texture(noise_tex, uv * 1.5 + vec2(-VIEW.x * 0.25, TIME * speed * 0.5)).r;
	smear = step(0.72, smear) * strength;
	ALBEDO = mix(g * tint.rgb, vec3(0.02, 0.02, 0.03), smear * 0.8);
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = tint.rgb * 0.05 * (1.0 - facing) * (1.0 - smear);
	ALPHA = 0.88;
}
