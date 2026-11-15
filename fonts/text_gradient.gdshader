shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 0.1, 0.05, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.12, 0.0, 0.0, 1.0);
uniform float text_height = 48.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float t = clamp(local_y / text_height, 0.0, 1.0);
	COLOR.rgb *= mix(top_color, bottom_color, t).rgb;
}
