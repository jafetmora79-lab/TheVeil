// Menu-only adaptation of Pack 09 veil_mist_layer: same noise and quantised drift.
// Static in-game photograph underneath; two texture samples, no screen/depth reads.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec4 mist_color : source_color = vec4(0.38, 0.41, 0.40, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.62;
uniform vec2 drift = vec2(0.012, 0.007);
void fragment() {
	vec2 uv = floor(UV * vec2(640.0, 360.0)) / vec2(640.0, 360.0);
	vec2 p = uv * vec2(2.0, 1.2);
	float n1 = texture(noise_tex, p + drift * TIME).r;
	float n2 = texture(noise_tex, p * 2.3 - drift.yx * TIME * 1.7 + vec2(0.37, 0.11)).r;
	float n = clamp(n1 * 0.65 + n2 * 0.55 - 0.18, 0.0, 1.0);
	n = floor(n * 12.0) / 12.0;
	float ground = smoothstep(0.20, 0.85, uv.y);
	float alpha = n * density * (0.25 + 0.75 * ground);
	COLOR = vec4(mist_color.rgb * (0.88 + 0.12 * n), alpha);
}
