// THE VEIL - the tentacle beast's walk and head wobble, done entirely in the vertex shader (no skeleton: the Meshy mesh
// has none). Model space: the mesh is about 0.8 units across, centred on the origin; up is +Y. It is a crouched
// four-legged beast that FACES +Z: the toothed head and the mouth tentacles are at the front (z > 0.1, near x = 0),
// the four legs stand at the corners (|x| > 0.2), two curling tail tentacles rise from the back (y > 0.2).
//   * legs: the diagonal pairs lift and plant in turn (a trot-like crawl), reaching along the walk direction
//   * body: a slow heavy bob and a lean from side to side
//   * head: a slow, loose wobble in yaw / roll / pitch about the neck, with a sharp twitch now and then;
//     the mouth tentacles go with it
//   * tail tentacles: a slow sway that grows towards their tips
// The limbs shear and stretch rather than bend at joints. Set anim_time >= 0 to freeze the animation at that time
// (previews, tests); -1 uses the game clock.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float albedo_mul = 0.8;
uniform float anim_time = -1.0;
uniform float walk_speed = 1.1;          // step cycles per second
uniform vec3 walk_dir = vec3(0.0, 0.0, 1.0);    // the way it walks: the way it faces (model space, horizontal)
uniform float step_lift = 0.07;          // how high a limb comes up
uniform float step_swing = 0.06;         // how far a limb reaches along the walk direction
uniform float bob = 0.018;
uniform float lean = 0.03;
uniform float head_wobble = 1.0;         // 0 = still, 1 = as designed
uniform float leg_top = -0.02;
uniform float leg_bottom = -0.37;
uniform vec3 head_pivot = vec3(0.0, 0.05, 0.10);        // the neck
uniform float tail_sway = 0.05;

mat3 rot_y(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }
mat3 rot_z(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }
mat3 rot_x(float a) { float c = cos(a), s = sin(a); return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c)); }

void vertex() {
	float t = anim_time >= 0.0 ? anim_time : TIME;
	float ph = t * walk_speed * 6.28318;
	vec3 p = VERTEX;
	vec3 fwd = normalize(walk_dir);

	// body: rides the steps (a double-time bob) and leans over the planted side
	float body_w = smoothstep(leg_bottom, 0.05, p.y);
	p.y += sin(ph * 2.0) * bob * body_w;
	p.x += sin(ph) * lean * body_w;

	// legs: the four at the corners (|x| > 0.2); diagonal pairs alternate
	float leg_w = smoothstep(leg_top, leg_bottom, p.y) * smoothstep(0.12, 0.24, abs(p.x));
	float lp = ph + (p.x * p.z > 0.0 ? 0.0 : 3.14159);
	float lift = max(sin(lp), 0.0);
	p.y += lift * step_lift * leg_w;
	p += fwd * (cos(lp) * step_swing * leg_w);

	// tail tentacles: they sway more the higher up they are
	float tail_w = smoothstep(0.18, 0.39, p.y);
	p.x += sin(t * 0.9 + p.y * 9.0) * tail_sway * tail_w;
	p.z += cos(t * 0.7 + p.y * 7.0) * tail_sway * 0.6 * tail_w;

	// head and mouth tentacles: in front of the shoulders and near the middle, so the forelegs stay out of it
	float hw = smoothstep(0.08, 0.34, p.z) * (1.0 - smoothstep(0.10, 0.26, abs(p.x))) * head_wobble;
	float tw = pow(max(sin(t * 0.37 + 1.1), 0.0), 40.0);
	float yaw = (sin(t * 0.45) * 0.34 + sin(t * 0.93 + 1.3) * 0.12 + tw * 0.4) * hw;
	float roll = (sin(t * 0.37 + 0.5) * 0.24 + tw * 0.22) * hw;
	float pitch = (sin(t * 0.61 + 2.0) * 0.14 - tw * 0.2) * hw;
	p = rot_y(yaw) * rot_z(roll) * rot_x(pitch) * (p - head_pivot) + head_pivot;
	VERTEX = p;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * albedo_mul;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
