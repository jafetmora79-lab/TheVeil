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

#include "res://game/enemies/tentacle_beast_walk.gdshaderinc"

void vertex() {
	float t = anim_time >= 0.0 ? anim_time : TIME;
	VERTEX = beast_walk(VERTEX, t);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * albedo_mul;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
}
