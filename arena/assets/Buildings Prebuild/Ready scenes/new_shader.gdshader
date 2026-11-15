shader_type canvas_item;

// Size of one "low-res pixel" in screen pixels
uniform float pixel_size : hint_range(1.0, 16.0, 0.5) = 4.0;

// Edge shaping
uniform float threshold : hint_range(0.0, 1.0) = 0.40;   // lower = bolder text
uniform float contrast  : hint_range(1.0, 20.0) = 5.0;   // higher = harder edges
uniform float spread    : hint_range(0.0, 2.0) = 0.5;    // blur/bleed before thresholding

// Gray fuzz around the letters
uniform float halo_amount : hint_range(0.0, 1.0) = 0.35;
uniform float halo_radius : hint_range(0.5, 4.0) = 1.5;  // in low-res pixels

// Compression-style grain on edge pixels
uniform float noise_amount : hint_range(0.0, 1.0) = 0.25;
uniform float noise_speed  : hint_range(0.0, 30.0) = 0.0; // 0 = static noise

// Number of gray levels (2 = pure black/white)
uniform int levels : hint_range(2, 16) = 5;

uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Sample the font texture at an arbitrary screen position, even though
// the text may be rotated/scaled. Uses screen-space derivatives of UV.
float sample_at(sampler2D tex, vec2 uv, vec2 duvdx, vec2 duvdy, vec2 offset) {
	vec2 suv = uv + duvdx * offset.x + duvdy * offset.y;
	return texture(tex, suv).a;
}

void fragment() {
	vec2 frag = FRAGCOORD.xy;
	vec2 cell = floor(frag / pixel_size);
	vec2 center = (cell + 0.5) * pixel_size;
	vec2 to_center = center - frag;

	// Derivatives must be computed in fragment(), once
	vec2 duvdx = dFdx(UV);
	vec2 duvdy = dFdy(UV);

	// Box-filter the block with 3x3 taps (slightly widened by spread)
	float step_px = pixel_size / 3.0 * (1.0 + spread);
	float core = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 off = to_center + vec2(float(x), float(y)) * step_px;
			core += sample_at(TEXTURE, UV, duvdx, duvdy, off);
		}
	}
	core /= 9.0;

	// Wider ring of taps for the soft gray halo
	float ring = 0.0;
	float r = pixel_size * halo_radius;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * TAU / 8.0;
		vec2 off = to_center + vec2(cos(ang), sin(ang)) * r;
		ring += sample_at(TEXTURE, UV, duvdx, duvdy, off);
	}
	ring /= 8.0;

	// Per-block noise, strongest where the edge is
	float t = floor(TIME * noise_speed);
	float n = hash(cell + t) - 0.5;
	float edge = 1.0 - abs(core * 2.0 - 1.0);
	core += n * noise_amount * edge * 2.0;

	// Harden edges, then add halo
	float a = clamp((core - threshold) * contrast + 0.5, 0.0, 1.0);
	float halo = ring * halo_amount * (0.6 + 0.8 * hash(cell * 1.7 + t));
	a = max(a, halo);

	// Posterize to a few gray levels
	float l = float(levels - 1);
	a = floor(a * l + 0.5) / l;

	COLOR = vec4(COLOR.rgb, a * opacity);
}