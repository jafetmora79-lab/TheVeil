// THE VEIL - the tentacle beast's walk and head wobble, done entirely in the vertex shader (no skeleton: the Meshy mesh
// has none). Model space: the mesh is about 0.8 units across, centred on the origin; up is +Y. It is a crouched
// four-legged beast that FACES +Z: the toothed head and the mouth tentacles are at the front (z > 0.1, near x = 0),
// the four legs stand at the corners (|x| > 0.2), two curling tail tentacles rise from the back (y > 0.2).
//   * legs: each leg is rotated about its hip (swing) and its knee (fold). A planted foot moves BACK along the body at
//     exactly the ground speed (it does not slide), then the knee folds, the foot lifts and swings forward. Diagonal
//     pairs alternate (a slow trot). The body must travel at ground_speed = 4 * step_swing * walk_speed (model units/s).
//   * body: a slow heavy bob and a lean from side to side
//   * head: a slow, loose wobble in yaw / roll / pitch about the neck, with a sharp twitch now and then;
//     the mouth tentacles go with it
//   * tail tentacles: a slow sway that grows towards their tips
// The legs are bent by rotating the mesh around the hip / knee points, so they stay solid but the skin stretches a
// little where the leg meets the body. Set anim_time >= 0 to freeze the animation at that time (previews, tests).
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float albedo_mul = 0.8;
uniform float anim_time = -1.0;
uniform float walk_speed = 0.5;          // step cycles per second (one leg's full step)
uniform float step_swing = 0.065;        // the foot moves +-step_swing (model units) along the body
uniform float knee_fold = 0.7;           // radians the lower leg folds when a foot is lifted
uniform float bob = 0.012;
uniform float lean = 0.02;
uniform float head_wobble = 1.0;         // 0 = still, 1 = as designed
uniform vec3 head_pivot = vec3(0.0, 0.05, 0.10);        // the neck
uniform float tail_sway = 0.05;
const vec3 HIP = vec3(0.25, 0.04, 0.18);                 // per leg: x and z are mirrored by the quadrant
const vec3 KNEE = vec3(0.27, -0.17, 0.33);
const float LEG_LEN = 0.42;              // hip to foot
const float LOWER_LEN = 0.21;            // knee to foot

mat3 rot_y(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }
mat3 rot_z(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }
mat3 rot_x(float a) { float c = cos(a), s = sin(a); return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c)); }

void vertex() {
	float t = anim_time >= 0.0 ? anim_time : TIME;
	float ph = t * walk_speed * 6.28318;
	vec3 p = VERTEX;

	// body: rides the steps (a double-time bob) and leans over the planted side
	float body_w = smoothstep(-0.37, 0.05, p.y);
	p.y += sin(ph * 2.0) * bob * body_w;
	p.x += sin(ph) * lean * body_w;

	// legs: quadrant by the signs of x and z; only outside the torso (|x|) and away from the middle (|z|)
	float side = p.x >= 0.0 ? 1.0 : -1.0;
	float fb = p.z >= 0.0 ? 1.0 : -1.0;
	float gate = smoothstep(0.12, 0.22, abs(p.x)) * smoothstep(0.02, 0.10, abs(p.z));
	float u = fract(t * walk_speed + (side * fb > 0.0 ? 0.0 : 0.5));
	float foot_z;       // how far forward the foot is (model units), + forward
	float lift = 0.0;
	if (u < 0.5) {
		foot_z = step_swing * (1.0 - 4.0 * u);                 // planted: backward, at constant speed
	} else {
		float s = (u - 0.5) * 2.0;
		foot_z = step_swing * (-1.0 + 2.0 * smoothstep(0.0, 1.0, s));   // swinging forward, eased
		lift = sin(3.14159 * s);
	}
	float beta = knee_fold * lift;                              // knee fold (the foot goes back and up)
	float alpha = -(foot_z + LOWER_LEN * sin(beta)) / LEG_LEN;  // hip swing, enough to put the foot at foot_z
	vec3 kp = vec3(KNEE.x * side, KNEE.y, KNEE.z * fb);
	vec3 hp = vec3(HIP.x * side, HIP.y, HIP.z * fb);
	float knee_w = smoothstep(-0.10, -0.22, p.y) * gate;
	float hip_w = smoothstep(0.08, -0.06, p.y) * gate;
	p = rot_x(beta * knee_w) * (p - kp) + kp;
	p = rot_x(alpha * hip_w) * (p - hp) + hp;

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
