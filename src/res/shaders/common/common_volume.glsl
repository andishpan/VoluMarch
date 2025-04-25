#ifndef COMMON_VOLUME_GLSL
#define COMMON_VOLUME_GLSL

#define NUM_MATERIALS 3

uniform vec3 uAlbedo[NUM_MATERIALS];
uniform vec3 uEmissive[NUM_MATERIALS];
uniform int uFlags[NUM_MATERIALS];


vec3  GetMaterialAlbedo  (int id) { return uAlbedo  [id]; }
vec3  GetMaterialEmissive(int id) { return uEmissive[id]; }
int   GetMaterialFlags   (int id) { return uFlags   [id]; }


vec3  ambientColor;


vec3 diffuseLight(in vec3 normal, in vec3 lightVec, in vec3 diffuseLightColor){
    float nDotL = dot(normal, lightVec);
    return clamp(nDotL, 0.0, 1.0) * diffuseLightColor;
}




//water resources from water shader by Angelo Logahd (https://www.shadertoy.com/view/WlfXzB)
vec3 skyColor(vec3 dir) {
    dir.y = max(dir.y, 0.0);
    float fade = pow(1.0 - dir.y, 1.5);
    return vec3(0.2,0.2,0.2);
}

struct Wave {
    float amplitude;
    float wavelength;
    float speed;
    float steepness;
    vec2 direction;
};

float gerstnerWaveHeight(vec2 pos, float time, Wave w) {
    float k       = 2.0 * PI / w.wavelength;
    float theta   = dot(w.direction, pos) * k - w.speed * time;
    float height  = w.amplitude * sin(theta);
    return height;
}

vec2 gerstnerWaveHorizontalOffset(vec2 pos, float time, Wave w) {
    float k     = 2.0 * PI / w.wavelength;
    float theta = dot(w.direction, pos) * k - w.speed * time;
    float offset= w.steepness * w.amplitude * cos(theta);
    return w.direction * offset;
}

float waveHeightGerstner(vec2 uv, float time) {
    // 3 waves
    Wave waves[3];
    waves[0] = Wave(0.08, 10.0, 1.0, 0.3, normalize(vec2(1.0, 1.0)));
    waves[1] = Wave(0.05, 5.0,  1.3, 0.2, normalize(vec2(-1.0, 0.2)));
    waves[2] = Wave(0.03, 12.0, 0.9, 0.1, normalize(vec2(0.4, -1.0)));

    float totalHeight = 0.0;
    for (int i = 0; i < 3; i++) {
        totalHeight += gerstnerWaveHeight(uv, time, waves[i]);
    }
    return totalHeight;
}



vec3 getWaterNormal(vec3 pos) {
    float eps = 0.01;
    float h  = waveHeightGerstner(pos.xz, uTime);
    float hx = waveHeightGerstner(pos.xz + vec2(eps, 0.0), uTime);
    float hz = waveHeightGerstner(pos.xz + vec2(0.0, eps), uTime);
    return normalize(vec3(h - hx, eps, h - hz));
}

float getFresnel(vec3 N, vec3 V, float F0) {
    float cosTheta = clamp(dot(N, V), 0.0, 1.0);
    float oneMinus = 1.0 - cosTheta;
    return F0 + (1.0 - F0) * pow(oneMinus, 5.0);
}


void getLighting(vec3 position, vec3 normal, vec3 reflectionDir, vec3 rayDir, int materialID, inout vec3 color) {
    vec3 lightDir   = normalize(uSunDirection);
    vec3 lightColor = vec3(1.0, 0.95, 0.8) * uSunIntensity;

    vec3 diffuseLight = diffuseLight(normal, lightDir, GetMaterialAlbedo(materialID));
    color += lightColor * diffuseLight;

    float specular = pow(max(dot(reflectionDir, lightDir), 0.0), 8.0);
    color += lightColor * specular * GetMaterialAlbedo(materialID);

    color += GetMaterialEmissive(materialID);
    color += ambientColor * GetMaterialAlbedo(materialID);

    if (materialID == WATER_MATERIAL_ID) {

        vec3 waterNormal = getWaterNormal(position);
        vec3 reflectedDir = reflect(rayDir, waterNormal);
        vec3 refractedColor = vec3(0.02, 0.1, 0.15);


        vec3 reflectedColor = skyColor(reflectedDir);

        float F0 = 0.02;
        float fresnel = getFresnel(waterNormal, -rayDir, F0);

        color += mix(refractedColor, reflectedColor, fresnel);


        color +=  fresnel * 0.5;
    }
}
#endif