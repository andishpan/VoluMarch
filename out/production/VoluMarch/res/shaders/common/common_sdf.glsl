#ifndef COMMON_SDF_GLSL
#define COMMON_SDF_GLSL


#define CLOUD_BASE_Y      30.0
#define CLOUD_LAYER_THICK 10.0

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




float stratocumulusSDF(vec3 p) {
    float base   = p.y - CLOUD_BASE_Y;
    float thick  = 0.5 + 0.3 * fbmBillow(p * 0.1);
    float bumps  = fbmBillow(p * 0.35) * 3.0 - 1.2;
    return max(abs(base) - thick, bumps);
}


float stratusSDF(vec3 p) {
    float undulation = 0.8 * fbm(p * 0.05);
    return (p.y - CLOUD_BASE_Y) - undulation;
}


float getShape(vec3 p, int id){

    vec3 c = vec3(0.0, 20.0, -25.0);
    float r = 5.0;
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
    else if (id == 4) { return stratocumulusSDF(p); }
    else if (id == 5) { return stratusSDF(p); }
    return 1e3;
}


#ifndef GET_NOISE_DEFINED
float getNoise(vec3 p);
#endif


float getDensity(vec3 p, float sdfValue){

    float sdfMul = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;
    float density = (fbm(p / 6.0) + 0.5);
    return sdfMul;


}


float getVolume(vec3 p){

    float scaleFactor = 1.2;
    p /= scaleFactor;
    vec3 cloudOffset = vec3(uTime * 2.0, 0.0, uTime * 1.0);
    vec3 shiftedP = p - cloudOffset;

    float dPrev = getShape(p, uPrevShape);
    float dCurr = getShape(p, uObjectShape);


    float d = mix(dPrev, dCurr, smoothstep(0.0, 1.0, uShapeTransition));

    vec3 fbmCoord = (p + vec3(uTime*0.2, 0.0, uTime*0.2)) / uNoiseScale;
    if (uCurrentNoise == 2){

        d += uNoiseHeight * fbm(fbmCoord);
    } else {

        d += uNoiseHeight * fbm(fbmCoord);
    }


    return d * scaleFactor;
}



#endif
