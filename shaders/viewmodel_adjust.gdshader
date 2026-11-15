shader_type canvas_item;

// Same contrast/saturation the world gets in light_steps
uniform float contrast : hint_range(0.0, 2.0) = 1.1;
uniform float saturation : hint_range(0.0, 2.0) = 0.85;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(vec3(0.5), c.rgb, contrast);
	c.rgb = mix(vec3(dot(vec3(1.0), c.rgb) * 0.33333), c.rgb, saturation);
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), c.a);
}
