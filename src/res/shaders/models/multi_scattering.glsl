#ifndef RAYMARCH_DEFINED
#define RAYMARCH_DEFINED

#ifndef MARCH_SHADOW_GLSL
#include "common/marchShadow.glsl"
#endif

#ifndef SKY_RAYLEIGH_GLSL
#include "common/sky_rayleigh.glsl"
#endif


vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outVolumeColor)
{
    vec3 skyColor = getRayleighSky(rayOrigin,rayDirection);
    vec3 color = skyColor;
    outVolumeColor = vec3(0.0);
    float viewTransmittance = 1.0;

    const float MAX_DISTANCE = 30.0;
    const float HEIGHT_OFFSET = 0.2;
    const int NUM_OCTAVES = 4;

    for (float dist = uMaxRayDistance; dist > 0.0; dist -= uStepSize)
    {
        vec3 position = dist * rayDirection + rayOrigin;

        vec3 windOffset = vec3(1.0,0.0,0.0) * 5.5 * uTime;
        vec3 fbmInput   = (position + windOffset) / uNoiseScale;
        float noise     = uNoiseHeight * fbm(fbmInput);

        float cloudSignedDistance = position.y + noise;

        if (cloudSignedDistance < 0.0) {
            float density = clamp(-cloudSignedDistance, 0.0, 1.0);

            // Optical properties
            float sigmaA = uVolumetricAbsorption * density;
            float sigmaS = uVolumetricScattering * density;
            float sigmaT = sigmaA + sigmaS;

            float stepTransmittance = exp(-sigmaT * uStepSize);
            float prevTransmittance = viewTransmittance;
            viewTransmittance *= stepTransmittance;

            if (viewTransmittance < uTransmittanceThreshold) break;

            float lightAttenuation = prevTransmittance - viewTransmittance;

            // Lighting
            vec3 lightDir = normalize(uSunDirection);
            vec3 lightColor = vec3(1.0, 0.95, 0.8) * uSunIntensity;
            vec3 viewDir = normalize(rayDirection);

            float shadow = marchShadow(position, lightDir); // optional: if defined
            float phase  = HenyeyGreenstein(dot(viewDir, lightDir), uPhaseG);

            float scatteringAlbedo = sigmaT > 0.0 ? sigmaS / sigmaT : 0.0;

            vec3 inscatter = lightAttenuation * scatteringAlbedo * lightColor * shadow * phase;

            vec3 cloudColor = vec3(1.0); // white cloud
            color = mix(color, cloudColor, lightAttenuation * 0.4);
            outVolumeColor += inscatter;
        }

    }

    color = clamp(color, 0.0, 1.0);
    color = color * color * (3.0 - 2.0 * color); // contrast

    float sat = 0.2;
    color = color * (1.0 + sat) - sat * dot(color, vec3(0.33));

    return color;
}







#endif
