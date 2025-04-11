#version 330 core


out vec4 fragColor;

uniform vec3  uResolution;
uniform float uTime;
uniform sampler2D iChannel0;

//light
uniform vec3 uSunDirection;
uniform float uSunIntensity;
uniform vec3 uAmbientLight;
uniform vec3 uVolumetricAlbedo;

uniform int uCurrentMethod;
uniform float uVolumetricAbsorption;

//shape
uniform int uObjectShape;
uniform int uPrevShape;
uniform float uShapeTransition;

//noise
uniform int uCurrentNoise;
uniform float uNoiseScale;
uniform float uNoiseHeight;
uniform sampler3D uPrecomputedNoise;


//steps
uniform int uMaxSteps;
uniform int uMaxVolumeSteps;
uniform int uMaxShadowMarchSteps;
uniform int uMaxLightMarchSteps;
uniform samplerCube uEnvironmentMap;

//scattering
uniform float uForwardScattering;
uniform float uBackwardScattering;

#define WATER_MATERIAL_ID 2
#define PI 3.14159
#define EPSILON 0.0001
#define USE_BLUE_NOISE 1
#define NUM_LIGHTS 0

const float EXTINCTION_MULT = 1.0;

#define MIN_OPACITY 0.05
#define NOISE_JITTER 0.02
#define SCENE_MAX_T 900.0
#define NUM_SCATTER_OCTAVES 4
#define SURFACE_DIST 0.03
#define INVALID_MATERIAL_ID int(-1)
#define NUM_MATERIALS 3



uniform vec3 uAlbedo[NUM_MATERIALS];
uniform vec3 uEmissive[NUM_MATERIALS];
uniform int uFlags[NUM_MATERIALS];


vec3 ambientColor = uAmbientLight * vec3(0.04, 0.05, 0.07);

vec3 GetMaterialAlbedo(int materialID) {
    return uAlbedo[materialID];
}

vec3 GetMaterialEmissive(int materialID) {
    return uEmissive[materialID];
}

int GetMaterialFlags(int materialID) {
    return uFlags[materialID];
}



float BeerLambert(float absorptionCoefficient, float distanceTraveled) {
    return exp(-absorptionCoefficient * distanceTraveled);
}



float HenyeyGreenstein(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
}

float DualLobeHG(float cosTheta, float gForward, float gBackward, float mixFactor) {
    float hgForward  = HenyeyGreenstein(cosTheta, gForward);
    float hgBackward = HenyeyGreenstein(cosTheta, gBackward);
    return mix(hgBackward, hgForward, mixFactor);
}




float MultipleOctaveScattering(float density, float mu){
    float attenuation      = 0.2;
    float contribution     = 0.4;
    float phaseAttenuation = 0.1;
    const float scatteringOctaves = 4.0;


    float a = 1.0;
    float b = 1.0;
    float c = 1.0;
    float g = 0.85;


    float uForwardScattering = 0.6;
    float uBackwardScattering = -0.3;
    float mixFactor = 0.8;

    float luminance = 0.0;

    for (float i = 0.0; i < scatteringOctaves; i++) {
        float phaseFunction = HenyeyGreenstein(0.3 * c, mu);


       float beers = exp(-density * EXTINCTION_MULT * a);

        luminance += b * phaseFunction * beers;


        a *= attenuation;
        b *= contribution;
        c *= (1.0 - phaseAttenuation);
    }

    return luminance;
}




float getLuminance(vec3 color) {
    return (color.r * 0.3) + (color.g * 0.59) + (color.b * 0.11);
}

bool isColorTooDark(vec3 color) {
    const float minValue = 0.009;
    return getLuminance(color) < minValue;
}


vec3 mask(vec3 f, float value)
{
    return vec3(
    (f.x < value) ? 1.0 : 0.0,
    (f.y < value) ? 1.0 : 0.0,
    (f.z < value) ? 1.0 : 0.0
    );
}


vec3 LinearToSRGB(vec3 rgb)
{
    rgb = clamp(rgb, 0.0, 1.0);
    return mix(
        pow(rgb, vec3(1.0 / 2.4)) * 1.055 - 0.055,
        rgb * 12.92,
        mask(rgb, 0.0031308)
    );
}




float hash1(float n) {
    return fract(n * 17.0 * fract(n * 0.3183099));
}




float noise(in vec3 x)
{
    vec3 p = floor(x);
    vec3 w = fract(x);

    vec3 u = w*w*w*(w*(w*6.0 - 15.0)+10.0);

    float n = p.x + 317.0*p.y + 157.0*p.z;

    float a = hash1(n+  0.0);
    float b = hash1(n+  1.0);
    float c = hash1(n+317.0);
    float d = hash1(n+318.0);
    float e = hash1(n+157.0);
    float f = hash1(n+158.0);
    float g = hash1(n+474.0);
    float h = hash1(n+475.0);

    float k0 = a;
    float k1 = b - a;
    float k2 = c - a;
    float k3 = e - a;
    float k4 = a - b - c + d;
    float k5 = a - c - e + g;
    float k6 = a - b - e + f;
    float k7 = -a + b + c - d + e - f - g + h;

    return -1.0 + 2.0 * (
    k0 + k1*u.x + k2*u.y + k3*u.z
    + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z
    );
}

const mat3 rotationM = mat3(
0.00,  0.80,  0.60,
-0.80,  0.36, -0.48,
-0.60, -0.48,  0.64
);



vec3 random3(vec3 p) {
    return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)),
                     dot(p, vec3(269.5, 183.3, 246.1)),
                     dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}


float perlinNoise(vec3 p) {
    vec3 pi = floor(p);
    vec3 pf = fract(p);


    vec3 u = pf * pf * (3.0 - 2.0 * pf);


    vec3 g000 = random3(pi + vec3(0.0, 0.0, 0.0));
    vec3 g100 = random3(pi + vec3(1.0, 0.0, 0.0));
    vec3 g010 = random3(pi + vec3(0.0, 1.0, 0.0));
    vec3 g110 = random3(pi + vec3(1.0, 1.0, 0.0));
    vec3 g001 = random3(pi + vec3(0.0, 0.0, 1.0));
    vec3 g101 = random3(pi + vec3(1.0, 0.0, 1.0));
    vec3 g011 = random3(pi + vec3(0.0, 1.0, 1.0));
    vec3 g111 = random3(pi + vec3(1.0, 1.0, 1.0));


    float n000 = dot(g000, pf - vec3(0.0, 0.0, 0.0));
    float n100 = dot(g100, pf - vec3(1.0, 0.0, 0.0));
    float n010 = dot(g010, pf - vec3(0.0, 1.0, 0.0));
    float n110 = dot(g110, pf - vec3(1.0, 1.0, 0.0));
    float n001 = dot(g001, pf - vec3(0.0, 0.0, 1.0));
    float n101 = dot(g101, pf - vec3(1.0, 0.0, 1.0));
    float n011 = dot(g011, pf - vec3(0.0, 1.0, 1.0));
    float n111 = dot(g111, pf - vec3(1.0, 1.0, 1.0));


    float nx00 = mix(n000, n100, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    float nxyz = mix(nxy0, nxy1, u.z);

    return nxyz;
}


float worleyNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    float nearest = 1.0;
    float secondNearest = 1.0;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 point = random3(i + neighbor);
                float d = length(neighbor + point - f);

                if (d < nearest) {
                    secondNearest = nearest;
                    nearest = d;
                } else if (d < secondNearest) {
                    secondNearest = d;
                }
            }
        }
    }

    return nearest;
}


float perlinWorleyNoise(vec3 p) {

    float perlin = perlinNoise(p);
    float worley = worleyNoise(p * 1.5);


    perlin = 0.5 * perlin + 0.5;


    return perlin * (1.0 - worley);
}


float getPlane(vec3 p) {
    float waveHeight = sin(p.x * 0.3 + uTime) * 0.1 +
    sin(p.z * 0.2 + uTime * 0.8) * 0.1;
    return p.y - waveHeight;
}


float getCube(vec3 p, vec3 center, vec3 halfExtents, float roundRadius){
    vec3 d = abs(p - center) - halfExtents;

    float outsideDistance = length(max(d, 0.0));

    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    return outsideDistance + insideDistance - roundRadius;
}


float getSphere(vec3 p, vec3 origin, float s) {
    return length(p - origin) - s;
}


float getTorus(vec3 p, vec3 center, float R, float r){
    p -= center;
    float lenXZ = length(p.xz) - R;
    return length(vec2(lenXZ, p.y)) - r;
}

float getRoundedBox(vec3 p, vec3 center, vec3 halfExtents, float roundRadius){
    p -= center;
    vec3 d = abs(p) - halfExtents;
    return length(max(d, 0.0)) - roundRadius;
}



vec2 sphericalUV(vec3 dir){

    dir = normalize(dir);


    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * PI);
    float v = 0.5 - asin(dir.y) / PI;


    return fract(vec2(u, v));
}





float hash13(vec3 p) {
    p = fract(p * 0.3183099);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    float n000 = hash13(i + vec3(0,0,0));
    float n100 = hash13(i + vec3(1,0,0));
    float n010 = hash13(i + vec3(0,1,0));
    float n110 = hash13(i + vec3(1,1,0));
    float n001 = hash13(i + vec3(0,0,1));
    float n101 = hash13(i + vec3(1,0,1));
    float n011 = hash13(i + vec3(0,1,1));
    float n111 = hash13(i + vec3(1,1,1));

    vec3 u = f*f*(3.0 - 2.0*f);

    float nx00 = mix(n000, n100, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    return mix(nxy0, nxy1, u.z);
}

float fbm3D(vec3 p) {
    float value = 0.0;
    float amp   = 0.5;
    for(int i=0; i<4; i++){
        value += amp * noise3D(p);
        p *= 2.01;
        amp *= 0.5;
    }
    return value;
}

float samplePrecomputedNoise(vec3 pos) {
    vec3 coord = fract(pos / uNoiseScale);
    return texture(uPrecomputedNoise, coord).r;
}



float getNoise(vec3 p) {
    if (uCurrentNoise == 0) {
        return perlinNoise(p);
    } else if (uCurrentNoise == 1) {
        return fbm3D(p);
    }else if (uCurrentNoise == 2){
        return worleyNoise(p);
    }else if(uCurrentNoise == 3){
        return perlinWorleyNoise(p);
    } else if(uCurrentNoise == 4){
        return samplePrecomputedNoise(p);
    } else {
        return fbm3D(p);
    }
}

float fbm(in vec3 x){
    float f = 2.0;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;
    for(int i = 0; i < 4; i++)
    {
        float n = getNoise(x);

        a += b * n;
        b *= s;
        // non-axis-aligned transformation of x => makes noise look more natural with less repetition
        x = f * rotationM * x;
    }
    return a;
}
float opSmoothUnion( float d1, float d2, float k ){
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}


float getDensity(vec3 p, float sdfValue){
    float sdfMultiplier = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;
    float density = abs(fbm(p / 6.0) + 0.5);
    return sdfMultiplier * density;
}


float getShape(vec3 p, int shapeID) {
    vec3 center1 = vec3(0.0, 20.0, -25.0);
    float radius = 8.0;
    vec3 cubeHalfExtents = vec3(10.0);
    float cubeRoundRadius = 1.0;

    if (shapeID == 0) {
        vec3 offset2 = vec3(8.0, 0.0, 0.0);
        vec3 offset3 = vec3(-8.0, 0.0, 0.0);
        float d1 = length(p - center1) - radius;
        float d2 = length(p - (center1 + offset2)) - radius;
        float d3 = length(p - (center1 + offset3)) - radius;
        float k = 2.0;
        return opSmoothUnion(opSmoothUnion(d1, d2, k), d3, k);
    } else if (shapeID == 1) {
        return getSphere(p, center1, radius);
    } else if (shapeID == 2) {
        return getTorus(p, center1, 12.0, 5.0);
    } else if (shapeID == 3) {
        return getCube(p, center1, cubeHalfExtents, cubeRoundRadius);
    }
    return 1000.0;
}


float getVolume(vec3 p){
    float scaleFactor = 1.2;
    p /= scaleFactor;

    float dPrev = getShape(p, uPrevShape);
    float dCurr = getShape(p, uObjectShape);


    float d = mix(dPrev, dCurr, smoothstep(0.0, 1.0, uShapeTransition));

    vec3 fbmCoord = (p + vec3(uTime * 0.5, 0.0, uTime * 0.5)) / uNoiseScale;
    d += uNoiseHeight * fbm(fbmCoord);

    return d * scaleFactor;
}



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


// raymarching

vec3 raymarch(in vec3 rayOrigin, in vec3 rayDir, out vec3 outVColor) {
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float finalDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;
    float visibility = 1.0;

    vec3 normal       = vec3(0.0);
    int  materialId   = INVALID_MATERIAL_ID;



    float t = 1e20;
    vec3 intersectionNormal = vec3(0.0);
    bool hitOpaque = false;
//check water
    if (rayDir.y != 0.0) {
        float tPlane = -rayOrigin.y / rayDir.y;
        if (tPlane > EPSILON && tPlane < t) {
            t = tPlane;
            intersectionNormal = vec3(0.0, 1.0, 0.0);
            materialId = WATER_MATERIAL_ID;
            hitOpaque = true;
        }
    }

    float opaqueDepth = t;
    if (hitOpaque) {
        normal = intersectionNormal;
        finalDepth = opaqueDepth;
    }

//raymarch find entrypoint
    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; i++) {
        vec3 p = rayOrigin + volumetricDepth * rayDir;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > finalDepth) break;
        volumetricDepth += distance;
    }

// raymarch inside volume =>
    if (volumetricDepth < finalDepth) {
        for (int i = 0; i < uMaxVolumeSteps; i++) {
            volumetricDepth += marchSize;
            if (volumetricDepth > finalDepth) break;

            vec3 p = rayOrigin + rayDir * volumetricDepth;
            float sdfValue = getVolume(p);
            //point is inside volume , calculate absorption and scattering
            if (sdfValue < 0.0) {
                float fog = getDensity(p, sdfValue);
                float prevVisibility = oVisibility;

                float T = BeerLambert(uVolumetricAbsorption * fog, marchSize);
                oVisibility *= T;

                if (oVisibility < MIN_OPACITY) break;

                //light absorbed in this step
                float marchAbsorption = prevVisibility - oVisibility;

                vec3 lightDir = normalize(uSunDirection);
                vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                //cosinus angle of view and light
                float mu = dot(-rayDir, lightDir);
                float powderStrength = 0.7 * clamp(1.0 - mu, 0.0, 1.0);
                float powder = 1.0 - exp(-uVolumetricAbsorption * fog * marchSize * powderStrength);

                // shadow ray marching
               // if (i % 10 == 0) {
                    visibility = 1.0;
                    float lightT = 0.0;
                    for (int j = 0; j < uMaxLightMarchSteps; j++) {
                        lightT += marchSize * 1.4;
                        vec3 currentLightPoint = p + lightDir * lightT;
                        //inside volume
                        if (getVolume(currentLightPoint) < 0.0) {
                            visibility *= BeerLambert(uVolumetricAbsorption, marchSize * 1.4);
                            if (visibility < 0.01) break;
                        }
                    }
               // }

                if (!isColorTooDark(lightCol)) {
                    lightCol *= visibility;
                }

                float blend = 0.6;
                vec3 scatterLight = mix(marchAbsorption * lightCol, powder * lightCol, blend);

                vColor += scatterLight * uVolumetricAlbedo;
                vColor += marchAbsorption * uVolumetricAlbedo * ambientColor;
            }
        }
    }


    // surface shading
    if (hitOpaque && materialId != INVALID_MATERIAL_ID) {
        vec3 position = rayOrigin + rayDir * opaqueDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        getLighting(position, normal, reflectionDir, rayDir, materialId, oColor);
    } else {
        oColor = vec3(0.7, 0.85, 1.0);
    }

    outVColor = vColor;
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}



vec3 raymarchForwardScattering(in vec3 rayOrigin, in vec3 rayDir, out vec3 outVColor) {
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float finalDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;
    float visibility = 1.0;

    vec3 normal       = vec3(0.0);
    int  materialId   = INVALID_MATERIAL_ID;



    float t = 1e20;
    vec3 intersectionNormal = vec3(0.0);
    bool hitOpaque = false;

    if (rayDir.y != 0.0) {
        float tPlane = -rayOrigin.y / rayDir.y;
        if (tPlane > EPSILON && tPlane < t) {
            t = tPlane;
            intersectionNormal = vec3(0.0, 1.0, 0.0);
            materialId = WATER_MATERIAL_ID;
            hitOpaque = true;
        }
    }

    float opaqueDepth = t;
    if (hitOpaque) {
        normal = intersectionNormal;
        finalDepth = opaqueDepth;
    }


    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; i++) {
        vec3 p = rayOrigin + volumetricDepth * rayDir;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > finalDepth) break;
        volumetricDepth += distance;
    }


    if (volumetricDepth < finalDepth) {
        for (int i = 0; i < uMaxVolumeSteps; i++) {
            volumetricDepth += marchSize;
            if (volumetricDepth > finalDepth) break;

            vec3 p = rayOrigin + rayDir * volumetricDepth;
            float sdfValue = getVolume(p);
            if (sdfValue < 0.0) {
                float fog = getDensity(p, sdfValue);
                float prevVisibility = oVisibility;

                float T = BeerLambert(uVolumetricAbsorption * fog, marchSize);
                oVisibility *= T;

                if (oVisibility < MIN_OPACITY) break;

                float marchAbsorption = prevVisibility - oVisibility;

                vec3 lightDir = normalize(uSunDirection);
                vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                float mu = dot(-rayDir, lightDir);

                float phase = HenyeyGreenstein(mu, uForwardScattering);
                float scatterLight = marchAbsorption * phase;

                // light visibility
               // if (i % 10 == 0) {
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
              //  }

                if (!isColorTooDark(lightCol)) {
                    lightCol *= visibility;
                }

                vColor += scatterLight * uVolumetricAlbedo * lightCol;
                vColor += marchAbsorption * uVolumetricAlbedo * ambientColor;
            }
        }
    }



    if (hitOpaque && materialId != INVALID_MATERIAL_ID) {
        vec3 position = rayOrigin + rayDir * opaqueDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        getLighting(position, normal, reflectionDir, rayDir, materialId, oColor);
    } else {
        oColor = vec3(0.7, 0.85, 1.0);
    }

    outVColor = vColor;
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}


vec3 raymarchBackwardScattering(in vec3 rayOrigin, in vec3 rayDir, out vec3 outVColor) {
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float finalDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;
    float visibility = 1.0;

    vec3 normal       = vec3(0.0);
    int  materialId   = INVALID_MATERIAL_ID;



    float t = 1e20;
    vec3 intersectionNormal = vec3(0.0);
    bool hitOpaque = false;

    if (rayDir.y != 0.0) {
        float tPlane = -rayOrigin.y / rayDir.y;
        if (tPlane > EPSILON && tPlane < t) {
            t = tPlane;
            intersectionNormal = vec3(0.0, 1.0, 0.0);
            materialId = WATER_MATERIAL_ID;
            hitOpaque = true;
        }
    }

    float opaqueDepth = t;
    if (hitOpaque) {
        normal = intersectionNormal;
        finalDepth = opaqueDepth;
    }


    float volumetricDepth = 0.0;
    for (int i = 0; i < uMaxSteps; i++) {
        vec3 p = rayOrigin + volumetricDepth * rayDir;
        float distance = getVolume(p);
        if (distance < SURFACE_DIST || volumetricDepth > finalDepth) break;
        volumetricDepth += distance;
    }


    if (volumetricDepth < finalDepth) {
        for (int i = 0; i < uMaxVolumeSteps; i++) {
            volumetricDepth += marchSize;
            if (volumetricDepth > finalDepth) break;

            vec3 p = rayOrigin + rayDir * volumetricDepth;
            float sdfValue = getVolume(p);
            if (sdfValue < 0.0) {
                float fog = getDensity(p, sdfValue);
                float prevVisibility = oVisibility;

                float T = BeerLambert(uVolumetricAbsorption * fog, marchSize);
                oVisibility *= T;

                if (oVisibility < MIN_OPACITY) break;

                float marchAbsorption = prevVisibility - oVisibility;

                vec3 lightDir = normalize(uSunDirection);
                vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                float mu = dot(-rayDir, lightDir);
                float phase = HenyeyGreenstein(mu, uBackwardScattering);
                float scatterLight = marchAbsorption * phase;

                // light visibility
              //  if (i % 10 == 0) {
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
              //  }

                if (!isColorTooDark(lightCol)) {
                    lightCol *= visibility;
                }

                vColor += scatterLight * uVolumetricAlbedo * lightCol;
                vColor += marchAbsorption * uVolumetricAlbedo * ambientColor;
            }
        }
    }



    if (hitOpaque && materialId != INVALID_MATERIAL_ID) {
        vec3 position = rayOrigin + rayDir * opaqueDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        getLighting(position, normal, reflectionDir, rayDir, materialId, oColor);
    } else {
        oColor = vec3(0.7, 0.85, 1.0);
    }

    outVColor = vColor;
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}





vec3 raymarchMOS(in vec3 rayOrigin, in vec3 rayDir, out vec3 outVColor){
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


vec3 raymarchDual(in vec3 rayOrigin, in vec3 rayDir, out vec3 outVColor){
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float finalDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;
    float visibility = 0.0;

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
                        float cosTheta = dot(viewDir, lightDir);


                        float uForwardScattering = 0.6;
                        float uBackwardScattering = -0.3;
                        float mixFactor = 0.8;
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


                        float phase = DualLobeHG(cosTheta, uForwardScattering, uBackwardScattering, mixFactor);
                        phase *= 1.2;

                        lightCol *= visibility * phase;
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
    else
    {

        oColor = vec3(0.7, 0.85, 1.0);
    }

    outVColor = vColor;
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}


in vec3 vRayOrigin;
in vec3 vRayDirection;

void main(){
    vec3 rayOrigin    = vRayOrigin;
    vec3 rayDirection = vRayDirection;
    vec3 vColor       = vec3(0.0);
    vec3 color;


    if (uCurrentMethod == 0) {
        color = raymarch(rayOrigin, rayDirection, vColor);
    }
    else if (uCurrentMethod == 1) {
        color = raymarchMOS(rayOrigin, rayDirection, vColor);

    }
    else if (uCurrentMethod == 2) {
        color = raymarchBackwardScattering(rayOrigin, rayDirection, vColor);
    }
    else if (uCurrentMethod == 3){
        color = raymarchForwardScattering(rayOrigin, rayDirection, vColor);
    }else{
        color = raymarchDual(rayOrigin, rayDirection, vColor);
    }

    #if USE_BLUE_NOISE

    if (getLuminance(vColor) > 0.01) {
        float noiseVal = texture(iChannel0, gl_FragCoord.xy / uResolution.xy).r;
        color += (noiseVal - 0.5) * NOISE_JITTER;
    }
    #endif

    color = LinearToSRGB(color);
    fragColor = vec4(color, 1.0);
}
