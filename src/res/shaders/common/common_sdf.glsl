#ifndef COMMON_SDF_GLSL
#define COMMON_SDF_GLSL
float getPlane(vec3 p)
{
    return p.y;        // ground plane at y = 0
}

float getSphere(vec3 p, vec3 centre, float radius)
{
    return length(p - centre) - radius;
}

float getCube(vec3 p, vec3 centre, vec3 halfExt, float roundR)
{
    vec3 d = abs(p - centre) - halfExt;
    float outside = length(max(d, 0.0));
    float inside  = min(max(d.x,max(d.y,d.z)), 0.0);
    return outside + inside - roundR;
}

float getTorus(vec3 p, vec3 centre, float R, float r)
{
    p   -= centre;
    vec2 q = vec2(length(p.xz) - R, p.y);
    return length(q) - r;
}

float getRoundedBox(vec3 p, vec3 centre, vec3 halfExt, float roundR)
{
    p -= centre;
    vec3 d = abs(p) - halfExt;
    return length(max(d,0.0)) - roundR;
}
float getShape(vec3 p, int id)
{
    vec3 c = vec3(0.0, 20.0, -25.0);
    float r = 8.0;
    vec3 halfExt = vec3(10.0);
    float k = 2.0;

    if (id == 0)
    {
        float d1 = length(p - c) - r;
        float d2 = length(p - (c+vec3( 8.0,0,0))) - r;
        float d3 = length(p - (c+vec3(-8.0,0,0))) - r;
        return opSmoothUnion(opSmoothUnion(d1,d2,k), d3, k);
    }
    else if (id == 1) { return getSphere(p, c, r);                     }
    else if (id == 2) { return getTorus (p, c, 12.0, 5.0);             }
    else if (id == 3) { return getCube  (p, c, halfExt, 1.0);          }
    return 1e3;
}
float getDensity(vec3 p, float sdfValue)
{
    float sdfMul = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;
    float density = abs(fbm(p / 6.0) + 0.5);
    return sdfMul * density;
}
float getVolume(vec3 p)
{
    float scaleFactor = 1.2;
    p /= scaleFactor;

    float dPrev = getShape(p, uPrevShape);
    float dCurr = getShape(p, uObjectShape);
    float d     = mix(dPrev, dCurr, smoothstep(0.0,1.0,uShapeTransition));

    vec3 fbmCoord = (p + vec3(uTime*0.5, 0.0, uTime*0.5)) / uNoiseScale;
    d += uNoiseHeight * fbm(fbmCoord);

    return d * scaleFactor;
}

#endif
