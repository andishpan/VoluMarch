#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED


#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif



//#ifndef ADAPTIVE_STEP_GLSL
//#include "common/adaptive_step.glsl"
//#endif


vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outvolumeColor) {
    vec3 volumeColor       = vec3(0.0);
    vec3 surfaceColor       = vec3(0.0);
    float nearestHitT  = SCENE_MAX_T;
    float viewTransmittance = 1.0;
    //const float uStepSize = 0.6;
    float shadowTransmittance  = 1.0;

    vec3 surfaceNormal       = vec3(0.0);
    int  materialId   = INVALID_MATERIAL_ID;

    float closestT = 1e20;
    vec3 intersectionNormal = vec3(0.0);
    bool hitOpaque = false;


    float waterT;
    vec3 waterNormal;
    if (intersectWaterPlane(rayOrigin, rayDirection, waterT, waterNormal)) {
        if (waterT < closestT) {
            closestT = waterT;
            intersectionNormal = waterNormal;
            materialId = WATER_MATERIAL_ID;
            hitOpaque = true;
        }
    }

    float opaqueDepth = closestT;
    if (hitOpaque) {
        surfaceNormal      = intersectionNormal;
        nearestHitT  = opaqueDepth;
    }

    // find entry point
    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; i++) {
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > nearestHitT) break;

        volumetricDepth += distance;
    }


    //volume ray march
    if (volumetricDepth < nearestHitT) {
        for (int i = 0; i < uMaxVolumeSteps; i++) {
           // volumetricDepth += uStepSize;
            //if (volumetricDepth > nearestHitT) break;

            vec3 p = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);
            float density  = getDensity(p, sdfValue);
            //float stepSize = adaptiveStep(sdfValue,density);

            if (volumetricDepth + uStepSize > nearestHitT) break;
            // inside volume – Beer–Lambert absorption only
            if (sdfValue < 0.0) {
               // float density           = getDensity(p, sdfValue);
                float prevTransmittance = viewTransmittance;

                // Beer–Lambert viewTransmittance along the view ray
                float stepTransmittance = BeerLambert(uVolumetricAbsorption * density, uStepSize);
                viewTransmittance *= stepTransmittance;

                if (viewTransmittance < MIN_OPACITY) break;

                // light absorbed in this step
                float lightAbsorption = prevTransmittance - viewTransmittance;

                // direct lighting
                vec3  lightDir = normalize(uSunDirection);
                vec3  lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                // shadow ray


                shadowTransmittance = shadowMarch(p, lightDir, uShadowStepSize, uMaxLightMarchSteps);

                if (!isColorTooDark(lightCol)) {
                    lightCol *= shadowTransmittance;
                }

                // No "powder" forward–scattering term – pure Beer–Lambert absorption
                vec3 scatterLight = lightAbsorption * lightCol;

                volumeColor += scatterLight * uVolumetricAlbedo;
                volumeColor += lightAbsorption * uVolumetricAlbedo * ambientColor;
            }
            volumetricDepth += uStepSize;
        }
    }

    // --- SURFACE SHADING ---------------------------------------------------------------
    if (hitOpaque && materialId != INVALID_MATERIAL_ID) {
        vec3 position      = rayOrigin + rayDirection * opaqueDepth;

        getLighting(position, surfaceNormal, -rayDirection, materialId, surfaceColor);
    } else {
        // Sky / background colour
        surfaceColor = vec3(0.7, 0.85, 1.0);
    }

    outvolumeColor = volumeColor;
    //maybe removes needed hdr info for tone mapping
    return clamp(volumeColor, 0.0, 1.0) + viewTransmittance * surfaceColor;
}

#endif
