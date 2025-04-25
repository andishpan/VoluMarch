#ifndef GET_NOISE_DEFINED
#define GET_NOISE_DEFINED

uniform sampler3D uPrecomputedNoise;

float samplePrecomputedNoise(vec3 pos) {
    vec3 coord = fract(pos / uNoiseScale);
    return texture(uPrecomputedNoise, coord).r;
}


float getNoise(vec3 p) {
    return samplePrecomputedNoise(p);
}
#endif
