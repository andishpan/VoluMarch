#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED


#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif




vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outVolumeColor){

    vec3  volumeColor       = vec3(0.0);
    vec3  surfaceColor      = vec3(0.0);
    float viewTransmittance        = 1.0;
    float nearestHitT       = SCENE_MAX_T;
    const float uStepSize  = 0.6;


    float opaqueT = 1e20;  vec3 surfN = vec3(0.0);
    int   matID   = INVALID_MATERIAL_ID;
    vec3  waterN; float waterHitT;

    if (intersectWaterPlane(rayOrigin, rayDirection, waterHitT, waterN) && waterHitT < opaqueT){
        opaqueT  = waterHitT;
        surfN    = waterN;
        matID    = WATER_MATERIAL_ID;
        nearestHitT = opaqueT;
    }


    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i){
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float d = getVolume(p);
        if (d < SURFACE_DIST || volumetricDepth > nearestHitT) break;
        volumetricDepth += d;
    }


    if (volumetricDepth < nearestHitT){
        vec3 lightDir       = normalize(uSunDirection);
        vec3 lightCol  = vec3(1.0,0.95,0.8) * uSunIntensity;

        for (int i = 0; i < uMaxVolumeSteps; ++i){

            if (volumetricDepth > nearestHitT) break;

            vec3  p   = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);
            if (sdfValue < 0.0){
                float dens   = getDensity(p, sdfValue);
                float sigmaA = uVolumetricAbsorption  * dens;
                float sigmaS = uVolumetricScattering * dens;
                float sigmaT = sigmaA + sigmaS;


                float prevTransmittance = viewTransmittance;
                viewTransmittance *= BeerLambert(sigmaT, uStepSize);
                if (viewTransmittance < MIN_OPACITY) break;

                float lightAbsorption   = prevTransmittance - viewTransmittance;
                float lightScattering = lightAbsorption * (sigmaS / sigmaT);


                float shadowTransmittance   = 1.0;
                shadowTransmittance = shadowMarchInOut(p, lightDir, uShadowStepSize, uMaxLightMarchSteps);
                vec3  incident = lightCol * shadowTransmittance;


                float mu    = dot(-rayDirection, lightDir);
                float phase = HenyeyGreenstein(mu, uBackwardScattering);

                volumeColor += lightScattering * phase * incident * uVolumetricAlbedo;
                volumeColor += lightAbsorption   *  uVolumetricAlbedo * ambientColor;
            }

            volumetricDepth += uStepSize;
        }
    }


    if (matID != INVALID_MATERIAL_ID){
        vec3 hitPos = rayOrigin + rayDirection * opaqueT;
        getLighting(hitPos, surfN, -rayDirection, matID, surfaceColor);
    } else {
        surfaceColor = vec3(0.7,0.85,1.0);
    }

    outVolumeColor = volumeColor;
    return clamp(volumeColor,0.0,1.0) + viewTransmittance * surfaceColor;
}


#endif
