#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED

#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif

vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outvolumeColor){


    //const float uStepSize        = 0.6;
    float       viewTransmittance = 1.0;
    float       nearestHitT      = SCENE_MAX_T;

    vec3  surfaceNormal = vec3(0.0);
    int   materialId    = INVALID_MATERIAL_ID;
    float closestT      = 1e20;
    bool  hitOpaque     = false;


    float waterT;
    vec3  waterNormal;
    if (intersectWaterPlane(rayOrigin, rayDirection, waterT, waterNormal) && waterT < closestT){

        closestT      = waterT;
        surfaceNormal = waterNormal;
        materialId    = WATER_MATERIAL_ID;
        hitOpaque     = true;
        nearestHitT   = closestT;
    }


    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i){

        vec3  p        = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > nearestHitT)
        break;

        volumetricDepth += distance;
    }


    if (volumetricDepth < nearestHitT){
        for (int i = 0; i < uMaxVolumeSteps; ++i){

            volumetricDepth += uStepSize;
            if (volumetricDepth > nearestHitT)
            break;

            vec3  p        = rayOrigin + volumetricDepth * rayDirection;
            float sdfValue = getVolume(p);

            if (sdfValue < 0.0)
            {
                float density = getDensity(p, sdfValue);
                viewTransmittance *= BeerLambert(uVolumetricAbsorption *
                density,
                uStepSize);

                if (viewTransmittance < MIN_OPACITY)
                break;
            }
        }
    }


    vec3 surfaceColor;
    if (hitOpaque && materialId != INVALID_MATERIAL_ID){

        vec3 position = rayOrigin + rayDirection * closestT;
        getLighting(position, surfaceNormal, -rayDirection, materialId, surfaceColor);
    }
    else{

        surfaceColor = vec3(0.7, 0.85, 1.0);
    }


    outvolumeColor = vec3(0.0);
    return clamp(viewTransmittance * surfaceColor, 0.0, 1.0);
}

#endif