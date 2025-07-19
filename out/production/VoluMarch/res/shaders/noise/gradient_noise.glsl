#ifndef GET_NOISE_DEFINED
#define GET_NOISE_DEFINED

// The MIT License
// Copyright © 2017 Inigo Quilez
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org/

// Computes the analytic derivatives of a 3D Gradient Noise.
// More info: https://iquilezles.org/articles/gradientnoise

// 0: integer hash
// 1: float hash (aliasing based)
#define METHOD 0

// 0: cubic
// 1: quintic
#define INTERPOLANT 1

#if METHOD==0
#define TILE_SIZE 64// or 128 or any integer tile size

vec3 hash(ivec3 p) {
    p = ivec3(mod(p, TILE_SIZE));// <<< TILING FIX

    ivec3 n = ivec3(
    p.x*127 + p.y*311 + p.z*74,
    p.x*269 + p.y*183 + p.z*246,
    p.x*113 + p.y*271 + p.z*124
    );
    n = (n << 13) ^ n;
    n = n * (n * n * 15731 + 789221) + 1376312589;
    return -1.0 + 2.0 * vec3(n & ivec3(0x0fffffff)) / float(0x0fffffff);
}

#else
vec3 hash(vec3 p) {
    p = vec3(
    dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6))
    );
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
#endif

// Gradient noise with derivatives (x = value, yzw = dx/dy/dz)
vec4 noised(in vec3 x) {
    #if METHOD==0
    ivec3 i = ivec3(floor(x));
    #else
    vec3 i = floor(x);
    #endif
    vec3 f = fract(x);

    #if INTERPOLANT==1
    vec3 u = f*f*f*(f*(f*6.0-15.0)+10.0);
    vec3 du = 30.0*f*f*(f*(f-2.0)+1.0);
    #else
    vec3 u = f*f*(3.0-2.0*f);
    vec3 du = 6.0*f*(1.0-f);
    #endif

    #if METHOD==0
    vec3 ga = hash(i+ivec3(0, 0, 0));
    vec3 gb = hash(i+ivec3(1, 0, 0));
    vec3 gc = hash(i+ivec3(0, 1, 0));
    vec3 gd = hash(i+ivec3(1, 1, 0));
    vec3 ge = hash(i+ivec3(0, 0, 1));
    vec3 gf = hash(i+ivec3(1, 0, 1));
    vec3 gg = hash(i+ivec3(0, 1, 1));
    vec3 gh = hash(i+ivec3(1, 1, 1));
    #else
    vec3 ga = hash(i+vec3(0.0, 0.0, 0.0));
    vec3 gb = hash(i+vec3(1.0, 0.0, 0.0));
    vec3 gc = hash(i+vec3(0.0, 1.0, 0.0));
    vec3 gd = hash(i+vec3(1.0, 1.0, 0.0));
    vec3 ge = hash(i+vec3(0.0, 0.0, 1.0));
    vec3 gf = hash(i+vec3(1.0, 0.0, 1.0));
    vec3 gg = hash(i+vec3(0.0, 1.0, 1.0));
    vec3 gh = hash(i+vec3(1.0, 1.0, 1.0));
    #endif

    float va = dot(ga, f-vec3(0.0, 0.0, 0.0));
    float vb = dot(gb, f-vec3(1.0, 0.0, 0.0));
    float vc = dot(gc, f-vec3(0.0, 1.0, 0.0));
    float vd = dot(gd, f-vec3(1.0, 1.0, 0.0));
    float ve = dot(ge, f-vec3(0.0, 0.0, 1.0));
    float vf = dot(gf, f-vec3(1.0, 0.0, 1.0));
    float vg = dot(gg, f-vec3(0.0, 1.0, 1.0));
    float vh = dot(gh, f-vec3(1.0, 1.0, 1.0));

    float k0 = va-vb-vc+vd;
    vec3  g0 = ga-gb-gc+gd;
    float k1 = va-vc-ve+vg;
    vec3  g1 = ga-gc-ge+gg;
    float k2 = va-vb-ve+vf;
    vec3  g2 = ga-gb-ge+gf;
    float k3 = -va+vb+vc-vd+ve-vf-vg+vh;
    vec3  g3 = -ga+gb+gc-gd+ge-gf-gg+gh;
    float k4 = vb-va;
    vec3  g4 = gb-ga;
    float k5 = vc-va;
    vec3  g5 = gc-ga;
    float k6 = ve-va;
    vec3  g6 = ge-ga;

    return vec4(
    va + k4*u.x + k5*u.y + k6*u.z + k0*u.x*u.y + k1*u.y*u.z + k2*u.z*u.x + k3*u.x*u.y*u.z,
    ga + g4*u.x + g5*u.y + g6*u.z + g0*u.x*u.y + g1*u.y*u.z + g2*u.z*u.x + g3*u.x*u.y*u.z +
    du * (vec3(k4, k5, k6) + vec3(k0, k1, k2)*u.yzx + vec3(k2, k0, k1)*u.zxy + k3*u.yzx*u.zxy)
    );
}

// Scalar noise value only
float getNoise(vec3 p) {
    return noised(p).x;
}

#endif
