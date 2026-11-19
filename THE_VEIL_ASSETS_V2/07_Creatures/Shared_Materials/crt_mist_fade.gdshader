// THE VEIL - Pack 07: creature material that dithers out below the mist surface.
// Compatibility-renderer safe: no screen / depth texture reads, no transparency (ordered-dither discard keeps the
// pixel-art look and avoids sorting problems with skinned meshes).
// Used by VeilMistTentacle (veil_mist_tentacle.gd), which copies the textures of the imported .tres materials.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D emission_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float emission_energy = 0.5;
uniform float roughness_v = 0.8;
// 0 = hidden, 1 = fully visible
uniform float visibility : hint_range(0.0, 1.0) = 1.0;
// world-space height of the mist surface the tentacle emerges from
uniform float mist_level = 0.0;
// metres above mist_level over which the tentacle dithers in
uniform float fade_height = 0.6;

varying float world_y;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	EMISSION = texture(emission_tex, UV).rgb * emission_energy;
	ROUGHNESS = roughness_v;
	float h = clamp((world_y - mist_level) / max(fade_height, 0.001), 0.0, 1.0);
	float alpha = h * visibility;
	int idx = int(mod(FRAGCOORD.x, 4.0)) + int(mod(FRAGCOORD.y, 4.0)) * 4;
	if (alpha < (BAYER[idx] + 0.5) / 16.0) {
		discard;
	}
}
