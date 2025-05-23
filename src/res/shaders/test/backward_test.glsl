#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED

#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif

vec3 raymarch(vec3 rayOrigin, vec3 rayDir,
out vec3 outVolCol,out float outTransmittance,
out int outPrimary, out int outShadow,
out int outSdf)
{

    int primarySteps = 0;
    int shadowSteps  = 0;
    int sdfSteps     = 0;



    vec3  volumeColor   = vec3(0.0);
    vec3  surfaceColor  = vec3(0.0);
    float transmittance = 1.0;
    float nearestHitT   = SCENE_MAX_T;


    float opaqueT = 1e20;
    vec3  surfN   = vec3(0.0);
    int   matID   = INVALID_MATERIAL_ID;
    float waterT;
    vec3  waterN;

    if (intersectWaterPlane(rayOrigin, rayDir, waterT, waterN) && waterT < opaqueT) {
        opaqueT    = waterT;
        surfN      = waterN;
        matID      = WATER_MATERIAL_ID;
        nearestHitT = opaqueT;
    }


    float vDepth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i) {
        ++sdfSteps;

        vec3 p = rayOrigin + vDepth * rayDir;
        float d = getVolume(p);

        if (d < SURFACE_DIST || vDepth > nearestHitT)
        break;

        vDepth += d;
    }


    if (vDepth < nearestHitT) {

        vec3 lightDir = normalize(uSunDirection);
        vec3 sunCol   = vec3(1.0, 0.95, 0.8) * uSunIntensity;

        for (int i = 0; i < uMaxVolumeSteps; ++i) {
            ++primarySteps;

            vDepth += uStepSize;
            if (vDepth > nearestHitT)
            break;

            vec3 p = rayOrigin + rayDir * vDepth;
            float sdf = getVolume(p);

            if (sdf < 0.0) {

                float dens   = getDensity(p, sdf);
                float sigmaA = uVolumetricAbsorption * dens;
                float sigmaS = uVolumetricScattering * dens;
                float sigmaT = sigmaA + sigmaS;


                float prevT = transmittance;
                transmittance *= BeerLambert(sigmaT, uStepSize);

                if (transmittance < MIN_OPACITY)
                break;


                float stepExt = prevT - transmittance;
                float stepSca = stepExt * (sigmaS / sigmaT);


                float lightTr = shadowMarchInOutTest(
                p, lightDir,
                uShadowStepSize,
                uMaxLightMarchSteps,
                shadowSteps);

                vec3 incident = sunCol * lightTr;


                float mu    = dot(-rayDir, lightDir);
                float phase = HenyeyGreenstein(mu, uBackwardScattering);






                volumeColor += stepSca * phase * incident * uVolumetricAlbedo;


                volumeColor += stepExt * uVolumetricAlbedo * ambientColor;
            }

        }
    }


    if (matID != INVALID_MATERIAL_ID) {
        vec3 hitPos = rayOrigin + rayDir * opaqueT;
        getLighting(hitPos, surfN, -rayDir, matID, surfaceColor);
    } else {
        // Sky color fallback
        surfaceColor = vec3(0.7, 0.85, 1.0);
    }


    outVolCol  = volumeColor;
    outTransmittance = transmittance;
    outPrimary = primarySteps;
    outShadow  = shadowSteps;
    outSdf     = sdfSteps;


    return clamp(volumeColor, 0.0, 1.0) + transmittance * surfaceColor;
}

#endif
