
#ifndef RAYMARCH_MULTISCAT_DEFINED
#define RAYMARCH_MULTISCAT_DEFINED

#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif



float hash11(float p){ p=fract(p*0.1031); p*=p+33.33; p*=p+p; return fract(p);}
vec2  hash22(vec2 p){ return vec2(hash11(p.x), hash11(p.y)); }


vec3 sampleHG(float g, vec2 xi){

    float cosT;
    if (abs(g) < 1e-3)
    cosT = 1.0 - 2.0 * xi.x;
    else {
        float sq = (1.0 - g*g) / (1.0 - g + 2.0*g*xi.x);
        cosT = (1.0 + g*g - sq*sq) / (2.0*g);
    }
    float sinT = sqrt(max(0.0, 1.0 - cosT*cosT));
    float phi  = 2.0 * 3.14159265 * xi.y;
    return vec3(cos(phi)*sinT, sin(phi)*sinT, cosT);
}


vec3 orthBase(vec3 n){
    return normalize(abs(n.x)>0.5 ? vec3(n.y,-n.x,0.0)
    : vec3(0.0,-n.z,n.y));
}
vec3 toWorld(vec3 v, vec3 dir){
    vec3 u = orthBase(dir);
    vec3 w = normalize(cross(dir, u));
    return v.x*u + v.y*w + v.z*dir;
}


float shadowMarchMS(vec3 x, vec3 L, float step, int maxSteps, inout int shadCtr){

    float Tr = 1.0, t = 0.0;
    for (int i = 0; i < maxSteps; ++i){
        ++shadCtr;
        vec3 p = x + L * t;
        float sdf = getVolume(p);
        if (sdf < SURFACE_DIST){
            float d   = getDensity(p, sdf);
            float sigT= (uVolumetricAbsorption + uVolumetricScattering)*d;
            Tr *= BeerLambert(sigT, step);
            if (Tr < 0.01) break;
        }
        t += step;
    }
    return Tr;
}


const int   MAX_BOUNCES = 4;
const float ROULETTE    = 0.2;

vec3 raymarch(vec3 rayO, vec3 rayD, out vec3 outVol, out int  outPrim, out int outShad, out int  outSdf,  out int outBounce){

    int prim=0, shad=0, sdf=0, bounce=0;

    vec3  L    = vec3(0.0);
    vec3  beta = vec3(1.0);
    vec3  lightCol   = vec3(1.0,0.95,0.8) * uSunIntensity;
    vec3  sunDir   = normalize(uSunDirection);
    float sigmaMax = uVolumetricAbsorption + uVolumetricScattering;

    for (int b = 0; b < MAX_BOUNCES; ++b){


        float t = 0.0;
        for (;;){
            ++sdf;
            float xi = hash11(dot(rayO,rayD)+float(b)*13.37);
            t += -log(1.0 - xi) / sigmaMax;

            vec3  p  = rayO + rayD * t;
            float sdfV = getVolume(p);
            if (sdfV > SURFACE_DIST) continue;

            float d = getDensity(p, sdfV);
            if (hash11(p.x+p.y+p.z) < d) { rayO = p; break; }
        }


        if (t > SCENE_MAX_T) break;


        float sigmaA = uVolumetricAbsorption;
        float sigmaS = uVolumetricScattering;
        float sigmaT = sigmaA + sigmaS;
        float albedo = sigmaS / sigmaT;


        ++bounce;
        float TrSun = shadowMarchMS(rayO, sunDir, 0.6,
        uMaxLightMarchSteps, shad);
        float phase = HenyeyGreenstein(dot(-rayD, sunDir),
        uBackwardScattering);
        L += beta * albedo * TrSun * lightCol * phase;


        beta *= albedo;
        float maxB = max(beta.r, max(beta.g, beta.b));
        if (maxB < ROULETTE){
            if (hash11(float(b)*7.0) < maxB/ROULETTE)
            beta /= maxB/ROULETTE;
            else
            break;
        }


        vec2  xi2  = hash22(vec2(dot(rayO,rayD), float(bounce)));
        vec3  dirL = sampleHG(uBackwardScattering, xi2);
        rayD = normalize(toWorld(dirL, rayD));
        ++prim;
    }

    outVol     = L;
    outPrim    = prim;
    outShad    = shad;
    outSdf     = sdf;
    outBounce  = bounce;
    return L;
}

#endif
