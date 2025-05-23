
#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED

#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif

#ifndef ADAPTIVE_STEP_GLSL
#include "common/adaptive_step.glsl"
#endif


vec3 raymarch(vec3 rayOrigin,  vec3 rayDirection, out vec3 outVolumeColor, out int  outPrimarySteps, out int  outShadowSteps, out int  outSdfSteps)
{

    int  primarySteps = 0;
    int  shadowSteps  = 0;
    int  sdfSteps     = 0;


    vec3  volumeColor   = vec3(0.0);
    vec3  surfaceColor  = vec3(0.0);
    float nearestHitT   = SCENE_MAX_T;
    float transmittance = 1.0;
    float lightTrans    = 1.0;

    vec3  surfaceNormal = vec3(0.0);
    int   materialId    = INVALID_MATERIAL_ID;


    float closestT      = 1e20;
    bool  hitOpaque     = false;
    vec3  intersectionNormal = vec3(0.0);

    float waterT; vec3 waterNormal;
    if (intersectWaterPlane(rayOrigin, rayDirection, waterT, waterNormal)) {
        closestT          = waterT;
        intersectionNormal= waterNormal;
        materialId        = WATER_MATERIAL_ID;
        hitOpaque         = true;
    }

    float opaqueDepth = closestT;
    if (hitOpaque) {
        surfaceNormal = intersectionNormal;
        nearestHitT   = opaqueDepth;
    }


    float depth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i) {
        ++sdfSteps;

        vec3  p        = rayOrigin + depth * rayDirection;
        float distance = getVolume(p);

        if (distance < SURFACE_DIST || depth > nearestHitT)
        break;

        depth += distance;
    }


    if (depth < nearestHitT) {
        for (int i = 0; i < uMaxVolumeSteps; ++i) {
            ++primarySteps;

            vec3  p        = rayOrigin + rayDirection * depth;
            float sdfValue = getVolume(p);
            float density  = getDensity(p, sdfValue);
            float stepSize = adaptiveStep(sdfValue, density);

            if (depth + stepSize > nearestHitT)
            break;

            if (sdfValue < 0.0) {
                float prevT   = transmittance;
                float stepT   = BeerLambert(uVolumetricAbsorption * density,
                stepSize);
                transmittance *= stepT;
                if (transmittance < MIN_OPACITY) break;

                float marchAbs = prevT - transmittance;
                vec3  lightDir = normalize(uSunDirection);
                vec3  lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                lightTrans = shadowMarchTest(p, lightDir,
                stepSize * 1.4,
                uMaxLightMarchSteps,
                shadowSteps);

                lightCol  *= lightTrans;
                vec3 scatter = marchAbs * lightCol;

                volumeColor += scatter * uVolumetricAlbedo;
                volumeColor += marchAbs * uVolumetricAlbedo * ambientColor;
            }
            depth += stepSize;
        }
    }


    if (hitOpaque && materialId != INVALID_MATERIAL_ID) {
        vec3 pos = rayOrigin + rayDirection * opaqueDepth;
        getLighting(pos, surfaceNormal, -rayDirection,
        materialId, surfaceColor);
    } else {
        surfaceColor = vec3(0.7, 0.85, 1.0);
    }


    outVolumeColor  = volumeColor;
    outPrimarySteps = primarySteps;
    outShadowSteps  = shadowSteps;
    outSdfSteps     = sdfSteps;

    return clamp(volumeColor, 0.0, 1.0) + transmittance * surfaceColor;
}


#endif
