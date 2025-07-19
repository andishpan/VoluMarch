#ifndef NOISE_WORLEY_DEFINED
#define NOISE_WORLEY_DEFINED

// The MIT License
// Copyright © 2017 Inigo Quilez
// Adapted with Worley (cellular) noise and tiling support
// https://iquilezles.org/articles/gradientnoise

// 0: integer hash
// 1: float hash (aliasing based)
#define METHOD 0

// 0: cubic
// 1: quintic
#define INTERPOLANT 1

// Tile size for wrapping both gradient and Worley
#define TILE_SIZE 32

// ---------------------
// Base hash functions
// ---------------------
#if METHOD==0
vec3 hash(ivec3 p) {
    p = ivec3(mod(p, TILE_SIZE));// tile wrap
    ivec3 n = ivec3(
    p.x*127 + p.y*311 + p.z* 74,
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

// ---------------------
// Gradient noise (analytic derivatives)
// ---------------------
vec4 noised(in vec3 x) {
    #if METHOD==0
    ivec3 i = ivec3(floor(x));
    #else
    vec3 i = floor(x);
    #endif
    vec3 f = fract(x);

    #if INTERPOLANT==1
    vec3 u  = f*f*f*(f*(f*6.0-15.0)+10.0);
    vec3 du = 30.0*f*f*(f*(f-2.0)+1.0);
    #else
    vec3 u  = f*f*(3.0-2.0*f);
    vec3 du = 6.0*f*(1.0-f);
    #endif

    // fetch gradients at cube corners
    vec3 ga = hash(i + ivec3(0, 0, 0));
    vec3 gb = hash(i + ivec3(1, 0, 0));
    vec3 gc = hash(i + ivec3(0, 1, 0));
    vec3 gd = hash(i + ivec3(1, 1, 0));
    vec3 ge = hash(i + ivec3(0, 0, 1));
    vec3 gf = hash(i + ivec3(1, 0, 1));
    vec3 gg = hash(i + ivec3(0, 1, 1));
    vec3 gh = hash(i + ivec3(1, 1, 1));

    // dot gradients
    float va = dot(ga, f - vec3(0));
    float vb = dot(gb, f - vec3(1, 0, 0));
    float vc = dot(gc, f - vec3(0, 1, 0));
    float vd = dot(gd, f - vec3(1, 1, 0));
    float ve = dot(ge, f - vec3(0, 0, 1));
    float vf = dot(gf, f - vec3(1, 0, 1));
    float vg = dot(gg, f - vec3(0, 1, 1));
    float vh = dot(gh, f - vec3(1, 1, 1));

    // interpolation contributions
    float k0 = va - vb - vc + vd;
    float k1 = va - vc - ve + vg;
    float k2 = va - vb - ve + vf;
    float k3 = -va + vb + vc - vd + ve - vf - vg + vh;
    float k4 = vb - va;
    float k5 = vc - va;
    float k6 = ve - va;

    vec3 g0 = ga - gb - gc + gd;
    vec3 g1 = ga - gc - ge + gg;
    vec3 g2 = ga - gb - ge + gf;
    vec3 g3 = -ga + gb + gc - gd + ge - gf - gg + gh;
    vec3 g4 = gb - ga;
    vec3 g5 = gc - ga;
    vec3 g6 = ge - ga;

    float value = va + k4*u.x + k5*u.y + k6*u.z
    + k0*u.x*u.y + k1*u.y*u.z + k2*u.z*u.x + k3*u.x*u.y*u.z;
    vec3 deriv = ga + g4*u.x + g5*u.y + g6*u.z
    + g0*u.x*u.y + g1*u.y*u.z + g2*u.z*u.x + g3*u.x*u.y*u.z
    + du * (vec3(k4, k5, k6) + vec3(k0, k1, k2)*u.yzx + vec3(k2, k0, k1)*u.zxy + k3*u.yzx*u.zxy);
    return vec4(value, deriv);
}

float getGradientNoise(vec3 p) {
    return noised(p).x;
}

// ---------------------
// Worley (cellular) noise
// ---------------------
float getWorley(vec3 p) {
    ivec3 cell = ivec3(floor(p));
    vec3 f  = fract(p);
    float minDist = 1e10;

    for (int xo=-1; xo<=1; ++xo) {
        for (int yo=-1; yo<=1; ++yo) {
            for (int zo=-1; zo<=1; ++zo) {
                ivec3 neighbor = cell + ivec3(xo, yo, zo);
                // tile wrap
                neighbor = ivec3(mod(neighbor, TILE_SIZE));
                // random point in cell
                vec3 jitter = 0.5 * (hash(neighbor) + 1.0);
                vec3 diff = vec3(xo, yo, zo) + jitter - f;
                float d = length(diff);
                minDist = min(minDist, d);
            } } }
    return minDist;
}

// ---------------------
// Combined tileable noise
// ---------------------
// Mix factor: 0 = pure gradient, 1 = pure Worley
#define WORLEY_MIX 0.5

float getNoise(vec3 p) {
    float g = getGradientNoise(p);
    float w = getWorley(p);
    return mix(g, w, WORLEY_MIX);
}

#endif// NOISE_WORLEY_DEFINED
