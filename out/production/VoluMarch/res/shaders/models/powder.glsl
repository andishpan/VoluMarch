#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED

#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif





vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outvolumeColor) {
    vec3 volumeColor       = vec3(0.0);
    vec3 surfaceColor       = vec3(0.0);
    float nearestHitT      = SCENE_MAX_T;
    float viewTransmittance = 1.0;
  //  const float uStepSize = 0.6;
    float shadowTransmittance = 1.0;

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
        surfaceNormal = intersectionNormal;
        nearestHitT = opaqueDepth;
    }

    //raymarch find entrypoint
    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; i++) {
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > nearestHitT) break;
        volumetricDepth += distance;
    }

    // raymarch inside volume =>
    if (volumetricDepth < nearestHitT) {
        for (int i = 0; i < uMaxVolumeSteps; i++) {
            volumetricDepth += uStepSize;
            if (volumetricDepth > nearestHitT) break;

            vec3 p = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);
            //point is inside volume , calculate absorption and scattering
            if (sdfValue < 0.0) {
                float density = getDensity(p, sdfValue);
                float prevTransmittance = viewTransmittance;

                float stepTransmittance = BeerLambert(uVolumetricAbsorption * density, uStepSize);
                viewTransmittance *= stepTransmittance;

                if (viewTransmittance < MIN_OPACITY) break;

                //light absorbed in this step
                float lightAbsorption = prevTransmittance - viewTransmittance;

                vec3 lightDir = normalize(uSunDirection);
                vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;



                // shadow ray marching
                // if (i % 10 == 0) {
               

                 shadowTransmittance = shadowMarch(p, lightDir,uShadowStepSize, uMaxLightMarchSteps);

                // }

                if (!isColorTooDark(lightCol)) {
                    lightCol *= shadowTransmittance;
                }

                vec3 scatterLight = computeScattering(density, uStepSize, lightAbsorption, uVolumetricAbsorption, uBlendFactor, rayDirection, lightDir, lightCol);


                volumeColor += scatterLight * uVolumetricAlbedo * viewTransmittance;
                volumeColor += lightAbsorption * uVolumetricAlbedo * ambientColor;
            }
        }
    }


    // surface shading
    if (hitOpaque && materialId != INVALID_MATERIAL_ID) {
        vec3 position = rayOrigin + rayDirection * opaqueDepth;

        getLighting(position, surfaceNormal, -rayDirection, materialId, surfaceColor);
    } else {
        surfaceColor = vec3(0.7, 0.85, 1.0);
    }

    outvolumeColor = volumeColor;
    return clamp(volumeColor, 0.0, 1.0) + viewTransmittance * surfaceColor;
}

#endif
