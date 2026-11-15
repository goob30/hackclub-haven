shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform int light_levels : hint_range(2, 32) = 5;
uniform int color_levels : hint_range(2, 64) = 6;
uniform float floor_light : hint_range(0.0, 0.2) = 0.02;
// Replaces the Environment adjustments (saves a post-process pass)
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
// PS1 look: low-res snap and ordered dither
uniform float pixel_size : hint_range(1.0, 8.0) = 1.0;
uniform float dither : hint_range(0.0, 1.0) = 0.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(SCREEN_UV * res / pixel_size);
	vec2 uv = (cell + 0.5) * pixel_size / res;
	vec3 c = texture(screen_tex, uv).rgb;
	c = mix(vec3(0.5), c, contrast);
	c = mix(vec3(dot(vec3(1.0), c) * 0.33333), c, saturation);
	c = clamp(c, 0.0, 1.0);
	float l = max(max(c.r, c.g), c.b);
	float n = float(light_levels);
	float d = (BAYER[int(mod(cell.y, 4.0)) * 4 + int(mod(cell.x, 4.0))] / 16.0 - 0.5) * dither;
	float ql = l > 0.0 ? max(floor(l * n + d + 0.5) / n, floor_light) : 0.0;
	vec3 hue = l > 0.0 ? c / l : vec3(0.0);
	float k = float(color_levels);
	hue = floor(hue * k + 0.5) / k;
	COLOR = vec4(hue * ql, 1.0);
}
