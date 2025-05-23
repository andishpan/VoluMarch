#ifndef COMMON_RAYMARCH_GLSL
#define COMMON_RAYMARCH_GLSL



bool intersectWaterPlane(vec3 rayOrigin, vec3 rayDirection, out float closestT, out vec3 normal) {
    if (rayDirection.y == 0.0) return false;
    float tPlane = -rayOrigin.y / rayDirection.y;
    if (tPlane > EPSILON) {
        closestT = tPlane;
        normal = vec3(0.0, 1.0, 0.0);
        return true;
    }
    return false;
}


float shadowMarch(vec3 p, vec3 lightDir, float stepSize, int maxSteps) {
    float shadowTransmittance = 1.0;
    float lightT = 0.0;
    for (int i = 0; i < maxSteps; ++i) {
        vec3 samplePos = p + lightDir * lightT;

        float d = getVolume(samplePos);

        //float density = getDensity(samplePos,d);
        if (d < 0.0) {
            //shadowTransmittance *= BeerLambert(uVolumetricAbsorption * density, stepSize);
            shadowTransmittance *= BeerLambert(uVolumetricAbsorption, stepSize);
            if (shadowTransmittance < 0.01) break;
        }
        lightT += stepSize;
    }
    return shadowTransmittance;
}


float shadowMarchTest(vec3 p, vec3 lightDir,
float stepSize, int maxSteps,
inout int stepCounter)
{
    float lightT             = 0.0;
    float shadowTransmittance = 1.0;

    for (int i = 0; i < maxSteps; ++i) {
        ++stepCounter;

        vec3  samplePos = p + lightDir * lightT;
        float d         = getVolume(samplePos);

        if (d < 0.0) {
            shadowTransmittance *= BeerLambert(uVolumetricAbsorption, stepSize);
            if (shadowTransmittance < 0.01)
            break;
        }
        lightT += stepSize;
    }
    return shadowTransmittance;
}

float shadowMarchInOut(vec3 p, vec3 L, float step, int maxSteps){

    float shadowTransmittance = 1.0, t = 0.0;
    for (int i = 0; i < maxSteps; ++i)
    {
        vec3 pos = p + L * t;
        float sdfValue = getVolume(pos);
        if (sdfValue < 0.0)
        {
            float density   = getDensity(pos, sdfValue);
            float sigmaT = (uVolumetricAbsorption + uVolumetricScattering) * density;
            shadowTransmittance *= BeerLambert(sigmaT, step);
            if (shadowTransmittance < 0.01) break;
        }
        t += step;
    }
    return shadowTransmittance;
}

float shadowMarchInOutTest(vec3 p, vec3 L, float step, int maxSteps,
inout int shadowCounter)
{
    float Tr = 1.0, t = 0.0;
    for (int i = 0; i < maxSteps; ++i) {
        ++shadowCounter;
        vec3 pos = p + L * t;
        float sdf = getVolume(pos);
        if (sdf < 0.0) {
            float dens   = getDensity(pos, sdf);
            float sigmaT = (uVolumetricAbsorption + uVolumetricScattering)
            * dens;
            Tr *= BeerLambert(sigmaT, step);
            if (Tr < 0.01) break;
        }
        t += step;
    }
    return Tr;
}

float shadowMarchSchlick(vec3 p, vec3 lightDir, float stepSize, int maxSteps) {
    float shadowTransmittance = 1.0;
    float lightT = 0.0;
    for (int i = 0; i < maxSteps; ++i) {
        vec3 samplePos = p + lightDir * lightT;
        float d = getVolume(samplePos);
        if (d < 0.0) {
            shadowTransmittance *= SchlickExtinction(uVolumetricAbsorption, stepSize);
            if (shadowTransmittance < 0.01) break;
        }
        lightT += stepSize;
    }
    return shadowTransmittance;
}


float shadowMarchLinear(vec3 p, vec3 lightDir, float stepSize, int maxSteps) {
    float shadowTransmittance = 1.0;
    float lightT = 0.0;
    for (int i = 0; i < maxSteps; ++i) {
        vec3 samplePos = p + lightDir * lightT;
        float d = getVolume(samplePos);
        if (d < 0.0) {
            shadowTransmittance *= LinearExtinction(uVolumetricAbsorption, stepSize);
            if (shadowTransmittance < 0.01) break;
        }
        lightT += stepSize;
    }
    return shadowTransmittance;
}


float shadowMarchMOS(vec3 p, vec3 lightDir, float stepSize, int maxSteps, float extinctionScale) {
    float shadowTransmittance = 1.0;
    float lightT = 0.0;
    float sigma_t = uVolumetricAbsorption * extinctionScale;

    for (int i = 0; i < maxSteps; ++i) {
        vec3 samplePos = p + lightDir * lightT;
        float d = getVolume(samplePos);
        if (d < 0.0) {
            shadowTransmittance *= exp(-sigma_t * stepSize);
            if (shadowTransmittance < 0.01) break;
        }
        lightT += stepSize;
    }
    return shadowTransmittance;
}

float shadowMarchMOSTest(vec3 p, vec3 lightDir, float stepSize, int maxSteps, float extinctionScale, inout int shadowCounter) {
    float shadowTransmittance = 1.0;
    float lightT = 0.0;
    float sigma_t = uVolumetricAbsorption * extinctionScale;

    for (int i = 0; i < maxSteps; ++i) {
        ++shadowCounter;
        vec3 samplePos = p + lightDir * lightT;
        float d = getVolume(samplePos);
        if (d < 0.0) {
            shadowTransmittance *= exp(-sigma_t * stepSize);
            if (shadowTransmittance < 0.01) break;
        }
        lightT += stepSize;
    }
    return shadowTransmittance;
}






vec3 computeScattering(float fogDensity, float stepSize, float lightAbsorption, float volumetricAbsorption, float blendFactor, vec3 rayDirection, vec3 lightDir, vec3 lightColor) {
    float mu = dot(rayDirection, lightDir);
    float powderStrength = uPowderStrength * clamp(1.0 - mu, 0.0, 1.0);
    float powder = 1.0 - exp(-volumetricAbsorption * fogDensity * stepSize * powderStrength);

    vec3 absorbedLight = lightAbsorption * lightColor;
    vec3 scatteredLight = powder * lightColor;

    return mix(absorbedLight, scatteredLight, blendFactor);
}


vec3 computeMOS(vec3 rayOrigin, vec3 rayDirection, float startDepth, float endDepth, float stepSize) {
    vec3 scatterColor = vec3(0.0);
    float scatterScale = 1.0;
    float amplitude = 1.0;

    vec3 viewDir = -rayDirection;
    vec3 lightDir = normalize(uSunDirection);
    vec3 baseLightColor = vec3(1.0, 0.95, 0.8) * uSunIntensity;

    for (int octave = 0; octave < NUM_SCATTER_OCTAVES; octave++) {
        float localVDepth = startDepth;
        float localStep = stepSize / scatterScale;

        for (int i = 0; i < uMaxVolumeSteps; i++) {
            localVDepth += localStep;
            if (localVDepth > endDepth) break;

            vec3 p = rayOrigin + rayDirection * localVDepth;
            float sdfValue = getVolume(p);
            if (sdfValue < 0.0) {
                float fog = getDensity(p, sdfValue);


                float mu = dot(viewDir, lightDir);
                float scatter = MultipleOctaveScattering(fog, mu, stepSize);


                float lightT = 0.0;
               float shadowTransmittance = shadowMarch(p, lightDir, uShadowStepSize, uMaxLightMarchSteps);


                vec3 lightColor = shadowTransmittance * scatter * baseLightColor;
                vec3 scatterContribution = uVolumetricAlbedo * (lightColor + ambientColor);

                scatterColor += amplitude * scatterContribution;
            }
        }

        amplitude *= 0.5;
        scatterScale *= 2.0;
    }

    return scatterColor;
}




#endif