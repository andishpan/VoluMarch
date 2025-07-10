#ifndef COMMON_SDF_GLSL
#define COMMON_SDF_GLSL





#define CLOUD_BASE_Y 30.0
#define CLOUD_LAYER_THICK 10.0


float H = 0.7;



float getPlane(vec3 p){

    return p.y;
}

float getSphere(vec3 p, vec3 centre, float radius){

    return length(p - centre) - radius;
}

float getCube(vec3 p, vec3 centre, vec3 halfExt, float roundR){

    vec3 d = abs(p - centre) - halfExt;
    float outside = length(max(d, 0.0));
    float inside  = min(max(d.x, max(d.y, d.z)), 0.0);
    return outside + inside - roundR;
}

float getTorus(vec3 p, vec3 centre, float R, float r){

    p -= centre;
    vec2 q = vec2(length(p.xz) - R, p.y);
    return length(q) - r;
}




float getRoundedBox(vec3 p, vec3 centre, vec3 halfExt, float roundR){

    p -= centre;
    vec3 d = abs(p) - halfExt;
    return length(max(d, 0.0)) - roundR;
}


float cumulusSDF(vec3 p) {

    vec3 centre = vec3(0.0, CLOUD_BASE_Y + 6.0, 0.0);


    const int N = 6;


    vec3 offs[N] = vec3[](
    vec3(-4.0, 0.0, 0.0),
    vec3(0.0, 0.0, 0.0),
    vec3(4.0, 0.0, 0.0),
    vec3(-2.5, 2.5, 0.5),
    vec3(2.5, 2.5, -0.5),
    vec3(0.0, 5.0, 0.0)
    );

    // Radius of each puff
    float radii[N] = float[](3.0, 3.5, 3.0, 2.5, 2.5, 2.0);

    // How “soft” the blends are
    const float K = sdfBlendRadius;

    // Build a smooth-union of all sub-spheres
    float d = 1e5;
    for (int i = 0; i < N; i++) {
        float di = length(p - (centre + offs[i])) - radii[i];
        d = opSmoothUnion(d, di, K);
    }

    return d;
}

float stratocumulusSDF(vec3 p) {
    float base = p.y - CLOUD_BASE_Y;
    float thick  = 0.5 + 0.3 * fbmBillow(p * 0.1);// variable thickness
    float bumps  = fbmBillow(p * 0.35) * 3.0 - 1.2;// billows
    return max(abs(base) - thick, bumps);
}


float stratusSDF(vec3 p) {
    float undulation = 0.8 * fbm(p * 0.05);
    return (p.y - CLOUD_BASE_Y) - undulation;// no abs()
}


float getShape(vec3 p, int id){

    vec3 c = vec3(0.0, 20.0, -25.0);
    float r = 7.0;
    vec3  halfExt = vec3(10.0);
    // increases the region  => density function returns non zero values over a bigger region
    //  float blendRadius = 2.0;

    if (id == 0) {
        float d1 = length(p - c) - r;
        float d2 = length(p - (c + vec3(8.0, 0.0, 0.0))) - r;
        float d3 = length(p - (c + vec3(-8.0, 0.0, 0.0))) - r;
        return opSmoothUnion(opSmoothUnion(d1, d2, sdfBlendRadius), d3, sdfBlendRadius);
    }
    else if (id == 1) { return getSphere(p, c, r); }
    else if (id == 2) { return getTorus (p, c, 12.0, 5.0); }
    else if (id == 3) { return getCube  (p, c, halfExt, 1.0); }
    else if (id == 4) { return cumulusSDF(p); }
    else if (id == 5) { return stratocumulusSDF(p); }
    else if (id == 6) { return stratusSDF(p); }
    return 1e3;
}

float getMultiShape(vec3 p) {
    float result = 1e5;
    const int NUM_CLOUDS = 5;

    vec3 offsets[NUM_CLOUDS];
    offsets[0] = vec3(-20.0, 0.0, 0.0);
    offsets[1] = vec3(-10.0, 0.0, 10.0);
    offsets[2] = vec3(0.0, 0.0, 0.0);
    offsets[3] = vec3(10.0, 0.0, -10.0);
    offsets[4] = vec3(20.0, 0.0, 0.0);

    for (int i = 0; i < NUM_CLOUDS; ++i) {
        float d = getShape(p - offsets[i], uObjectShape);
        result = opSmoothUnion(result, d, 3.0);
    }

    return result;
}


#ifndef GET_NOISE_DEFINED
float getNoise(vec3 p);
#endif




/*float getDensity(vec3 p, float sdfValue){

    float sdfMul = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;
    //float sdfMul = clamp(1.0 - abs(sdfValue) * 4.0, 0.0, 1.0);

    //float noiseValue = getNoise(p * 0.25);
    // float density = abs(fbm(p / 6.0) + 0.5);
    //float noise01 = clamp(fbm(p/6.0)*0.5 + 0.5, 0.0, 1.0);
    float noise01 = clamp(fbm(p + vec3(uTime * 0.2)), 0.0, 1.0);
    noise01 = pow(noise01, 1.5);

    float density = sdfMul * noise01;
    //float density = abs(noiseValue);
    //  return density;
    return sdfMul;
} */


float getDensityOld(vec3 p, float sdfValue){

    vec3 warp = vec3(
    getNoise(p * 0.35 + uTime),
    getNoise(p * 0.35 + vec3(19.3, 7.1, 12.8)),
    getNoise(p * 0.35 + vec3(37.7, 51.6, 9.4))
    );
    vec3 pw = p + warp * 2.5;
    float d = fbm(pw * 5.0);
    d = pow(d, 1.6);
    float h = smoothstep(uNoiseHeight, 0.0, pw.y);
    return max(d * h - sdfValue * 0.08, 0.0);

}



/*float getVolume(vec3 p){

    float scaleFactor = 1.2;
    p /= scaleFactor;

    // float dPrev = getMultiShape(p);
    //float dCurr = getMultiShape(p);
    float dPrev = getShape(p, uPrevShape);
    float dCurr = getShape(p, uObjectShape);


    float d = mix(dPrev, dCurr, smoothstep(0.0, 1.0, uShapeTransition));

    //vec3 nOffset = vec3(uTime * 0.5, 0.0, uTime * 0.5);
    //  float noiseValue = getNoise((p + nOffset) / uNoiseScale);

    vec3 offset = vec3(cos(uTime)*0.5, 0.0, sin(uTime)*0.5);

    vec3 fbmCoord = (p + offset) / uNoiseScale;
    d += uNoiseHeight * fbmBillow(fbmCoord);
    // d += uNoiseHeight * noiseValue;

    return d * scaleFactor;
} */

float getDensity(vec3 p, float sdfValue){

    float sdfMul = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;
    float fbmValue = fbm(p/6.0);
    // float density = abs(fbm(p / 6.0) + 0.5);
    float density = 0.5 * fbmValue + 0.5;
    return sdfMul * density;
}


float getVolume(vec3 p){

    float scaleFactor = 1.2;
    p /= scaleFactor;

    float dPrev = getShape(p,uPrevShape);
    float dCurr = getShape(p,uObjectShape);
    float d     = mix(dPrev, dCurr, smoothstep(0.0,1.0,uShapeTransition));

    vec3 fbmCoord = (p + vec3(uTime*0.5, 0.0, uTime*0.5)) / uNoiseScale;
    d += uNoiseHeight * fbm(fbmCoord);

    return d * scaleFactor;
}

#endif
