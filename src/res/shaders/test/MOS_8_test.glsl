


#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif


const int   NUM_OCTAVES = 8;

const float OCTAVE_SCALES[NUM_OCTAVES] = float[](
1.0,0.5,0.25,0.125,0.0625,0.03125,0.015625,0.0078125);

const float OCTAVE_ECC[NUM_OCTAVES] = float[](
0.6,0.3,0.15,0.075,0.0375,0.01875,0.009375,0.0046875);

const float OCTAVE_WEIGHTS[NUM_OCTAVES] = float[](
0.5,0.25,0.125,0.0625,0.03125,0.015625,0.0078125,0.00390625);

const float OCTAVE_CDF[NUM_OCTAVES] = float[](
0.5,0.75,0.875,0.9375,0.96875,0.984375,0.9921875,1.0);


float hash11(float p){ p=fract(p*0.1031); p*=p+33.33; p*=p+p; return fract(p);}
int  selectOctave(float s){ float r=hash11(s); for(int i=0;i<NUM_OCTAVES;++i)
if(r<OCTAVE_CDF[i]) return i; return NUM_OCTAVES-1; }


float shadowMarchMOS(vec3 p, vec3 L, float step, int maxSteps, float scale,
inout int shadowCtr)
{
    float Tr=1.0, t=0.0;
    for(int i=0;i<maxSteps;++i){
        ++shadowCtr;
        vec3 pos = p + L*t;
        float sdf = getVolume(pos);
        if(sdf<0.0){
            float dens = getDensity(pos,sdf);
            float sigmaT = (uVolumetricAbsorption+uVolumetricScattering)
            * dens * scale;
            Tr*=BeerLambert(sigmaT,step);
            if(Tr<0.01) break;
        }
        t+=step;
    }
    return Tr;
}


vec3 raymarch(vec3 rayOrigin, vec3 rayDir,
out vec3 outVolCol,
out int  outPrimary, out int outShadow,
out int  outSdf)
{

    int primaryCtr=0, shadowCtr=0, sdfCtr=0;


    vec3  volCol=vec3(0.0), surfCol=vec3(0.0);
    float trans=1.0, nearestT=SCENE_MAX_T;
    const float marchSize=0.3;


    float opaqueT=1e20; vec3 surfN=vec3(0); int matID=INVALID_MATERIAL_ID;
    float waterT; vec3 waterN;
    if(intersectWaterPlane(rayOrigin,rayDir,waterT,waterN)&&waterT<opaqueT){
        opaqueT=waterT; surfN=waterN; matID=WATER_MATERIAL_ID; nearestT=opaqueT;
    }


    float depth=0.0;
    for(int i=0;i<uMaxSteps;++i){
        ++sdfCtr;
        vec3 p=rayOrigin+depth*rayDir;
        float d=getVolume(p);
        if(d<SURFACE_DIST||depth>nearestT) break;
        depth+=d;
    }


    if(depth<nearestT){
        vec3 L = normalize(uSunDirection);
        vec3 sunCol = vec3(1.0,0.95,0.8)*uSunIntensity;
        vec3 ambient = ambientColor*0.5;

        for(int i=0;i<uMaxVolumeSteps;++i){
            ++primaryCtr;
            depth += marchSize;
            if(depth > nearestT) break;

            vec3  p   = rayOrigin + rayDir * depth;
            float sdf = getVolume(p);
            if(sdf >= 0.0) continue;

            float dens = getDensity(p, sdf);


            int   oct    = selectOctave(depth + p.x + p.y + p.z);
            float scale  = OCTAVE_SCALES [oct];
            float g      = OCTAVE_ECC   [oct];
            float weight = OCTAVE_WEIGHTS[oct] * float(NUM_OCTAVES);


            float sigmaA = uVolumetricAbsorption  * dens * scale;
            float sigmaS = uVolumetricScattering * dens * scale;
            float sigmaT = sigmaA + sigmaS;

            float stepT   = exp(-sigmaT * marchSize);
            float stepExt = (1.0 - stepT) * trans;
            trans *= stepT;
            if(trans < MIN_OPACITY) continue;


            float lightVis = shadowMarchMOSTest(
            p, L, marchSize * 1.4,
            uMaxLightMarchSteps, scale,
            shadowCtr);


            float mu    = dot(-rayDir, L);
            float phase = HenyeyGreenstein(mu, g);



            //if(stepExt > 0.0 && sigmaS > 0.0){
            //    bounceCtr++;
          //  }


            vec3 scatter = sunCol * (sigmaS * phase * lightVis);
            volCol += weight * scatter * stepExt;
            volCol += ambient * stepExt;
        }

    }


    if(matID!=INVALID_MATERIAL_ID){
        vec3 hit=rayOrigin+rayDir*opaqueT;
        getLighting(hit,surfN,-rayDir,matID,surfCol);
    }else surfCol=vec3(0.7,0.85,1.0);


    outVolCol  = volCol;
    outPrimary = primaryCtr;
    outShadow  = shadowCtr;
    outSdf     = sdfCtr;

    return clamp(volCol,0.0,1.0)+trans*surfCol;
}

#endif
