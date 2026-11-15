shader_type canvas_item;

group_uniforms Pixelation;
// Size of one "low-res pixel" in screen pixels (rounded to whole pixels)
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 1.0;
// Taps per axis in the block filter (grid is n x n)
uniform int block_taps : hint_range(1, 7) = 2;
// Extra widening of the block filter footprint (0 = exactly the block)
uniform float spread : hint_range(0.0, 2.0) = 0.0;

group_uniforms Legibility;
// Raises (>1) or lowers (<1) coverage before thresholding. Below 1 opens up counters.
uniform float coverage_gamma : hint_range(0.5, 4.0) = 1.0;
// Unsharp mask strength: pushes strokes away from their surroundings
uniform float sharpen : hint_range(0.0, 3.0) = 0.0;
// Radius of the sharpening reference ring, in cells
uniform float sharpen_radius : hint_range(0.5, 4.0) = 1.0;
// Blend in the single center tap to keep hairlines alive (0 = off)
uniform float center_weight : hint_range(0.0, 1.0) = 0.0;

group_uniforms Edge;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;
uniform float contrast  : hint_range(1.0, 20.0) = 4.0;    // lower = softer edges
uniform float edge_midpoint : hint_range(0.0, 1.0) = 0.5; // output value at the threshold

group_uniforms Halo;
uniform float halo_amount : hint_range(0.0, 1.0) = 0.02;
uniform float halo_radius : hint_range(0.5, 4.0) = 1.2;
uniform int   halo_samples : hint_range(1, 16) = 8;
uniform float halo_angle_offset : hint_range(0.0, 6.2832) = 0.0;
uniform float halo_variation : hint_range(0.0, 1.0) = 0.6;
uniform float halo_base : hint_range(0.0, 2.0) = 0.7;
uniform float halo_noise_scale : hint_range(0.1, 10.0) = 1.7;

group_uniforms Noise;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.01;
uniform float noise_speed  : hint_range(0.0, 30.0) = 0.0;
uniform float noise_edge_power : hint_range(0.1, 8.0) = 1.0;
uniform vec2  noise_seed = vec2(127.1, 311.7);

group_uniforms Output;
// Number of gray levels (2 = pure black/white)
uniform int levels : hint_range(2, 16) = 8;
// Posterize rounding bias (0.5 = nearest level, 0.0 = floor, 1.0 = ceil)
uniform float level_rounding : hint_range(0.0, 1.0) = 0.5;
// 0 = original text, 1 = full effect
uniform float effect_strength : hint_range(0.0, 1.0) = 0.5;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, noise_seed)) * 43758.5453);
}

float sample_at(sampler2D tex, vec2 uv, vec2 duvdx, vec2 duvdy, vec2 offset) {
	vec2 suv = uv + duvdx * offset.x + duvdy * offset.y;
	return texture(tex, suv).a;
}

float ring_avg(sampler2D tex, vec2 uv, vec2 duvdx, vec2 duvdy, vec2 to_center, float radius, int samples, float angle0) {
	float sum = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= samples) break;
		float ang = angle0 + float(i) * TAU / float(samples);
		vec2 off = to_center + vec2(cos(ang), sin(ang)) * radius;
		sum += sample_at(tex, uv, duvdx, duvdy, off);
	}
	return sum / float(samples);
}

void fragment() {
	float px = max(1.0, floor(pixel_size + 0.5)); // integer cells only
	vec2 frag = FRAGCOORD.xy;
	vec2 cell = floor(frag / px);
	vec2 center = (cell + 0.5) * px;
	vec2 to_center = center - frag;

	vec2 duvdx = dFdx(UV);
	vec2 duvdy = dFdy(UV);

	// Box-filter the block with n x n taps
	float n_taps = float(block_taps);
	float step_px = px / n_taps * (1.0 + spread);
	float half_span = (n_taps - 1.0) * 0.5;
	float core = 0.0;
	for (int x = 0; x < 7; x++) {
		if (x >= block_taps) break;
		for (int y = 0; y < 7; y++) {
			if (y >= block_taps) break;
			vec2 off = to_center + (vec2(float(x), float(y)) - half_span) * step_px;
			core += sample_at(TEXTURE, UV, duvdx, duvdy, off);
		}
	}
	core /= n_taps * n_taps;

	// Optionally blend in the unfiltered center sample
	float center_tap = sample_at(TEXTURE, UV, duvdx, duvdy, to_center);
	core = mix(core, max(core, center_tap), center_weight);

	// Separate rings: one for the halo, one for sharpening
	float ring = ring_avg(TEXTURE, UV, duvdx, duvdy, to_center, px * halo_radius, halo_samples, halo_angle_offset);
	float sring = ring_avg(TEXTURE, UV, duvdx, duvdy, to_center, px * sharpen_radius, 8, 0.0);

	// Unsharp mask, then coverage curve
	core = clamp(core + sharpen * (core - sring), 0.0, 1.0);
	core = pow(core, 1.0 / coverage_gamma);

	// Per-block noise, strongest where the edge is
	float t = floor(TIME * noise_speed);
	float n = hash(cell + t) - 0.5;
	float edge = pow(max(1.0 - abs(core * 2.0 - 1.0), 0.0), noise_edge_power);
	core += n * noise_amount * edge;

	// Soften edges, then add halo
	float a = clamp((core - threshold) * contrast + edge_midpoint, 0.0, 1.0);
	float halo = ring * halo_amount * (halo_base + halo_variation * hash(cell * halo_noise_scale + t));
	a = max(a, halo);

	// Posterize
	float l = float(levels - 1);
	a = floor(a * l + level_rounding) / l;

	// Blend between original and processed
	float original = texture(TEXTURE, UV).a;
	a = mix(original, a, effect_strength);

	COLOR = vec4(COLOR.rgb, a * opacity);
}