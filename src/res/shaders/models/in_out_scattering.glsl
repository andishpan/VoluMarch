#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED


#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif



vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outVolumeColor){

    vec3  volumeColor      = vec3(0.0);
    vec3  surfaceColor     = vec3(0.0);
    float viewTransmittance             = 1.0;
    float nearestHitT      = SCENE_MAX_T;
    //const float viewStep   = 0.6;


    float opaqueT  = 1e20;
    vec3  surfN    = vec3(0.0);
    int   matID    = INVALID_MATERIAL_ID;
    bool  hitSurf  = false;

    vec3 waterN; float waterT;
    if (intersectWaterPlane(rayOrigin, rayDirection, waterT, waterN) && waterT < opaqueT){
        opaqueT = waterT; surfN = waterN; matID = WATER_MATERIAL_ID; hitSurf = true;
    }
    if (hitSurf) nearestHitT = opaqueT;


    float vDepth = 0.0;
    for (int i = 0; i < uMaxSteps; ++i){
        vec3 p = rayOrigin + vDepth * rayDirection;
        float d = getVolume(p);
        if (d < SURFACE_DIST || vDepth > nearestHitT) break;
        vDepth += d;
    }


    if (vDepth < nearestHitT){
        vec3  lightDir        = normalize(uSunDirection);
        vec3  lightCol   = vec3(1.0,0.95,0.8) * uSunIntensity;

        for (int i = 0; i < uMaxVolumeSteps; ++i){
            vDepth += viewStep; if (vDepth > nearestHitT) break;
            vec3 p = rayOrigin + rayDirection * vDepth;
            float sdf = getVolume(p);
            if (sdf >= 0.0) continue;

            float dens   = getDensity(p, sdf);
            float sigmaA = uVolumetricAbsorption  * dens;
            float sigmaS = uVolumetricScattering * dens;
            float sigmaT = sigmaA + sigmaS;
            if (sigmaT <= 0.0) continue;

        //out scattering
            float prevTransmittance = viewTransmittance;
            viewTransmittance *= BeerLambert(sigmaT, viewStep);
            if (viewTransmittance < MIN_OPACITY) break;

            float lightAbsoprtion = prevTransmittance - viewTransmittance;
            float albedo   = sigmaS / sigmaT;
            float scatter  = lightAbsorption * albedo;


            float shadowT  = shadowMarchInOut(p, lightDir, uShadowStepSize, uMaxLightMarchSteps);
            vec3  inLight  = lightCol * shadowT;


            float mu    = dot(-rayDirection, lightDir);
            float phase = HenyeyGreenstein(mu, uPhaseG);

            //in scattering
            volumeColor += scatter * phase * inLight;
            volumeColor += scatter * ambientColor;
        }
    }


    if (hitSurf){
        vec3 hitPos = rayOrigin + rayDirection * opaqueT;
        getLighting(hitPos, surfN, -rayDirection, matID, surfaceColor);
    } else {
        surfaceColor = vec3(0.7,0.85,1.0);
    }

    outVolumeColor = volumeColor;
    return clamp(volumeColor,0.0,1.0) + viewTransmittance * surfaceColor;
}

#endif
