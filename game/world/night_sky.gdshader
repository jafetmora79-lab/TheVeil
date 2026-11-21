// The night sky before the Veil: stars (some twinkling), a moon with a halo and a few drifting clouds.
// Drawn additively on a dome that follows the camera, over the dark procedural sky; fog never touches it.
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 moon_dir = vec3(0.3, 0.6, 0.7);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float star_density : hint_range(0.0, 1.0) = 0.9;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec3 d = normalize(VERTEX);
	float up = smoothstep(-0.02, 0.12, d.y);              // nothing below / on the horizon
	vec3 md = normalize(moon_dir);

	// ---- clouds: a few thin banks, moving slowly; they dim what is behind them
	vec2 cuv = d.xz / (d.y + 0.35) * 1.15 + vec2(TIME * 0.006, TIME * 0.0025);
	float dens = fbm(cuv);
	float cloud = smoothstep(1.0 - cloud_cover * 0.55, 1.0 - cloud_cover * 0.55 + 0.16, dens) * smoothstep(0.02, 0.3, d.y);
	float near_moon = pow(max(dot(d, md), 0.0), 6.0);
	vec3 cloud_col = mix(vec3(0.03, 0.04, 0.07), vec3(0.34, 0.40, 0.52), near_moon) * (0.55 + 0.9 * (1.0 - dens));

	// ---- stars: hard little points on a 3D grid, a few brighter and tinted, a slow twinkle
	vec3 sp = d * 150.0;
	vec3 cell = floor(sp);
	vec3 f = fract(sp) - 0.5;
	float h = hash13(cell);
	vec3 jit = vec3(hash13(cell + 7.3), hash13(cell + 13.7), hash13(cell + 23.1)) - 0.5;
	float present = step(1.0 - 0.045 * star_density, h);
	float r = length(f - jit * 0.55);
	float size = 0.10 + 0.12 * hash13(cell + 41.0);
	float star = present * smoothstep(size, size * 0.25, r);
	float tw = 0.75 + 0.25 * sin(TIME * (1.5 + 4.0 * hash13(cell + 3.0)) + h * 60.0);
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.92, 0.78), hash13(cell + 5.0));
	vec3 stars = tint * star * tw * (0.55 + 1.2 * hash13(cell + 9.0));
	// the very dense backdrop of faint stars (the milky dust)
	vec3 sp2 = d * 330.0;
	vec3 c2 = floor(sp2);
	float dust = step(0.985, hash13(c2 + 101.0)) * smoothstep(0.22, 0.05, length(fract(sp2) - 0.5));
	stars += vec3(0.5, 0.58, 0.75) * dust * 0.35;
	stars *= (1.0 - cloud * 0.9);

	// ---- moon: a disc with a few dark seas, a halo, and a glow in the haze round it
	float md_dot = dot(d, md);
	float ang = acos(clamp(md_dot, -1.0, 1.0));
	float R = 0.052;                                      // (the real one is 0.0045 rad: this is for show)
	vec3 up_v = abs(md.y) > 0.95 ? vec3(1, 0, 0) : vec3(0, 1, 0);
	vec3 tx = normalize(cross(up_v, md));
	vec3 ty = cross(md, tx);
	vec2 mp = vec2(dot(d, tx), dot(d, ty)) / R;
	float disc = smoothstep(1.0, 0.94, length(mp));
	float seas = fbm(mp * 2.6 + 3.0);
	float surface = 0.78 + 0.35 * smoothstep(0.35, 0.65, seas) - 0.25 * smoothstep(0.55, 0.85, fbm(mp * 7.0));
	// a gibbous phase: the shadowed limb is cut by a second disc
	float shade = smoothstep(0.0, 0.5, 1.0 - length(mp - vec2(-0.55, 0.12)) * 0.0 + (mp.x * 0.35 + 0.35));
	vec3 moon = vec3(0.92, 0.95, 1.0) * disc * surface * clamp(shade, 0.25, 1.0) * 1.6;
	float halo = exp(-ang * 26.0) * 0.55 + exp(-ang * 7.0) * 0.14;
	moon += vec3(0.45, 0.56, 0.8) * halo;
	moon *= (1.0 - cloud * 0.65);

	vec3 col = stars + moon + cloud * cloud_col;
	// a faint paler band low in the sky (distant town glow / haze)
	col += vec3(0.035, 0.04, 0.06) * pow(1.0 - clamp(d.y, 0.0, 1.0), 6.0);
	ALBEDO = col * up * fade;
	ALPHA = 1.0;
}
