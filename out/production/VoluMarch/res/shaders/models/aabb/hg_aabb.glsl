#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED





#ifndef MARCH_SHADOW_GLSL
#include "common/marchShadow.glsl"
#endif


#ifndef SKY_RAYLEIGH_GLSL
#include "common/sky_rayleigh.glsl"
#endif



vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outVolumeColor) {
    vec3 volumeColor = vec3(0.0);
    vec3 mySky = vec3(0.0);
    float nearestHitT  = uMaxRayDistance;
    float viewTransmittance = 1.0;
    float shadowTransmittance  = 1.0;

    vec3 surfaceNormal = vec3(0.0);
    int  materialId = INVALID_MATERIAL_ID;

    float closestT = 1e20;
    vec3 intersectionNormal = vec3(0.0);

    uint localVolume = 0u;
    uint localSDF = 0u;
    uint localEntryCount= 0u;

    // AABB intersection test
    vec3 boxMin, boxMax;
    getShapeAABB(uObjectShape, boxMin, boxMax);

    float pad = sdfBlendRadius + 1.0;
    boxMin -= vec3(pad);
    boxMax += vec3(pad);

    vec3 invDir = 1.0 / rayDirection;
    vec3 tMin = (boxMin - rayOrigin) * invDir;
    vec3 tMax = (boxMax - rayOrigin) * invDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);

    float tEntry = max(max(t1.x, t1.y), t1.z);
    float tExit = min(min(t2.x, t2.y), t2.z);


    if (tExit <= 0.0 || tEntry > tExit) {
        mySky = getRayleighSky(rayOrigin, rayDirection);
        outVolumeColor = vec3(0.0);
        vec3 hdrColor = viewTransmittance * mySky;
        vec3 mapped = hdrColor / (hdrColor + vec3(1.0));
        return clamp(mapped, 0.0, 1.0);
    }

    float volumetricDepth = max(tEntry, 0.0);

    for (int i = 0; i < uMaxSteps; i++) {
        localSDF++;
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < uSDFHitThreshold || volumetricDepth > tExit) break;
        volumetricDepth += distance;
    }

    if (volumetricDepth < tExit) {
        localEntryCount++;
        for (int i = 0; i < uMaxVolumeSteps; i++) {
            localVolume++;
            vec3 p = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);
            float stepSize = uStepSize * clamp(0.5 + abs(sdfValue), 0.1, 1.0);
            float density = getDensity(p, sdfValue);

            if (volumetricDepth > tExit) break;

            if (sdfValue < 0.0) {
                float sigmaA = uVolumetricAbsorption * density;
                float sigmaS = uVolumetricScattering * density;
                float sigmaT = sigmaA + sigmaS;

                float scatteringAlbedo = sigmaS / (sigmaT + 1e-5);
                float prevTransmittance = viewTransmittance;
                float stepTr = BeerLambert(sigmaT, stepSize);
                viewTransmittance *= stepTr;
                if (viewTransmittance < uTransmittanceThreshold) break;

                float lightAttenuation = prevTransmittance - viewTransmittance;

                vec3 lightDir = normalize(uSunDirection);
                vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;
                vec3 viewDir = normalize(rayDirection);

                float shadow = marchShadowAABB(p, lightDir);
                float HG = HenyeyGreenstein(dot(viewDir, lightDir), uPhaseG);

                vec3 energy = lightAttenuation * scatteringAlbedo * lightCol * 4.0 * shadow * HG;
                volumeColor += energy;
            }

            volumetricDepth += stepSize;
        }
    }

    vec3 sky = getRayleighSky(rayOrigin, rayDirection);
    outVolumeColor = volumeColor;
    atomicAdd(volume, localVolume);
    atomicAdd(sdf, localSDF);
    atomicAdd(entryCount, localEntryCount);
    vec3 hdrColor = volumeColor + viewTransmittance * sky;
    return clamp(hdrColor / (hdrColor + vec3(1.0)), 0.0, 1.0);
}


#endif