#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED



#ifndef SKY_RAYLEIGH_GLSL
#include "common/sky_rayleigh.glsl"
#endif


vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outVolumeColor){
    vec3  volumeColor  = vec3(0.0);
    vec3  mySky = vec3(0.0);

    float nearestHitT  = uMaxRayDistance;
    float viewTransmittance = 1.0;


    float opaqueT  = 1e20;
    vec3  surfN  = vec3(0.0);
    int matID  = INVALID_MATERIAL_ID;



    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i) {
        // atomicCounterIncrement(sdf);
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float d = getVolume(p);
        if (d < uSDFHitThreshold || volumetricDepth > nearestHitT) break;
        volumetricDepth += d;
    }


    if (volumetricDepth < nearestHitT) {

        vec3  lightDir = normalize(uSunDirection);
        vec3  lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

        float amplitude = 1.0;
        float stepScale = 1.0;

        for (int octave = 0; octave < 3; ++octave) {
            // atomicCounterIncrement(volume);
            float localStep = 0.6 * stepScale;
            float localDepth  = volumetricDepth;

            while (true) {

                localDepth += localStep;
                if (localDepth > nearestHitT) break;

                vec3 p = rayOrigin + rayDirection * localDepth;
                float sdf = getVolume(p);
                if (sdf >= 0.0) continue;
                float density = getDensity(p, sdf);


                float sigmaA = uVolumetricAbsorption  * density;
                float sigmaS = uVolumetricScattering * density;
                float sigmaT = sigmaA + sigmaS;

                //outscattering + absorption
                float prevTransmittance = viewTransmittance;
                viewTransmittance *= BeerLambert(sigmaT * amplitude, localStep);
                if (viewTransmittance < uTransmittanceThreshold) break;

                float lightAbsoprtion  = prevTransmittance - viewTransmittance;
                float lightScattering = lightAbsoprtion * (sigmaS / sigmaT);


                float shadowTransmittance = 1.0;
                float lightT = 0.0;

                for (int i = 0; i < uMaxShadowSteps; ++i)  {
                    //  atomicCounterIncrement(shadow);
                    vec3 pos = p + lightDir * lightT;
                    float sdfValue = getVolume(pos);
                    if (sdfValue < 0.0){

                        float density = getDensity(pos, sdfValue);
                        float sigmaT = (uVolumetricAbsorption + uVolumetricScattering) * density;
                        shadowTransmittance *= BeerLambert(sigmaT, uShadowStepSize);
                        if (shadowTransmittance < 0.01) break;
                    }
                    lightT += uShadowStepSize;
                }
                vec3  incident  = lightCol * shadowTransmittance;

                float mu  = dot(-rayDirection, lightDir);
                float phase = HenyeyGreenstein(mu, uPhaseG);

                volumeColor += amplitude * lightScattering * phase * incident;
                volumeColor += amplitude * lightAbsoprtion * ambientColor;
            }


            amplitude *= 0.5;
            stepScale *= 2.0;
        }
    }




    if (nearestHitT == uMaxRayDistance)
    {
        mySky = getRayleighSky(rayOrigin, rayDirection);
    }


    outVolumeColor = volumeColor;
    return clamp(volumeColor, 0.0, 1.0) + viewTransmittance * mySky;
}

#endif