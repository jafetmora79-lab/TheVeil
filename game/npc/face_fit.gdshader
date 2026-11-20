shader_type spatial;
render_mode cull_back;
// THE VEIL - the face of a Mixamo-rigged NPC: an expression image where the expression changes something (mask), the model's own painted face (UV2) everywhere else.
uniform sampler2D face_tex : source_color, filter_nearest;
uniform sampler2D orig_tex : source_color, filter_nearest;
uniform sampler2D mask_tex : filter_linear;
uniform vec3 tint = vec3(1.0);
uniform float amount = 0.0;
uniform vec3 skin_col = vec3(0.6, 0.33, 0.18);
uniform sampler2D eye_tex : filter_linear;
uniform float blink = 0.0;
uniform float blink_eyes_only = 0.0;      // 1 for a kit set: a blink changes only the eyes, the rest of the face stays
uniform float blink_line_v = 0.505;

void fragment() {
	vec3 o = texture(orig_tex, UV2).rgb;
	vec3 fc = texture(face_tex, UV).rgb;
	float tl = dot(fc, vec3(0.3, 0.59, 0.11));
	vec3 f = fc * mix(tint, vec3(1.0), smoothstep(0.62, 0.82, tl));      // the skin tint stops at the eye whites
	// a blink: the whole painted eye becomes lid skin; only the lash line (dark pixels below blink_line_v) is kept from the image, not the pupil remnants above it
	float lash = (1.0 - smoothstep(0.18, 0.32, tl)) * smoothstep(blink_line_v, blink_line_v + 0.012, UV.y);
	f = mix(f, mix(skin_col, f, lash), blink * (1.0 - blink_eyes_only) * step(0.5, texture(eye_tex, UV).r));
	float eyes_only = step(0.5, texture(eye_tex, UV).r);
	float m = smoothstep(0.35, 0.65, texture(mask_tex, UV).r) * amount * mix(1.0, eyes_only, blink_eyes_only);
	ALBEDO = mix(o, f, m);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
