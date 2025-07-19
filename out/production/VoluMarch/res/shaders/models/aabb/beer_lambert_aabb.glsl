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
    float shadowTransmittance  = 1.0;

    vec3 surfaceNormal = vec3(0.0);
    int  materialId = INVALID_MATERIAL_ID;

    float closestT = 1e20;
    vec3 intersectionNormal = vec3(0.0);

    uint localVolume = 0u;
    uint localSDF = 0u;
    uint localEntryCount= 0u;

    // --- AABB intersection test ---
    vec3 boxMin, boxMax;
    getShapeAABB(uObjectShape, boxMin, boxMax);

    float pad = sdfBlendRadius + 1.0; // fixed pad, not based on step size
    boxMin -= vec3(pad);
    boxMax += vec3(pad);

    vec3 invDir = 1.0 / rayDirection;
    vec3 tMin = (boxMin - rayOrigin) * invDir;
    vec3 tMax = (boxMax - rayOrigin) * invDir;
    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);

    float tEntry = max(max(t1.x, t1.y), t1.z);
    float tExit = min(min(t2.x, t2.y), t2.z);

    // Misses volume
    if (tExit <= 0.0 || tEntry > tExit) {
        mySky = getRayleighSky(rayOrigin, rayDirection);
        outVolumeColor = vec3(0.0);
        vec3 hdrColor = viewTransmittance * mySky;
        vec3 mapped = hdrColor / (hdrColor + vec3(1.0));
        return clamp(mapped, 0.0, 1.0);
    }

    float volumetricDepth = max(tEntry, 0.0);

    // --- Sphere trace to entry point ---
    for (int i = 0; i < uMaxSteps; i++) {
        localSDF++;
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < uSDFHitThreshold || volumetricDepth > tExit) {
            break;
        }
        volumetricDepth += distance;
    }

    if (volumetricDepth < tExit) {
        localEntryCount++;
        for (int i = 0; i < uMaxVolumeSteps; i++) {
            localVolume++;

            vec3 p = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);
            float density  = getDensity(p, sdfValue);

            if (volumetricDepth > tExit) break;

            if (sdfValue < 0.0) {
                float prevTransmittance = viewTransmittance;
                float stepTransmittance = BeerLambert(uVolumetricAbsorption * density, uStepSize);
                viewTransmittance *= stepTransmittance;
                if (viewTransmittance < uTransmittanceThreshold) break;

                float lightAttenuation = prevTransmittance - viewTransmittance;

                vec3  lightDir = normalize(uSunDirection);
                vec3  lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                shadowTransmittance = marchShadowAABB(p, lightDir);
                vec3 scatterLight = lightAttenuation * lightCol * shadowTransmittance;
                volumeColor += scatterLight;
            }

            volumetricDepth += uStepSize;
        }
    }

    mySky = getRayleighSky(rayOrigin, rayDirection);

    outVolumeColor = volumeColor;
    atomicAdd(volume, localVolume);
    atomicAdd(sdf, localSDF);
    atomicAdd(entryCount, localEntryCount);

    vec3 hdrColor = volumeColor + viewTransmittance * mySky;
    vec3 mapped = hdrColor / (hdrColor + vec3(1.0));
    return clamp(mapped, 0.0, 1.0);
}



#endif
