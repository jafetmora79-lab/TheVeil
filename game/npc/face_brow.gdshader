shader_type spatial;
render_mode cull_disabled;
// THE VEIL - an eyebrow strip: the model's own painted brow (its original UV texture; only the dark brow pixels are drawn) on a thin strip of geometry that can lift, drop and
// tilt. UV2.x = 0 at the inner end, 1 at the outer end; COLOR = the direction toward the nose (remapped), NORMAL = the face's forward.
uniform sampler2D tex : filter_nearest;      // raw sRGB values: the darkness test is on the painted colour
uniform sampler2D tex_lin : source_color, filter_nearest;   // the same texture, decoded for lighting
uniform vec3 up_local = vec3(0.0, 1.0, 0.0);
uniform float lift_in = 0.0;
uniform float lift_out = 0.0;
uniform float shift_in = 0.0;
uniform float alpha_lo = 0.30;
uniform float alpha_hi = 0.42;

void vertex() {
	float t = UV2.x;
	vec3 inward = COLOR.rgb * 2.0 - 1.0;
	VERTEX += up_local * mix(lift_in, lift_out, t) + inward * shift_in * (1.0 - t);
}

void fragment() {
	vec4 c = texture(tex, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	ALPHA = 1.0 - smoothstep(alpha_lo, alpha_hi, lum);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = texture(tex_lin, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
