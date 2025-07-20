#ifndef RAYMARCH_MOS_DEFINED
#define RAYMARCH_MOS_DEFINED

#ifndef MARCH_SHADOW_GLSL
#include "common/marchShadow.glsl"
#endif


#ifndef SKY_RAYLEIGH_GLSL
#include "common/sky_rayleigh.glsl"
#endif
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
const float OCTAVE_CDF[8] = float[](
0.125, 0.250, 0.375, 0.500,
0.625, 0.750, 0.875, 1.000
);


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

    vec3 surfaceNormal = vec3(0.0);
    int  materialId = INVALID_MATERIAL_ID;

    uint localVolume = 0u;
    uint localSDF = 0u;
    uint localEntryCount= 0u;




    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i) {
        localSDF++;
        vec3 p = rayOrigin + volumetricDepth * rayDirection;
        float distance = getVolume(p);
        if (distance < uSDFHitThreshold || volumetricDepth > nearestHitT) break;
        volumetricDepth += distance;
    }


    if (volumetricDepth < nearestHitT) {
        localEntryCount++;
        for (int i = 0; i < uMaxVolumeSteps; ++i) {
            localVolume++;
            volumetricDepth += uStepSize;
            if (volumetricDepth > nearestHitT) break;
            vec3  lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

            vec3 p = rayOrigin + rayDirection * volumetricDepth;
            float sdfValue = getVolume(p);
            float density = getDensity(p, sdfValue);

            if (sdfValue < 0.0) {
                vec3  lightDir = normalize(uSunDirection);
                float cosTheta = dot(-rayDirection, lightDir);

                float sigmaA  = uVolumetricAbsorption * density;
                float sigmaS  = uVolumetricScattering * density;
                float random = pcgHash(dot(p, vec3(12.9898, 78.233, 37.719)) + float(i)*17.0);
                int selection = 0;
                for (int j = 0; j < MAX_OCTAVES; ++j) {
                    if (random < OCTAVE_CDF[j]) {
                        selection = j;
                        break;
                    }
                }

                float ai = OCTAVE_ATTEN[selection];
                float ci = OCTAVE_ECC[selection];
                float bi = OCTAVE_WEIGHTS[selection];

                float sigmaAi = sigmaA * ai;
                float sigmaSi = sigmaS * ai;
                float sigmaTi = sigmaAi + sigmaSi;

                float prevTransmittance = viewTransmittance;

                float stepTransmittance = exp(-sigmaTi * uStepSize);

                viewTransmittance *= stepTransmittance;
                if (viewTransmittance < uTransmittanceThreshold) continue;

                float lightAttenuation = prevTransmittance - viewTransmittance;

                float phase  = HenyeyGreenstein(cosTheta, uPhaseG * ci);
                float shadow = marchShadow(p, lightDir);

                volumeColor += (sigmaSi * phase * shadow * lightCol * 4.0 * lightAttenuation) / bi;

            }
        }
    }



    if(uUseCubeMap){
        mySky = texture(uEnvironmentMap, normalize(vRayDirection)).rgb;
    }else{
        mySky = getRayleighSky(rayOrigin, rayDirection);
    }


    outVolumeColor = volumeColor;
    atomicAdd(volume, localVolume);
    atomicAdd(sdf, localSDF);
    atomicAdd(entryCount, localEntryCount);


    vec3 hdrColor = volumeColor + viewTransmittance * mySky;
    vec3 mapped = hdrColor / (hdrColor + vec3(1.0));
    return mapped = clamp(mapped, 0.0, 1.0);
}

#endif
