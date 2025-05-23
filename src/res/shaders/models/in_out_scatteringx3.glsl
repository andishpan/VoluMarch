#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED


#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif




vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outVolumeColor){
    vec3  volumeColor  = vec3(0.0);
    vec3  surfaceColor = vec3(0.0);

    float nearestHitT      = SCENE_MAX_T;
    float viewTransmittance = 1.0;


    float opaqueT  = 1e20;
    vec3  surfN    = vec3(0.0);
    int   matID    = INVALID_MATERIAL_ID;

    vec3 waterN; float waterHitT;
    if (intersectWaterPlane(rayOrigin, rayDirection, waterHitT, waterN) && waterHitT < opaqueT) {

        opaqueT = waterHitT;  surfN = waterN;  matID = WATER_MATERIAL_ID;
        nearestHitT = opaqueT;
    }


    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i) {

        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float d = getVolume(p);
        if (d < SURFACE_DIST || volumetricDepth > nearestHitT) break;
        volumetricDepth += d;
    }


    if (volumetricDepth < nearestHitT) {

        vec3  lightDir = normalize(uSunDirection);
        vec3  lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

        float amplitude   = 1.0;
        float stepScale   = 1.0;

        for (int octave = 0; octave < 3; ++octave) {

            float localStep   = 0.6 * stepScale;
            float localDepth  = volumetricDepth;

            while (true) {

                localDepth += localStep;
                if (localDepth > nearestHitT) break;

                vec3 p = rayOrigin + rayDirection * localDepth;
                float sdf = getVolume(p);
                if (sdf >= 0.0) continue;
                float density   = getDensity(p, sdf);


                float sigmaA = uVolumetricAbsorption  * density;
                float sigmaS = uVolumetricScattering * density;
                float sigmaT = sigmaA + sigmaS;

                 //outscattering + absorption
                float prevTransmittance = viewTransmittance;
                viewTransmittance *= BeerLambert(sigmaT * amplitude, localStep);
                if (viewTransmittance < MIN_OPACITY) break;

                float lightAbsoprtion  = prevTransmittance - viewTransmittance;
                float lightScattering = lightAbsoprtion * (sigmaS / sigmaT);


                float shadowT   = shadowMarchInOut(p, lightDir, uShadowStepSize, uMaxLightMarchSteps);
                vec3  incident  = lightCol * shadowT;

                float mu    = dot(-rayDirection, lightDir);
                float phase = HenyeyGreenstein(mu, uPhaseG);

                volumeColor += amplitude * lightScattering * phase * incident * uVolumetricAlbedo;
                volumeColor += amplitude * lightAbsoprtion  * uVolumetricAlbedo * ambientColor;
            }


            amplitude *= 0.5;
            stepScale *= 2.0;
        }
    }


    if (matID != INVALID_MATERIAL_ID)   {

        vec3 hitPos = rayOrigin + rayDirection * opaqueT;
        getLighting(hitPos, surfN, -rayDirection, matID, surfaceColor);
    }
    else surfaceColor = vec3(0.7, 0.85, 1.0);

    outVolumeColor = volumeColor;
    return clamp(volumeColor, 0.0, 1.0) + viewTransmittance * surfaceColor;
}

#endif