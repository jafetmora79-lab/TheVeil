shader_type spatial;
render_mode cull_back;
// THE VEIL - a head texture with baked expression patches (see face_bake.gd). The same look as the game's PSX character materials: nearest filtering, rough, no specular.
uniform sampler2D base_tex : source_color, filter_nearest;
uniform sampler2D clean_tex : source_color, filter_nearest;
uniform sampler2D patch_tex : source_color, filter_nearest;
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);     // the patch's place in the texture (uv: x, y, w, h)
uniform float amount = 0.0;

void fragment() {
	vec4 b = texture(base_tex, UV);
	vec3 col = b.rgb;
	if (amount > 0.0) {
		col = texture(clean_tex, UV).rgb;      // an expression: the texture with the old brows and eyes wiped
	}
	vec2 q = (UV - rect.xy) / rect.zw;
	if (amount > 0.0 && q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0) {
		vec4 p = texture(patch_tex, q);
		col = mix(col, p.rgb, p.a * amount);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
