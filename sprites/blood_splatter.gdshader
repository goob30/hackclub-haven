shader_type particles;

uniform float speed_min = 2.5;
uniform float speed_max = 6.0;
uniform float spread = 1.0;
uniform vec3 gravity = vec3(0.0, -12.0, 0.0);


void start() {
    TRANSFORM[3].xyz = EMISSION_TRANSFORM[3].xyz;

    float seed = float(INDEX) + TIME * 17.0;
    float r1 = fract(sin(seed * 12.9898) * 43758.5453);
    float r2 = fract(sin(seed * 78.233) * 43758.5453);
    float r3 = fract(sin(seed * 39.346) * 24634.6345);

    float azimuth = r1 * 6.2831853;
    float tilt = r2 * spread;
    vec3 direction = vec3(sin(tilt) * cos(azimuth), cos(tilt), sin(tilt) * sin(azimuth));

    VELOCITY = direction * mix(speed_min, speed_max, r3);

    CUSTOM.x = 0.0;
    CUSTOM.y = mix(0.7, 1.4, r2);

    COLOR = vec4(1.0);

    float particle_scale = CUSTOM.y;
    TRANSFORM[0].xyz *= particle_scale;
    TRANSFORM[1].xyz *= particle_scale;
    TRANSFORM[2].xyz *= particle_scale;
}


void process() {
    CUSTOM.x += DELTA;

    VELOCITY += gravity * DELTA;
    TRANSFORM[3].xyz += VELOCITY * DELTA;

    float life = clamp(CUSTOM.x / max(LIFETIME, 0.001), 0.0, 1.0);
    float size = CUSTOM.y * mix(1.2, 0.15, life);

    TRANSFORM[0].xyz = normalize(TRANSFORM[0].xyz) * size;
    TRANSFORM[1].xyz = normalize(TRANSFORM[1].xyz) * size;
    TRANSFORM[2].xyz = normalize(TRANSFORM[2].xyz) * size;

    COLOR.a = 1.0 - smoothstep(0.25, 1.0, life);
}
