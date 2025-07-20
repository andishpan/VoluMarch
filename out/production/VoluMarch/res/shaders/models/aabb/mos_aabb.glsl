#ifndef RAYMARCH_MOS_DEFINED
#define RAYMARCH_MOS_DEFINED

#ifndef MARCH_SHADOW_GLSL
#include "common/marchShadow.glsl"
#endif


#ifndef SKY_RAYLEIGH_GLSL
#include "common/sky_rayleigh.glsl"
#endif


// —————— MOS parameters (8 octaves) ——————
const int MAX_OCTAVES = 8;
const float OCTAVE_ATTEN[8] = float[](
0.5, 0.5, 0.5, 0.5,
0.5, 0.5, 0.5, 0.5
);// aᵢ

const float OCTAVE_ECC[8] = float[](
0.5, 0.5, 0.5, 0.5,
0.5, 0.5, 0.5, 0.5
);// cᵢ

const float OCTAVE_WEIGHTS[8] = float[](
0.125, 0.125, 0.125, 0.125,
0.125, 0.125, 0.125, 0.125
);// bᵢ = 1/8

// precomputed CDF of weights:
const float OCTAVE_CDF[8] = float[](
0.125, 0.250, 0.375, 0.500,
0.625, 0.750, 0.875, 1.000
);

/*float hash11(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
} */
//https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
float pcgHash(float seed) {
    uint x = floatBitsToUint(seed);
    x = x * 747796405u + 2891336453u;
    uint word = ((x >> ((x >> 28u) + 4u)) ^ x) * 277803737u;
    return float((word >> 22u) ^ word) / float(0xffffffffu);
}


int selectOctave(float seed) {
    for (int i = 0; i < MAX_OCTAVES; ++i)
    if (seed < OCTAVE_CDF[i]) return i;
    return MAX_OCTAVES - 1;
}



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

    for (int i = 0; i < uMaxSteps; ++i) {
        localSDF++;
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < uSDFHitThreshold || volumetricDepth > tExit) break;
        volumetricDepth += distance;
    }

    if (volumetricDepth < tExit) {
        localEntryCount++;
        for (int i = 0; i < uMaxVolumeSteps; ++i) {
            localVolume++;
            if (volumetricDepth > tExit) break;
            vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;
            vec3 p = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);
            float density = getDensity(p, sdfValue);

            if (sdfValue < 0.0) {
                vec3 lightDir = normalize(uSunDirection);
                float cosTheta = dot(-rayDirection, lightDir);
                float sigmaA = uVolumetricAbsorption * density;
                float sigmaS = uVolumetricScattering * density;

                float random = pcgHash(dot(p, vec3(12.9898, 78.233, 37.719)) + float(i) * 17.0);
                int selection = selectOctave(random);

                float ai = OCTAVE_ATTEN[selection];
                float ci = OCTAVE_ECC[selection];
                float bi = OCTAVE_WEIGHTS[selection];

                float sigmaTi = (sigmaA + sigmaS) * ai;

                float prevTransmittance = viewTransmittance;
                viewTransmittance *= exp(-sigmaTi * uStepSize);
                if (viewTransmittance < uTransmittanceThreshold) continue;

                float lightAttenuation = prevTransmittance - viewTransmittance;
                float phase = HenyeyGreenstein(cosTheta, uPhaseG * ci);
                float shadow = marchShadowAABB(p, lightDir);

                volumeColor += (sigmaS * ai * phase * shadow * lightCol * 4.0 * lightAttenuation) / (bi + 1e-5);
            }

            volumetricDepth += uStepSize;
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
