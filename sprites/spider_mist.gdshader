shader_type particles;

uniform float speed_min = 0.6;
uniform float speed_max = 2.2;
uniform float drag = 1.5;
uniform vec3 drift = vec3(0.0, 0.7, 0.0);

void start() {
    float seed = float(INDEX) + TIME * 13.0;
    float r1 = fract(sin(seed * 12.9898) * 43758.5453);
    float r2 = fract(sin(seed * 78.233) * 43758.5453);
    float r3 = fract(sin(seed * 39.346) * 24634.6345);
    float r4 = fract(sin(seed * 91.173) * 31415.9265);

    vec3 dir = normalize(vec3(r1 - 0.5, (r2 - 0.5) * 0.8, r3 - 0.5) + vec3(0.001));
    VELOCITY = dir * mix(speed_min, speed_max, r4);
    TRANSFORM[3].xyz = EMISSION_TRANSFORM[3].xyz + dir * r4 * 0.5;

    CUSTOM.x = 0.0;
    CUSTOM.y = mix(0.7, 1.3, r2);
    COLOR = vec4(1.0);
}

void process() {
    CUSTOM.x += DELTA;
    VELOCITY *= max(0.0, 1.0 - drag * DELTA);
    VELOCITY += drift * DELTA;
    TRANSFORM[3].xyz += VELOCITY * DELTA;

    float life = clamp(CUSTOM.x / max(LIFETIME, 0.001), 0.0, 1.0);
    float size = CUSTOM.y * mix(0.6, 1.6, life);
    TRANSFORM[0].xyz = normalize(TRANSFORM[0].xyz) * size;
    TRANSFORM[1].xyz = normalize(TRANSFORM[1].xyz) * size;
    TRANSFORM[2].xyz = normalize(TRANSFORM[2].xyz) * size;

    COLOR.a = 1.0 - smoothstep(0.15, 1.0, life);
}
