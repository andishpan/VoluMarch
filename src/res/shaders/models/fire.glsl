#ifndef RAYMARCH_FIRE_DEFINED
#define RAYMARCH_FIRE_DEFINED

#ifndef COMMON_RAYMARCH_GLSL
#include "common/common_raymarch.glsl"
#endif


const float uFireAbsorption  = 8.0;
const float uFireIntensity   = 40.0;
const vec3  uFireColorCool   = vec3(1.0, 0.3, 0.0);
const vec3  uFireColorHot    = vec3(1.2, 1.1, 1.0);


vec3 fireEmission(float temp){

    temp = clamp(temp, 0.0, 1.0);

    vec3 colour = mix(uFireColorCool, uFireColorHot, temp * temp * temp);
    return colour * uFireIntensity;
}


vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outVolumeColor){

   // const float uStepSize = 0.4;
    float viewTransmittance = 1.0;
    vec3  volumeColor      = vec3(0.0);


    float t = 0.0;
    for (int i = 0; i < uMaxSteps; ++i){

        vec3  p        = rayOrigin + t * rayDirection;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST) break;
        t += distance;
    }


    for (int i = 0; i < uMaxVolumeSteps; ++i){

        t += uStepSize;
        if (viewTransmittance < MIN_OPACITY) break;

        vec3  p        = rayOrigin + t * rayDirection;
        float sdfValue = getVolume(p);
        if (sdfValue >= 0.0) continue;

        float density = getDensity(p, sdfValue);
        float temp    = density;


        vec3  emission = fireEmission(temp) * density;
        volumeColor += viewTransmittance * emission * uStepSize;


        float stepTrans = BeerLambert(uFireAbsorption * density, uStepSize);
        viewTransmittance *= stepTrans;
    }


    vec3 background = vec3(0.0);
    outVolumeColor  = volumeColor;
    return clamp(volumeColor + viewTransmittance * background, 0.0, 1.0);
}

#endif
