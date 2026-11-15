shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_nearest;
uniform float dither_scale = 2.0;

varying float fade;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void vertex() {
	fade = COLOR.a;
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	VERTEX *= scale;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ivec2 p = ivec2(FRAGCOORD.xy / dither_scale) % 4;
	float threshold = (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
	if (c.a < 0.5 || fade <= threshold) {
		discard;
	}
	ALBEDO = c.rgb;
}
