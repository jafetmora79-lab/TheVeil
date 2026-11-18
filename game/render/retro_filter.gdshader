shader_type canvas_item;
// THE VEIL - full-screen PS1-style pass (game/autoload/retro_filter.gd). Works in the Compatibility renderer:
// the finished 3D frame is read back, drawn in big square pixels (`lines` tall), and its colour depth is cut to
// `levels` steps per channel (32 = the PlayStation's 15-bit colour) with a 4x4 ordered dither, so the fog and
// dark gradients break into the period's dotted bands instead of smooth ramps.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float lines = 300.0;        // virtual screen height in pixels (0 = full resolution)
uniform float levels = 32.0;        // colour steps per channel
uniform float dither = 1.0;         // 0..1 strength of the ordered dither

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 ssize = 1.0 / SCREEN_PIXEL_SIZE;
	float px = lines > 0.0 ? max(floor(ssize.y / lines), 1.0) : 1.0;   // whole screen pixels per virtual pixel
	vec2 cell = floor(FRAGCOORD.xy / px);
	vec2 uv = (cell * px + 0.5 * px) * SCREEN_PIXEL_SIZE;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	int ix = int(mod(cell.x, 4.0));
	int iy = int(mod(cell.y, 4.0));
	float b = (BAYER[iy * 4 + ix] + 0.5) / 16.0 - 0.5;
	float steps = max(levels - 1.0, 1.0);
	c = clamp(floor(c * steps + 0.5 + b * dither) / steps, 0.0, 1.0);
	COLOR = vec4(c, 1.0);
}
