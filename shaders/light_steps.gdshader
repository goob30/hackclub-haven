shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform int light_levels : hint_range(2, 32) = 5;
uniform int color_levels : hint_range(2, 64) = 6;
uniform float floor_light : hint_range(0.0, 0.2) = 0.02;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = max(max(c.r, c.g), c.b);
	float n = float(light_levels);
	float ql = l > 0.0 ? max(floor(l * n + 0.5) / n, floor_light) : 0.0;
	vec3 hue = l > 0.0 ? c / l : vec3(0.0);
	float k = float(color_levels);
	hue = floor(hue * k + 0.5) / k;
	COLOR = vec4(hue * ql, 1.0);
}
