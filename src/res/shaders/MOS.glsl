#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED

vec3 raymarch(vec3 rayOrigin, vec3 rayDir, out vec3 outVColor) {
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float finalDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;

    vec3 normal       = vec3(0.0);
    vec3 vnormal      = vec3(0.0);
    int  vmaterialId  = INVALID_MATERIAL_ID;
    int  materialId   = INVALID_MATERIAL_ID;


    float t = 1e20;
    vec3 intersectionNormal = vec3(0.0);
    materialId = WATER_MATERIAL_ID;



    if (rayDir.y != 0.0) {
        float tPlane = -rayOrigin.y / rayDir.y;
        if (tPlane > EPSILON && tPlane < t) {
            t = tPlane;
            intersectionNormal = vec3(0.0, 1.0, 0.0);
            materialId = WATER_MATERIAL_ID;
        }
    }


    normal = intersectionNormal;
    float opaqueDepth = t;
    if (materialId != INVALID_MATERIAL_ID) {
        finalDepth = opaqueDepth;
    }


    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; i++) {
        vec3 p = rayOrigin + volumetricDepth * rayDir;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > finalDepth) break;
        volumetricDepth += distance;
    }


    if (volumetricDepth < finalDepth){

        float scatterScale = 1.0;
        float scatterStrength = 1.0;
        float amplitude = 1.0;
        float visibility = 0.0;

        for (int octave = 0; octave < NUM_SCATTER_OCTAVES; octave++) {
            float localVDepth = volumetricDepth;
            float localStep = marchSize / scatterScale;

            for (int i = 0; i < uMaxVolumeSteps; i++) {
                localVDepth += localStep;
                if (localVDepth > opaqueDepth) break;

                vec3 p = rayOrigin + rayDir * localVDepth;
                float sdfValue = getVolume(p);
                if (sdfValue < 0.0) {
                    float prevVisibility = oVisibility;
                    float fog = getDensity(p, sdfValue);

                    oVisibility *= BeerLambert(uVolumetricAbsorption * fog, localStep);

                    if (oVisibility < MIN_OPACITY) break;

                    float marchAbsorption = prevVisibility - oVisibility;

                    vec3 viewDir = -rayDir;
                    vec3 lightDir = normalize(uSunDirection);
                    vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                    if (!isColorTooDark(lightCol)) {
                        float mu = dot(viewDir, lightDir);

                        //  if (i % 6 == 0) {
                        visibility = 1.0;
                        float lightT = 0.0;
                        for (int j = 0; j < uMaxLightMarchSteps; j++) {
                            lightT += marchSize * 1.4;
                            vec3 currentLightPoint = p + lightDir * lightT;
                            if (getVolume(currentLightPoint) < 0.0) {
                                visibility *= BeerLambert(uVolumetricAbsorption, marchSize * 1.4);
                                if (visibility < 0.01) break;
                            }
                        }
                        // }

                        float scatter = MultipleOctaveScattering(fog, mu);
                        lightCol *= visibility * scatter;
                    }

                    vec3 scatterContribution = marchAbsorption * uVolumetricAlbedo * lightCol;
                    vColor += amplitude * scatterContribution;


                    vColor += amplitude * marchAbsorption * uVolumetricAlbedo * ambientColor;
                }
            }

            amplitude *= 0.5;
            scatterScale *= 2.0;
        }

    }


    if (materialId != INVALID_MATERIAL_ID){

        vec3 position = rayOrigin + rayDir * opaqueDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        getLighting(position, normal, reflectionDir, rayDir,materialId, oColor);
    }
    else {

        oColor = vec3(0.7, 0.85, 1.0);
    }

    outVColor = vColor;
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}

#endif
