#version 330 core


out vec4 fragColor;


uniform vec3  iResolution;
uniform float iTime;
//uniform vec4  iMouse;
uniform sampler2D iChannel0;


uniform vec3 uSunDirection;
uniform float uSunIntensity;

uniform int uCurrentMethod;        // 0=Single,1=MOS,2=DOS,3=Dual
uniform float uVolumetricAbsorption; // from GUI
uniform int uObjectShape;
uniform int uPrevShape;
uniform float uShapeTransition; // 0.0 → old shape, 1.0 → new shape
uniform int currentNoise;




#define PI 3.14159
#define LARGE_NUMBER 1e20
#define EPSILON 0.0001
#define SCENE_MAX_T 900.0


#define CAST_SHADOW_ON_OPAQUE 1
#define USE_BLUE_NOISE 1






#define NUM_LIGHTS 0




#define LIGHT_ATTENUATION 1.3




const float EXTINCTION_MULT = 1.0;



const vec3 AMBIENT_LIGHT = vec3(0.04, 0.05, 0.07);



const vec3 VOLUMETRIC_ALBEDO = vec3(1.0, 0.98, 0.95);



//const float VOLUMETRIC_ABSORPTION = 0.1;


#define MIN_OPACITY 0.05
#define NOISE_JITTER 0.02
#define NOISE_THRESHOLD 0.03


#define BLEND_STRENGTH 1.75
#define GROUND_STICK 13.
#define NUM_OCTAVES 16
#define NOISE 10
#define NOISE_HEIGHT 16.0


#define MAX_STEPS 40
#define MAX_VOLUME_STEPS 40
#define MAX_SHADOWMARCH_STEPS 25
#define MAX_LIGHTMARCH_STEPS 25
#define SURFACE_DIST 0.03


#define INVALID_MATERIAL_ID int(-1)
#define LAMP_MATERIAL_ID 0
#define DEBUG_MATERIAL_ID 1
#define NUM_MATERIALS (LAMP_MATERIAL_ID + NUM_LIGHTS + 1)
#define MATERIAL_IS_LIGHT_SOURCE 0x1
#define ENABLE_SPACE_WARPING 1
uniform vec3 uAlbedo[NUM_MATERIALS];
uniform vec3 uEmissive[NUM_MATERIALS];
uniform int uFlags[NUM_MATERIALS];




bool IsLightSource(int materialID) {
    return (uFlags[materialID] & MATERIAL_IS_LIGHT_SOURCE) != 0;
}




vec3 GetMaterialAlbedo(int materialID) {
    return uAlbedo[materialID];
}

vec3 GetMaterialEmissive(int materialID) {
    return uEmissive[materialID];
}

int GetMaterialFlags(int materialID) {
    return uFlags[materialID];
}





float GetLightAttenuation(float distanceToLight)
{

    return 1.0 / pow(distanceToLight, LIGHT_ATTENUATION);
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




float MultipleOctaveScattering(float density, float mu)
{
    float attenuation      = 0.2;
    float contribution     = 0.4;
    float phaseAttenuation = 0.1;
    const float scatteringOctaves = 4.0;


    float a = 1.0;
    float b = 1.0;
    float c = 1.0;
    float g = 0.85;


    float gF = 0.6;
    float gB = -0.3;
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





float DualScattering(float density, float mu)
{
    float attenuation      = 0.2;
    float contribution     = 0.4;
    float phaseAttenuation = 0.1;
    const float scatteringOctaves = 4.0;


    float a = 1.0;
    float b = 1.0;
    float c = 1.0;
    float g = 0.85;


    float gF = 0.6;
    float gB = -0.3;
    float mixFactor = 0.8;

    float luminance = 0.0;

    for (float i = 0.0; i < scatteringOctaves; i++) {

        float phaseFunction = DualLobeHG(mu, gF, gB, mixFactor);

        float beers = exp(-density * EXTINCTION_MULT * a);

        luminance += b * phaseFunction * beers;


        a *= attenuation;
        b *= contribution;
        c *= (1.0 - phaseAttenuation);
    }

    return luminance;
}





float Luminance(vec3 color) {
    return (color.r * 0.3) + (color.g * 0.59) + (color.b * 0.11);
}

bool IsColorInsignificant(vec3 color) {
    const float minValue = 0.009;
    return Luminance(color) < minValue;
}


vec3 LessThan(vec3 f, float value)
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
        LessThan(rgb, 0.0031308)
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

const mat3 m3 = mat3(
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


vec2 worleyNoise(vec3 p) {
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

    return vec2(nearest, secondNearest);
}




float fbm(in vec3 x)
{
    float f = 2.0;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;
    for(int i = 0; i < 4; i++)
    {
        float n = perlinNoise(x);
        a += b * n;
        b *= s;
        x = f * m3 * x;
    }
    return a;
}




float worleyFBM(vec3 p) {
    float scale = 1.0;
    float weight = 0.5;
    float sum = 0.0;
    float amplitude = 1.0;

    for (int i = 0; i < 5; i++) {
                                  vec2 worley = worleyNoise(p * scale);
                                  sum += (1.0 - worley.x) * amplitude;
                                  scale *= 2.0;
                                  amplitude *= weight;
    }

    return sum;
}







float FogDensity(vec3 p, float sdfValue)
{
    float sdfMultiplier = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;
    float density = abs(fbm(p / 6.0) + 0.5);
    return sdfMultiplier * density;
}









float sdPlane(vec3 p) {

    return p.y;
}


float SdCube(vec3 p, vec3 center, vec3 halfExtents, float roundRadius)
{
    vec3 d = abs(p - center) - halfExtents;

    float outsideDistance = length(max(d, 0.0));

    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    return outsideDistance + insideDistance - roundRadius;
}


float sdSphere(vec3 p, vec3 origin, float s) {
    return length(p - origin) - s;
}




float SdTorus(vec3 p, vec3 center, float R, float r)
{
    p -= center;
    float lenXZ = length(p.xz) - R;
    return length(vec2(lenXZ, p.y)) - r;
}

float SdRoundedBox(vec3 p, vec3 center, vec3 halfExtents, float roundRadius)
{
    p -= center;
    vec3 d = abs(p) - halfExtents;
    return length(max(d, 0.0)) - roundRadius;
}








float SphereIntersection(
in vec3 rayOrigin,
in vec3 rayDirection,
in vec3 sphereCenter,
in float sphereRadius,
out vec3 normal
) {
    vec3 eMinusC = rayOrigin - sphereCenter;
    float dDotD  = dot(rayDirection, rayDirection);

    float disc = dot(rayDirection, eMinusC) * dot(rayDirection, eMinusC)
    - dDotD * (dot(eMinusC, eMinusC) - sphereRadius*sphereRadius);


    if (disc < 0.0) return -1.0;

    float firstIsect = (dot(-rayDirection, eMinusC) - sqrt(disc)) / dDotD;
    float t = firstIsect;


    if (firstIsect < EPSILON) {
        t = (dot(-rayDirection, eMinusC) + sqrt(disc)) / dDotD;
    }

    normal = normalize(rayOrigin + rayDirection * t - sphereCenter);
    return t;
}




void UpdateIfIntersected(
inout float tCurrent,
in float tCandidate,
in vec3 candidateNormal,
in int candidateMaterialID,
out vec3 bestNormal,
out int bestMaterialID
) {
    if (tCandidate > EPSILON && tCandidate < tCurrent) {
        bestNormal     = candidateNormal;
        bestMaterialID = candidateMaterialID;
        tCurrent       = tCandidate;
    }
}




float IntersectOpaqueScene(
in vec3 rayOrigin,
in vec3 rayDirection,
out int materialID,
out vec3 normal
) {
    float t = LARGE_NUMBER;
    vec3 intersectionNormal = vec3(0);
    materialID = INVALID_MATERIAL_ID;

    return t;
}

vec2 SphericalUV(vec3 dir)
{

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
    for(int i=0; i<5; i++){
        value += amp * noise3D(p);
        p *= 2.01;
        amp *= 0.5;
    }
    return value;
}




float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}


float GetShapeSDF(vec3 p, int shapeID) {
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
        return sdSphere(p, center1, radius);
    } else if (shapeID == 2) {
        return SdTorus(p, center1, 12.0, 5.0);
    } else if (shapeID == 3) {
        return SdCube(p, center1, cubeHalfExtents, cubeRoundRadius);
    }
    return 1000.0; // fallback
}


float SdVolume(vec3 p)
{
    float scaleFactor = 1.2;
    p /= scaleFactor;

    float dPrev = GetShapeSDF(p, uPrevShape);
    float dCurr = GetShapeSDF(p, uObjectShape);

    // Blend shapes (smooth or linear)
    float d = mix(dPrev, dCurr, smoothstep(0.0, 1.0, uShapeTransition));

    vec3 fbmCoord = (p + vec3(iTime * 0.5, 0.0, iTime * 0.5)) / NOISE;
    d += NOISE_HEIGHT * fbm(fbmCoord);

    return d * scaleFactor;
}




float IntersectVolumetric(
in vec3 rayOrigin,
in vec3 rayDirection,
in float maxDist,
out int materialID,
out vec3 normal
) {
    materialID = INVALID_MATERIAL_ID;
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = rayOrigin + dO * rayDirection;
        float ds = SdVolume(p);
        dO += ds;
        if (ds < SURFACE_DIST || dO > maxDist) {
            break;
        }
    }
    return dO;
}




float VolumeLightVisibility(
in vec3 rO,
in vec3 rDir,
in float maxT,
in int numSteps,
in float marchSize
) {
    float t = 0.0;
    float lightVis = 1.0;
    for (int i = 0; i < numSteps; i++) {
        t += marchSize;
        if (t > maxT) break;
        vec3 p = rO + t * rDir;
        if (SdVolume(p) < 0.0) {
            lightVis *= BeerLambert(uVolumetricAbsorption, marchSize);
        }
    }
    return lightVis;
}





vec3 Diffuse(in vec3 normal, in vec3 lightVec, in vec3 diffuseColor)
{
    float nDotL = dot(normal, lightVec);
    return clamp(nDotL, 0.0, 1.0) * diffuseColor;
}




void CalculateLighting(
    vec3 position,
    vec3 normal,
    vec3 reflectionDir,
    int materialID,
inout vec3 color
)
{

    vec3 lightDir   = normalize(uSunDirection);

    vec3 lightColor = vec3(1.0, 0.95, 0.8) * uSunIntensity;


    vec3 diffuse = Diffuse(normal, lightDir, GetMaterialAlbedo(materialID));
    color += lightColor * diffuse;


    float specular = pow(max(dot(reflectionDir, lightDir), 0.0), 8.0);
    color += lightColor * specular * GetMaterialAlbedo(materialID);


    color += GetMaterialEmissive(materialID);


    color += AMBIENT_LIGHT * GetMaterialAlbedo(materialID);
}








vec3 Render(in vec3 rayOrigin, in vec3 rayDir, out vec3 outVColor)
{
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float fDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;
    float visibility = 0.0;

    vec3 normal       = vec3(0.0);
    vec3 vnormal      = vec3(0.0);
    int  vmaterialId  = INVALID_MATERIAL_ID;
    int  materialId   = INVALID_MATERIAL_ID;


    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }


    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);


    if (vDepth > 0.0)
    {
        for (int i = 0; i < MAX_VOLUME_STEPS; i++) {
            vDepth += marchSize;
            if (vDepth > oDepth) break;

            vec3 p = rayOrigin + rayDir * vDepth;
            float sdfValue = SdVolume(p);
            bool inVolume  = (sdfValue < 0.0);
            if (inVolume) {
                float prevVisibility = oVisibility;
                float fog = FogDensity(p, sdfValue);


                float T = BeerLambert(uVolumetricAbsorption * fog, marchSize);
                oVisibility *= T;
                float marchAbsorption = prevVisibility - oVisibility;



                if (oVisibility < MIN_OPACITY) {
                    break;
                }



                vec3 lightDir = normalize(uSunDirection);
                vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;


                float powderStrength = 0.7;
                float mu = dot(-rayDir, lightDir);
                powderStrength *= clamp(1.0 - mu, 0.0, 1.0);

                float powder = 1.0 - exp(-uVolumetricAbsorption *fog * marchSize * powderStrength);

                if (i % 10 == 0) {
                    visibility = VolumeLightVisibility(
                    p, lightDir, 1000.0,
                    MAX_LIGHTMARCH_STEPS, marchSize * 1.4
                    );
                }
                if (!IsColorInsignificant(lightCol)) {
                    lightCol *= visibility;
                }








                float blend = 0.6;
                vec3 scatterLight = mix(marchAbsorption * lightCol, powder * lightCol, blend);

                vColor += scatterLight * VOLUMETRIC_ALBEDO;
                vColor += marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
            }
        }
    }


    if (materialId != INVALID_MATERIAL_ID)
    {

        vec3 position = rayOrigin + rayDir * oDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        CalculateLighting(position, normal, reflectionDir, materialId, oColor);
    }
    else
    {


        oColor = vec3(0.2, 0.5, 1.0);
    }

    outVColor = vColor;
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}





vec3 RenderMOS(in vec3 rayOrigin, in vec3 rayDir)
{
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float fDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;

    vec3 normal       = vec3(0.0);
    vec3 vnormal      = vec3(0.0);
    int  vmaterialId  = INVALID_MATERIAL_ID;
    int  materialId   = INVALID_MATERIAL_ID;


    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }


    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);


    if (vDepth > 0.0)
    {
        const int NUM_SCATTER_OCTAVES = 4;
        float scatterScale = 1.0;
        float scatterStrength = 1.0;
        float amplitude = 1.0;
        float visibility = 0.0;

        for (int octave = 0; octave < NUM_SCATTER_OCTAVES; octave++) {
            float localVDepth = vDepth;
            float localStep = marchSize / scatterScale;

            for (int i = 0; i < MAX_VOLUME_STEPS; i++) {
                localVDepth += localStep;
                if (localVDepth > oDepth) break;

                vec3 p = rayOrigin + rayDir * localVDepth;
                float sdfValue = SdVolume(p);
                if (sdfValue < 0.0) {
                    float prevVisibility = oVisibility;
                    float fog = FogDensity(p, sdfValue);

                    oVisibility *= BeerLambert(uVolumetricAbsorption * fog, localStep);

                    if (oVisibility < MIN_OPACITY) break;

                    float marchAbsorption = prevVisibility - oVisibility;

                    vec3 viewDir = -rayDir;
                    vec3 lightDir = normalize(uSunDirection);
                    vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                    if (!IsColorInsignificant(lightCol)) {
                        float mu = dot(viewDir, lightDir);

                        if (i % 6 == 0) {
                            visibility = VolumeLightVisibility(
                                p, lightDir, 1000.0, MAX_LIGHTMARCH_STEPS, localStep * 1.4
                            );
                        }

                        float scatter = MultipleOctaveScattering(fog, mu);
                        lightCol *= visibility * scatter;
                    }

                    vec3 scatterContribution = marchAbsorption * VOLUMETRIC_ALBEDO * lightCol;
                    vColor += amplitude * scatterContribution;


                    vColor += amplitude * marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
                }
            }


            amplitude *= 0.5;
            scatterScale *= 2.0;
        }

    }


    if (materialId != INVALID_MATERIAL_ID)
    {

        vec3 position = rayOrigin + rayDir * oDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        CalculateLighting(position, normal, reflectionDir, materialId, oColor);
    }
    else
    {

        oColor = vec3(0.7, 0.85, 1.0);
    }


    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}


vec3 RenderDOS(in vec3 rayOrigin, in vec3 rayDir)
{
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float fDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;

    vec3 normal       = vec3(0.0);
    vec3 vnormal      = vec3(0.0);
    int  vmaterialId  = INVALID_MATERIAL_ID;
    int  materialId   = INVALID_MATERIAL_ID;


    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }


    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);


    if (vDepth > 0.0)
    {
        const int NUM_SCATTER_OCTAVES = 4;
        float scatterScale = 1.0;
        float scatterStrength = 1.0;
        float amplitude = 1.0;
        float visibility = 0.0;

        for (int octave = 0; octave < NUM_SCATTER_OCTAVES; octave++) {
            float localVDepth = vDepth;
            float localStep = marchSize / scatterScale;

            for (int i = 0; i < MAX_VOLUME_STEPS; i++) {
                localVDepth += localStep;
                if (localVDepth > oDepth) break;

                vec3 p = rayOrigin + rayDir * localVDepth;
                float sdfValue = SdVolume(p);
                if (sdfValue < 0.0) {
                    float prevVisibility = oVisibility;
                    float fog = FogDensity(p, sdfValue);

                    oVisibility *= BeerLambert(uVolumetricAbsorption * fog, localStep);

                    if (oVisibility < MIN_OPACITY) break;

                    float marchAbsorption = prevVisibility - oVisibility;

                    vec3 viewDir = -rayDir;
                    vec3 lightDir = normalize(uSunDirection);
                    vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                    if (!IsColorInsignificant(lightCol)) {
                        float mu = dot(viewDir, lightDir);

                        if (i % 6 == 0) {
                            visibility = VolumeLightVisibility(
                                p, lightDir, 1000.0, MAX_LIGHTMARCH_STEPS, localStep * 1.4
                            );
                        }

                        float scatter = DualScattering(fog, mu);
                        lightCol *= visibility * scatter;
                    }

                    vec3 scatterContribution = marchAbsorption * VOLUMETRIC_ALBEDO * lightCol;
                    vColor += amplitude * scatterContribution;


                    vColor += amplitude * marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
                }
            }


            amplitude *= 0.5;
            scatterScale *= 2.0;
        }

    }


    if (materialId != INVALID_MATERIAL_ID)
    {

        vec3 position = rayOrigin + rayDir * oDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        CalculateLighting(position, normal, reflectionDir, materialId, oColor);
    }
    else
    {

        oColor = vec3(0.7, 0.85, 1.0);
    }


    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}

vec3 RenderDual(in vec3 rayOrigin, in vec3 rayDir)
{
    vec3 vColor       = vec3(0.0);
    vec3 oColor       = vec3(0.0);
    float fDepth      = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.6;
    float visibility = 0.0;

    vec3 normal       = vec3(0.0);
    vec3 vnormal      = vec3(0.0);
    int  vmaterialId  = INVALID_MATERIAL_ID;
    int  materialId   = INVALID_MATERIAL_ID;


    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }


    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);


    if (vDepth > 0.0)
    {
        const int NUM_SCATTER_OCTAVES = 4;
        float scatterScale = 1.0;
        float scatterStrength = 1.0;
        float amplitude = 1.0;

        for (int octave = 0; octave < NUM_SCATTER_OCTAVES; octave++) {
            float localVDepth = vDepth;
            float localStep = marchSize / scatterScale;

            for (int i = 0; i < MAX_VOLUME_STEPS; i++) {
                localVDepth += localStep;
                if (localVDepth > oDepth) break;

                vec3 p = rayOrigin + rayDir * localVDepth;
                float sdfValue = SdVolume(p);
                if (sdfValue < 0.0) {
                    float prevVisibility = oVisibility;
                    float fog = FogDensity(p, sdfValue);
                    oVisibility *= BeerLambert(uVolumetricAbsorption * fog, localStep);

                    if (oVisibility < MIN_OPACITY) break;

                    float marchAbsorption = prevVisibility - oVisibility;

                    vec3 viewDir = -rayDir;
                    vec3 lightDir = normalize(uSunDirection);
                    vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;


                    if (!IsColorInsignificant(lightCol)) {
                        float cosTheta = dot(viewDir, lightDir);


                        float gF = 0.6;
                        float gB = -0.3;
                        float mixFactor = 0.8;
                        if (i % 6 == 0) {
                            visibility = VolumeLightVisibility(
                                p, lightDir, 1000.0, MAX_LIGHTMARCH_STEPS, localStep * 1.4
                            );
                        }


                        float phase = DualLobeHG(cosTheta, gF, gB, mixFactor);
                        phase *= 1.2;

                        lightCol *= visibility * phase;
                    }


                    vec3 scatterContribution = marchAbsorption * VOLUMETRIC_ALBEDO * lightCol;
                    vColor += amplitude * scatterContribution;


                    vColor += amplitude * marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
                }
            }


            amplitude *= 0.5;
            scatterScale *= 2.0;
        }

    }


    if (materialId != INVALID_MATERIAL_ID)
    {

        vec3 position = rayOrigin + rayDir * oDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        CalculateLighting(position, normal, reflectionDir, materialId, oColor);
    }
    else
    {

        oColor = vec3(0.7, 0.85, 1.0);
    }


    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}






in vec3 vRayOrigin;
in vec3 vRayDirection;

void main()
{
    vec3 rayOrigin    = vRayOrigin;
    vec3 rayDirection = vRayDirection;
    vec3 vColor       = vec3(0.0);
    vec3 color;

    // pick method
    if (uCurrentMethod == 0) {
        color = Render(rayOrigin, rayDirection, vColor);
    }
    else if (uCurrentMethod == 1) {
        color = RenderMOS(rayOrigin, rayDirection);
    }
    else if (uCurrentMethod == 2) {
        color = RenderDOS(rayOrigin, rayDirection);
    }
    else {
        color = RenderDual(rayOrigin, rayDirection);
    }

    #if USE_BLUE_NOISE

    if (Luminance(vColor) > 0.01) {
        float noiseVal = texture(iChannel0, gl_FragCoord.xy / iResolution.xy).r;
        color += (noiseVal - 0.5) * NOISE_JITTER;
    }
    #endif

    color = LinearToSRGB(color);
    fragColor = vec4(color, 1.0);
}
