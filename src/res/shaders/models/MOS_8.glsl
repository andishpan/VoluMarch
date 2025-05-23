
#ifndef RAYMARCH_MOS_DEFINED
#define RAYMARCH_MOS_DEFINED

#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif


const int   NUM_OCTAVES = 8;


const float OCTAVE_SCALES[NUM_OCTAVES] = float[](
1.0,
0.5,
0.25,
0.125,
0.0625,
0.03125,
0.015625,
0.0078125);


const float OCTAVE_ECC[NUM_OCTAVES] = float[](
0.6,
0.3,
0.15,
0.075,
0.0375,
0.01875,
0.009375,
0.0046875);


const float OCTAVE_WEIGHTS[NUM_OCTAVES] = float[](
0.5,
0.25,
0.125,
0.0625,
0.03125,
0.015625,
0.0078125,
0.00390625);


const float OCTAVE_CDF[NUM_OCTAVES] = float[](
0.5,
0.75,
0.875,
0.9375,
0.96875,
0.984375,
0.9921875,
1.0);


float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

int selectOctave(float seed) {
    float r = hash11(seed);
    for (int i = 0; i < NUM_OCTAVES; ++i) {
        if (r < OCTAVE_CDF[i]) return i;
    }
    return NUM_OCTAVES - 1;
}




vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outvolumeColor) {
    vec3 volumeColor       = vec3(0.0);
    vec3 surfaceColor       = vec3(0.0);
    float nearestHitT  = SCENE_MAX_T;
    float viewTransmittance = 1.0;
    //const float uStepSize = 0.3;

    vec3 surfaceNormal       = vec3(0.0);
    int  materialId   = INVALID_MATERIAL_ID;


    float closestT = 1e20;
    vec3 intersectionNormal = vec3(0.0);
    bool hitOpaque = false;
    float waterT;
    vec3  waterNormal;
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


    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i) {
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > nearestHitT) break;
        volumetricDepth += distance;
    }


    if (volumetricDepth < nearestHitT) {
        for (int i = 0; i < uMaxVolumeSteps; ++i) {
            volumetricDepth += uStepSize;
            if (volumetricDepth > nearestHitT) break;

            vec3 p = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);

            if (sdfValue < 0.0) {
                float density = getDensity(p, sdfValue);

                vec3 lightDir   = normalize(uSunDirection);
                vec3 lightColor = vec3(1.0, 0.95, 0.8) * uSunIntensity;
                vec3 ambient    = ambientColor * 0.5;

                // Stochastic roulette selection

                int octave = selectOctave(volumetricDepth + p.x + p.y + p.z);

                float scale   = OCTAVE_SCALES[octave];
                float g       = OCTAVE_ECC[octave];
                float weight  = OCTAVE_WEIGHTS[octave] * float(NUM_OCTAVES);

                float sigmaT = uVolumetricAbsorption * density * scale;
                vec3  sigmaS = uVolumetricAlbedo    * density * scale;

                float stepTransmittance  = exp(-sigmaT * uStepSize);
                float lightAbsorption = (1.0 - stepTransmittance) * viewTransmittance;
                viewTransmittance *= stepTransmittance;
                if (viewTransmittance < MIN_OPACITY) continue;

                float cosTheta = dot(-rayDirection, lightDir);
                float phase    = HenyeyGreenstein(cosTheta, g);

                float shadowTransmittance = shadowMarchMOS(p, lightDir, uShadowStepSize, uMaxLightMarchSteps,scale);
                vec3 scatter  = lightColor * (sigmaS * phase * shadowTransmittance);
                volumeColor += weight * scatter * lightAbsorption;
                volumeColor += ambient * lightAbsorption;
            }
        }
    }


    if (hitOpaque && materialId != INVALID_MATERIAL_ID) {
        vec3 position      = rayOrigin + rayDirection * opaqueDepth;

        getLighting(position, surfaceNormal, -rayDirection, materialId, surfaceColor);
    } else {
        surfaceColor = vec3(0.7, 0.85, 1.0);
    }

    outvolumeColor = volumeColor;
    return clamp(volumeColor, 0.0, 1.0) + viewTransmittance * surfaceColor;
}

#endif
