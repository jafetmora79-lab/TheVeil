shader_type spatial;
render_mode cull_back;
// THE VEIL - the face of a Mixamo-rigged NPC: an expression image where the expression changes something (mask), the model's own painted face (UV2) everywhere else.
uniform sampler2D face_tex : source_color, filter_nearest;
uniform sampler2D orig_tex : source_color, filter_nearest;
uniform sampler2D mask_tex : filter_linear;
uniform vec3 tint = vec3(1.0);
uniform float amount = 0.0;

void fragment() {
	vec3 o = texture(orig_tex, UV2).rgb;
	vec3 f = texture(face_tex, UV).rgb * tint;
	float m = smoothstep(0.35, 0.65, texture(mask_tex, UV).r) * amount;
	ALBEDO = mix(o, f, m);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
