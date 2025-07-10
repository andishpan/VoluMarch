#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED



#ifndef MARCH_SHADOW_GLSL
#include "common/marchShadow.glsl"
#endif

//#ifndef ADAPTIVE_STEP_GLSL
//#include "common/adaptive_step.glsl"
//#endif

#ifndef SKY_RAYLEIGH_GLSL
#include "common/sky_rayleigh.glsl"
#endif


vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outVolumeColor) {

    vec3 volumeColor = vec3(0.0);
    vec3 mySky = vec3(0.0);
    float nearestHitT  = uMaxRayDistance;
    float viewTransmittance = 1.0;
    //const float uStepSize = 0.6;
    float shadowTransmittance  = 1.0;

    vec3 surfaceNormal = vec3(0.0);
    int  materialId = INVALID_MATERIAL_ID;

    float closestT = 1e20;
    vec3 intersectionNormal = vec3(0.0);

    uint localVolume = 0u;
    uint localSDF = 0u;

    uint localEntryCount= 0u;

    // find entry point using sphere tracing with adaptive stepsize
    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; i++) {
        localSDF++;
        //sdf++;
        //atomicCounterIncrement(sdf);
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < uSDFHitThreshold || volumetricDepth > nearestHitT) {
            break;
        }

        volumetricDepth += distance;
    }


    //volume ray march fixed step size with lighting
    if (volumetricDepth < nearestHitT) {
        localEntryCount++;
        // atomicCounterIncrement(entryCount);
        for (int i = 0; i < uMaxVolumeSteps; i++) {
            localVolume++;
            // primary++;
            // atomicCounterIncrement(volume);
            // volumetricDepth += uStepSize;
            //if (volumetricDepth > nearestHitT) break;

            vec3 p = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);
            float density  = getDensity(p, sdfValue);
            //float stepSize = adaptiveStep(sdfValue,density);

            if (volumetricDepth  > nearestHitT) break;
            // inside volume – Beer–Lambert absorption only
            if (sdfValue < 0.0) {
                // float density   = getDensity(p, sdfValue);
                float prevTransmittance = viewTransmittance;

                // Beer–Lambert viewTransmittance along the view ray
                float stepTransmittance = BeerLambert(uVolumetricAbsorption * density, uStepSize);
                //float alpha = sigmaT * uStepSize;
                // float stepTransmittance = exp(-alpha + 0.000001);
                viewTransmittance *= stepTransmittance;

                if (viewTransmittance < uTransmittanceThreshold) break;

                // light absorbed in this step
                float lightAttenuation = prevTransmittance - viewTransmittance;

                // direct lighting
                vec3  lightDir = normalize(uSunDirection);
                vec3  lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                // shadow ray


                float shadowTransmittance = marchShadowAABB(p, lightDir);

                if (!isColorTooDark(lightCol)) {
                    lightCol *= shadowTransmittance;
                }


                vec3 scatterLight = lightAttenuation * lightCol * shadowTransmittance;

                volumeColor += scatterLight;

                //volumeColor += lightAttenuation  * ambientColor;


            }
            volumetricDepth += uStepSize;
        }
    }

    // Sky / background colour

    // mySky = vec3(0.7,0.85,1.0);
    if (nearestHitT == uMaxRayDistance)
    {
        mySky = getRayleighSky(rayOrigin, rayDirection);
    }



    outVolumeColor = volumeColor;
    atomicAdd(volume, localVolume);
    atomicAdd(sdf, localSDF);
    atomicAdd(entryCount, localEntryCount);


    //maybe removes needed hdr info for tone mapping
    // return clamp(volumeColor, 0.0, 1.0) + viewTransmittance * mySky;
    vec3 hdrColor = volumeColor + viewTransmittance * mySky;
    vec3 mapped = hdrColor / (hdrColor + vec3(1.0));
    return mapped = clamp(mapped, 0.0, 1.0);

}

#endif
