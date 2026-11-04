// THE VEIL - Colossus encounter look (localized cinematic treatment; the rest of the game's fog is untouched).
// The creature's own textures with controlled, dim lighting: one cold moon key + ambient, computed here and
// rendered unshaded, so no street or store light can blow its huge low-texel faces out to white.
// Vertical concealment (world height above the road):
//   ground .. conceal_start : dark, textured, full contrast (the foot and lower leg read clearly)
//   conceal_start .. end    : contrast drops and the colour sinks into the mist colour (details go indistinct)
//   dissolve_start .. end   : ordered-dither discard - the leg vanishes into the mist ceiling; the body never shows
// Compatibility / Web safe: no screen or depth texture reads, opaque (no sorting issues on a skinned mesh).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D emission_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform float ground_y = 0.0;
uniform float conceal_start = 3.0;
uniform float conceal_end = 13.0;
uniform float dissolve_start = 10.0;
uniform float dissolve_end = 17.0;
uniform vec3 mist_col : source_color = vec3(0.11, 0.125, 0.13);
uniform vec3 key_dir = vec3(-0.35, 0.8, 0.45);      // towards the moon (world space)
uniform float key_energy = 0.55;
uniform float ambient = 0.32;
uniform float emission_energy = 0.12;           // the plate seams only hint at a glow
uniform float albedo_mul = 0.55;                // the atlas's bone / plate colours read as dirty, dark bone
uniform float distance_fade = 0.035;            // extra fade into the mist with distance (on top of the scene fog)

varying float world_y;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float h = world_y - ground_y;
	float d = clamp((h - dissolve_start) / max(dissolve_end - dissolve_start, 0.001), 0.0, 1.0);
	int idx = int(mod(FRAGCOORD.x, 4.0)) + int(mod(FRAGCOORD.y, 4.0)) * 4;
	if (d > (BAYER[idx] + 0.5) / 16.0) {
		discard;
	}
	vec3 tex = texture(albedo_tex, UV).rgb * albedo_mul;
	tex = mix(tex, vec3(dot(tex, vec3(0.3, 0.59, 0.11))), 0.35);
	vec3 lv = normalize((VIEW_MATRIX * vec4(normalize(key_dir), 0.0)).xyz);
	float lam = max(dot(normalize(NORMAL), lv), 0.0);
	vec3 col = tex * (ambient + key_energy * lam) + texture(emission_tex, UV).rgb * emission_energy;
	float c = smoothstep(conceal_start, conceal_end, h);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum), c * 0.7);                 // contrast / saturation drop with height
	col = mix(col, mist_col, c * 0.85);                  // sinking into the mist colour (never brighter than it)
	float dist = length(VERTEX);                         // view space: distance from the camera
	col = mix(col, mist_col, clamp(1.0 - exp(-distance_fade * dist), 0.0, 0.9));
	ALBEDO = col;
}
