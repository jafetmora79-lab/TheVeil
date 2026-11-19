// THE VEIL - the tentacle beast in the Colossus encounter: the beast's own walk (tentacle_beast_walk.gdshaderinc) with the
// Colossus's dark, dim, mist-swallowed look (same fragment as game/world/colossus_veil.gdshader, so the street, store
// and mist lights cannot blow it out): dark and textured at the road, the colour and contrast sinking into the mist
// with height, an ordered dither dissolving the body into the mist ceiling, and far_hide for the staging.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float anim_time = 0.0;           // always driven by the encounter (the beast's own clock), never TIME
uniform float ground_y = 0.0;
uniform float conceal_start = 3.0;
uniform float conceal_end = 13.0;
uniform float dissolve_start = 10.0;
uniform float dissolve_end = 17.0;
uniform vec3 mist_col : source_color = vec3(0.11, 0.125, 0.13);
uniform vec3 key_dir = vec3(-0.35, 0.8, 0.45);
uniform float key_energy = 0.6;
uniform float ambient = 0.34;
uniform float albedo_mul = 0.75;
uniform float distance_fade = 0.035;
uniform float far_hide = 100000.0;

#include "res://game/enemies/tentacle_beast_walk.gdshaderinc"

varying float world_y;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	VERTEX = beast_walk(VERTEX, anim_time);
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float h = world_y - ground_y;
	float d = clamp((h - dissolve_start) / max(dissolve_end - dissolve_start, 0.001), 0.0, 1.0);
	d = max(d, clamp((length(VERTEX) - far_hide) / 12.0, 0.0, 1.0));
	int idx = int(mod(FRAGCOORD.x, 4.0)) + int(mod(FRAGCOORD.y, 4.0)) * 4;
	if (d > (BAYER[idx] + 0.5) / 16.0) {
		discard;
	}
	vec3 tex = texture(albedo_tex, UV).rgb * albedo_mul;
	tex = mix(tex, vec3(dot(tex, vec3(0.3, 0.59, 0.11))), 0.25);
	vec3 lv = normalize((VIEW_MATRIX * vec4(normalize(key_dir), 0.0)).xyz);
	float lam = max(dot(normalize(NORMAL), lv), 0.0);
	vec3 col = tex * (ambient + key_energy * lam);
	float c = smoothstep(conceal_start, conceal_end, h);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum), c * 0.7);
	col = mix(col, mist_col, c * 0.85);
	float dist = length(VERTEX);
	col = mix(col, mist_col, clamp(1.0 - exp(-distance_fade * dist), 0.0, 0.9));
	ALBEDO = col;
}
