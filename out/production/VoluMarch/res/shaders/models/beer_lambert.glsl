#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED

vec3 raymarch(vec3 rayOrigin, vec3 rayDir, out vec3 outVColor) {
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float finalDepth  = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;
    float visibility  = 1.0;

    vec3 normal       = vec3(0.0);
    int  materialId   = INVALID_MATERIAL_ID;

    float t = 1e20;
    vec3 intersectionNormal = vec3(0.0);
    bool hitOpaque = false;

    // water plane intersection
    if (rayDir.y != 0.0) {
        float tPlane = -rayOrigin.y / rayDir.y;
        if (tPlane > EPSILON && tPlane < t) {
            t = tPlane;
            intersectionNormal = vec3(0.0, 1.0, 0.0);
            materialId   = WATER_MATERIAL_ID;
            hitOpaque    = true;
        }
    }

    float opaqueDepth = t;
    if (hitOpaque) {
        normal      = intersectionNormal;
        finalDepth  = opaqueDepth;
    }

    // find entry point
    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; i++) {
        vec3 p = rayOrigin + volumetricDepth * rayDir;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > finalDepth) break;

        volumetricDepth += distance;
    }


    //volume ray march
    if (volumetricDepth < finalDepth) {
        for (int i = 0; i < uMaxVolumeSteps; i++) {
            volumetricDepth += marchSize;
            if (volumetricDepth > finalDepth) break;

            vec3 p = rayOrigin + rayDir * volumetricDepth;
            float sdfValue = getVolume(p);

            // inside volume – Beer–Lambert absorption only
            if (sdfValue < 0.0) {
                float fog           = getDensity(p, sdfValue);
                float prevVisibility = oVisibility;

                // Beer–Lambert transmittance along the view ray
                float T = BeerLambert(uVolumetricAbsorption * fog, marchSize);
                oVisibility *= T;

                if (oVisibility < MIN_OPACITY) break;

                // light absorbed in this step
                float marchAbsorption = prevVisibility - oVisibility;

                // direct lighting
                vec3  lightDir = normalize(uSunDirection);
                vec3  lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                // shadow ray
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

                if (!isColorTooDark(lightCol)) {
                    lightCol *= visibility;
                }

                // No "powder" forward–scattering term – pure Beer–Lambert absorption
                vec3 scatterLight = marchAbsorption * lightCol;

                vColor += scatterLight * uVolumetricAlbedo;
                vColor += marchAbsorption * uVolumetricAlbedo * ambientColor;
            }
        }
    }

    // --- SURFACE SHADING ---------------------------------------------------------------
    if (hitOpaque && materialId != INVALID_MATERIAL_ID) {
        vec3 position      = rayOrigin + rayDir * opaqueDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        getLighting(position, normal, reflectionDir, rayDir, materialId, oColor);
    } else {
        // Sky / background colour
        oColor = vec3(0.7, 0.85, 1.0);
    }

    outVColor = vColor;
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}

#endif
