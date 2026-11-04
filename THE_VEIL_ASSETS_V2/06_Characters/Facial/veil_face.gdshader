// THE VEIL - pixel-art face compositing for the approved character heads (Godot 4, Compatibility-safe).
// The approved head texture is drawn unchanged, except two small pixel windows (brows + eyes, mouth) that are fetched
// from the character's face atlas at the current expression / eye-action / viseme cell. Nearest texel fetches keep the
// pixel art exact; the head mesh, UVs and skinning are untouched.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D base_tex : source_color, filter_nearest;
uniform sampler2D face_atlas : source_color, filter_nearest;
uniform vec4 upper_rect = vec4(44.0, 17.0, 42.0, 19.0);   // x, y, w, h in head-texture pixels
uniform vec4 mouth_rect = vec4(52.0, 41.0, 26.0, 11.0);
uniform vec2 mouth_origin = vec2(0.0, 152.0);              // atlas pixel origin of the mouth grid
uniform vec2 upper_cell = vec2(0.0);                       // (expression, eye action)
uniform vec2 mouth_cell = vec2(0.0);                       // (expression, viseme)
uniform float roughness_value = 0.92;
uniform float specular_value = 0.3;

void fragment() {
	ivec2 bs = textureSize(base_tex, 0);
	ivec2 px = clamp(ivec2(floor(UV * vec2(bs))), ivec2(0), bs - ivec2(1));
	vec4 c = texelFetch(base_tex, px, 0);
	vec2 p = vec2(px);
	if (p.x >= upper_rect.x && p.y >= upper_rect.y && p.x < upper_rect.x + upper_rect.z && p.y < upper_rect.y + upper_rect.w) {
		vec2 a = upper_cell * upper_rect.zw + (p - upper_rect.xy);
		c = texelFetch(face_atlas, ivec2(a), 0);
	} else if (p.x >= mouth_rect.x && p.y >= mouth_rect.y && p.x < mouth_rect.x + mouth_rect.z && p.y < mouth_rect.y + mouth_rect.w) {
		vec2 a = mouth_origin + mouth_cell * mouth_rect.zw + (p - mouth_rect.xy);
		c = texelFetch(face_atlas, ivec2(a), 0);
	}
	ALBEDO = c.rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	METALLIC = 0.0;
}
