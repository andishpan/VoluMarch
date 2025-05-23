#ifndef COMMON_SDF_GLSL
#define COMMON_SDF_GLSL



/* ──────────────── SKY-LAYER SHAPES ──────────────── */
#define CLOUD_BASE_Y      40.0   /* altitude of cloud bottom */
#define CLOUD_LAYER_THICK 12.0   /* thickness of the layer   */

float getPlane(vec3 p){

    return p.y;
}

float getSphere(vec3 p, vec3 centre, float radius){

    return length(p - centre) - radius;
}

float getCube(vec3 p, vec3 centre, vec3 halfExt, float roundR){

    vec3 d = abs(p - centre) - halfExt;
    float outside = length(max(d, 0.0));
    float inside  = min(max(d.x,max(d.y,d.z)), 0.0);
    return outside + inside - roundR;
}

float getTorus(vec3 p, vec3 centre, float R, float r){

    p   -= centre;
    vec2 q = vec2(length(p.xz) - R, p.y);
    return length(q) - r;
}

float getPlume(vec3 p)
{

    const float uRiseSpeed = 2.0;
    p.y += uTime * uRiseSpeed;


    const float plumeHeight  = 30.0;
    const float baseRadius   = 3.0;
    const float topRadius    = 1.0;

    float h = clamp(p.y / plumeHeight, 0.0, 1.0);
    float radius = mix(baseRadius, topRadius, h);


    float swell = 0.8 * fbm(vec3(p.xz * 0.4, uTime * 0.2));

    radius += swell;

    float core = length(p.xz) - radius;


    float blob1 = length(p - vec3(0.0,  5.0, 0.0)) - 2.5;
    float blob2 = length(p - vec3(0.0, 12.0, 0.0)) - 2.0;
    float blob3 = length(p - vec3(0.0, 20.0, 0.0)) - 1.5;

    float k = 2.0;
    float union12 = opSmoothUnion(blob1, blob2, k);
    float union123 = opSmoothUnion(union12, blob3, k);
    return opSmoothUnion(core, union123, k);
}


float getRoundedBox(vec3 p, vec3 centre, vec3 halfExt, float roundR){

    p -= centre;
    vec3 d = abs(p) - halfExt;
    return length(max(d,0.0)) - roundR;
}



float cumulusSDF(vec3 p)
{

    vec3  centre = vec3(0.0, CLOUD_BASE_Y + 6.0,  0.0);
    float d0 = length(p - (centre + vec3(0.0,  0.0, 0.0))) -  7.0;
    float d1 = length(p - (centre + vec3(0.0,  6.0, 0.0))) -  6.0;
    float d2 = length(p - (centre + vec3(0.0, 12.0, 0.0))) -  4.5;
    return opSmoothUnion(opSmoothUnion(d0, d1, 3.0), d2, 3.0);
}

float stratocumulusSDF(vec3 p)
{

    float slab  = abs(p.y - CLOUD_BASE_Y) - (CLOUD_LAYER_THICK * 0.5);
    float bumps = fbm(p * 0.25) * 4.0 - 1.6;
    return max(slab, bumps);
}

float stratusSDF(vec3 p)
{

    return abs(p.y - CLOUD_BASE_Y) - 1.0;
}


float getShape(vec3 p, int id)
{
    vec3 c = vec3(0.0, 20.0, -25.0);
    float r = 8.0;
    vec3  halfExt = vec3(10.0);
    float k = 2.0;

    if      (id == 0) {
        float d1 = length(p - c) - r;
        float d2 = length(p - (c + vec3( 8.0, 0.0, 0.0))) - r;
        float d3 = length(p - (c + vec3(-8.0, 0.0, 0.0))) - r;
        return opSmoothUnion(opSmoothUnion(d1, d2, k), d3, k);
    }
    else if (id == 1) { return getSphere( p, c, r ); }
    else if (id == 2) { return getTorus ( p, c, 12.0, 5.0 ); }
    else if (id == 3) { return getCube  ( p, c, halfExt, 1.0 ); }
    else if (id == 4) { return cumulusSDF( p ); }
    else if (id == 5) { return stratocumulusSDF( p ); }
    else if (id == 6) { return stratusSDF( p ); }
    else if (id == 7) { return getPlume( p ); }
    return 1e3;
}

#ifndef GET_NOISE_DEFINED
float getNoise(vec3 p);
#endif




float getDensity(vec3 p, float sdfValue){

    float sdfMul = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;
    float fbmValue = fbm(p/6.0);
   // float density = abs(fbm(p / 6.0) + 0.5);
    float density = 0.5 * fbmValue + 0.5;
    return sdfMul * density;
}

/*float getDensity(vec3 p, float sdfValue){

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

}*/



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
