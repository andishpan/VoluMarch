#version 330 core

// Fragment shader outputs
out vec4 fragColor;


uniform float iTime;         // Elapsed time in seconds
uniform sampler2D iChannel0; // For noise texture, etc.
uniform sampler3D uNoiseTexture; // 3D noise texture



// Single light uniform
uniform vec3 uLightPosition;  // Light position in world space
uniform vec3 uLightColor;     // Light color/intensity
uniform float uLightRadius;   // Light's spherical influence radius


//--------------------------------
//           #define(s)
//--------------------------------
#define PI 3.14159
#define LARGE_NUMBER 1e20
#define EPSILON 0.0001
#define SCENE_MAX_T 900.0

// Features
#define CAST_SHADOW_ON_OPAQUE 1
#define USE_BLUE_NOISE 0
#define USE_3D_NOISE_TEXTURE 1  // New define to toggle between procedural and texture noise

//--------------------------------
//  Here is where we define we have
//  only 1 lamp, so it's a single
//  small lamp in the scene
//--------------------------------
#define NUM_LIGHTS 1

//--------------------------------
//light const
//--------------------------------
#define LIGHT_ATTENUATION 1.3

// Debug mode uniform
uniform int uObjectShape; // sphere, rbox, torus

const float EXTINCTION_MULT = 1.0;

// Reduced ambient so the scene is mostly dark, lit by the lamp
const vec3 AMBIENT_LIGHT = vec3(0.01, 0.005, 0.005);

// Volume
const vec3 VOLUMETRIC_ALBEDO = vec3(0.95, 0.95, 0.95);
const float VOLUMETRIC_ABSORPTION = 0.08;  // Reduced absorption for softer clouds

// Minimum opacity for volume steps
#define MIN_OPACITY 0.02  // Reduced for softer edges
#define NOISE_JITTER 0.02
#define NOISE_THRESHOLD 0.03

// Volume shape
#define BLEND_STRENGTH 1.75
#define GROUND_STICK 13.
#define NUM_OCTAVES 4
#define NOISE 6.0  // Increased scale
#define NOISE_HEIGHT 1.5  // Reduced height impact

// Raymarch
#define MAX_STEPS 80
#define MAX_VOLUME_STEPS 80
#define MAX_SHADOWMARCH_STEPS 50
#define MAX_LIGHTMARCH_STEPS 50
#define SURFACE_DIST 0.01

// Materials
#define INVALID_MATERIAL_ID int(-1)
#define LAMP_MATERIAL_ID 0
#define DEBUG_MATERIAL_ID 1
#define NUM_MATERIALS (LAMP_MATERIAL_ID + NUM_LIGHTS + 1)
#define MATERIAL_IS_LIGHT_SOURCE 0x1

uniform vec3 uAlbedo[NUM_MATERIALS];
uniform vec3 uEmissive[NUM_MATERIALS];
uniform int uFlags[NUM_MATERIALS];

// Check if material is a light source
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


//--------------------------------------------
//              Noise Functions
//--------------------------------------------
float hash1(float n) {
    return fract(n * 17.0 * fract(n * 0.3183099));
}

// 3D noise from : https://iquilezles.org/articles/morenoise/
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


// Hash function to generate pseudo-random gradient vectors
vec3 random3(vec3 p) {
    return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)),
                     dot(p, vec3(269.5, 183.3, 246.1)),
                     dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}

// Classic Perlin noise function in 3D
float perlinNoise(vec3 p) {
    vec3 pi = floor(p); // Grid cell coordinates
    vec3 pf = fract(p); // Local position within cell

    // Smoothstep function to interpolate smoothly
    vec3 u = pf * pf * (3.0 - 2.0 * pf);

    // Random gradient vectors at grid points
    vec3 g000 = random3(pi + vec3(0.0, 0.0, 0.0));
    vec3 g100 = random3(pi + vec3(1.0, 0.0, 0.0));
    vec3 g010 = random3(pi + vec3(0.0, 1.0, 0.0));
    vec3 g110 = random3(pi + vec3(1.0, 1.0, 0.0));
    vec3 g001 = random3(pi + vec3(0.0, 0.0, 1.0));
    vec3 g101 = random3(pi + vec3(1.0, 0.0, 1.0));
    vec3 g011 = random3(pi + vec3(0.0, 1.0, 1.0));
    vec3 g111 = random3(pi + vec3(1.0, 1.0, 1.0));

    // Compute dot products of gradient vectors with offset vectors
    float n000 = dot(g000, pf - vec3(0.0, 0.0, 0.0));
    float n100 = dot(g100, pf - vec3(1.0, 0.0, 0.0));
    float n010 = dot(g010, pf - vec3(0.0, 1.0, 0.0));
    float n110 = dot(g110, pf - vec3(1.0, 1.0, 0.0));
    float n001 = dot(g001, pf - vec3(0.0, 0.0, 1.0));
    float n101 = dot(g101, pf - vec3(1.0, 0.0, 1.0));
    float n011 = dot(g011, pf - vec3(0.0, 1.0, 1.0));
    float n111 = dot(g111, pf - vec3(1.0, 1.0, 1.0));

    // Trilinear interpolation using smoothstep values
    float nx00 = mix(n000, n100, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    float nxyz = mix(nxy0, nxy1, u.z);

    return nxyz;
}

// Worley noise function (returns the nearest and second nearest distance)
vec2 worleyNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    float nearest = 1.0;
    float secondNearest = 1.0;

    // Loop through neighboring cells
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 point = random3(i + neighbor); // Random point in cell
                float d = length(neighbor + point - f); // Distance to random point

                if (d < nearest) {
                    secondNearest = nearest;
                    nearest = d;
                } else if (d < secondNearest) {
                    secondNearest = d;
                }
            }
        }
    }

    return vec2(nearest, secondNearest); // Return both distances
}




float fbm(in vec3 x)
{
    float f = 2.0;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;
    for(int i = 0; i < 4; i++)
    {
        float n = noise(x);
        a += b * n;
        b *= s;
        x = f * m3 * x;
    }
    return a;
}


/*float fbm(vec3 x)
{
    float f = 2.0;
    float s = 0.5;
    float a = 0.0;
    float b = 0.5;

    for(int i = 0; i < 4; i++)
    {
        float n = noise(x); // Use your hash-based noise
        vec2 worley = worleyNoise(x); // Get Worley noise
        float worleyMix = mix(n, 1.0 - worley.x, 0.5); // Blend Perlin-style noise with Worley
        a += b * worleyMix;
        b *= s;
        x = f * m3 * x;
    }
    return a;
} */

// Multi-Octave Worley Noise (Worley FBM)
float worleyFBM(vec3 p) {
    float scale = 1.0;
    float weight = 0.5;
    float sum = 0.0;
    float amplitude = 1.0;

    for (int i = 0; i < 5; i++) { // Increase octaves for more detail
                                  vec2 worley = worleyNoise(p * scale);
                                  sum += (1.0 - worley.x) * amplitude; // Invert Worley noise for cloud effect
                                  scale *= 2.0;
                                  amplitude *= weight;
    }

    return sum;
}




//--------------------------------
//   Fog Density in the volume
//--------------------------------
float FogDensity(vec3 p, float sdfValue)
{
    float sdfMultiplier = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;

    #if USE_3D_NOISE_TEXTURE
        // Sample the texture at two different scales and offsets
        vec3 baseCoord = p * 0.02;
        vec3 animOffset = vec3(iTime * 0.05, iTime * 0.03, iTime * 0.04);

        // First sample - larger scale
        vec3 coord1 = fract(baseCoord + animOffset);
        float noise1 = texture(uNoiseTexture, coord1).r;

        // Second sample - smaller scale for detail
        vec3 coord2 = fract(baseCoord * 2.0 + animOffset * 1.5);
        float noise2 = texture(uNoiseTexture, coord2).r;

        // Blend the two noise samples
        float density = noise1 * 0.7 + noise2 * 0.3;

        // Add a small bias to ensure there's always some base density
        density = density * 0.8 + 0.5;
    #else
        float density = abs(fbm(p / 6.0) + 0.5);
    #endif

    return sdfMultiplier * density;
}





//--------------------------------
//  SDF shapes
//--------------------------------

float SdPlane(vec3 p) {
    // Plane at y=0
    return p.y;
}


float SdCube(vec3 p, vec3 center, vec3 halfExtents, float roundRadius)
{
    vec3 d = abs(p - center) - halfExtents;
    // Maximum component-wise subtraction for distance outside the cube
    float outsideDistance = length(max(d, 0.0));
    // Minimum component-wise maximum for distance inside the cube
    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    return outsideDistance + insideDistance - roundRadius;
}


float SdSphere(vec3 p, vec3 origin, float s) {
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





//--------------------------------
//   Sphere Intersection
//--------------------------------
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

    // no intersection
    if (disc < 0.0) return -1.0;

    float firstIsect = (dot(-rayDirection, eMinusC) - sqrt(disc)) / dDotD;
    float t = firstIsect;

    // if we are inside the sphere, pick the second intersection
    if (firstIsect < EPSILON) {
        t = (dot(-rayDirection, eMinusC) + sqrt(disc)) / dDotD;
    }

    normal = normalize(rayOrigin + rayDirection * t - sphereCenter);
    return t;
}

//--------------------------------
//   Update Intersection Info
//--------------------------------
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

//------------------------------------------------------------------
// Volumetric and opaque raymarching functions
//------------------------------------------------------------------

float IntersectOpaqueScene(
in vec3 rayOrigin,
in vec3 rayDirection,
out int materialID,
out vec3 normal
) {
    float t = LARGE_NUMBER;
    vec3 intersectionNormal = vec3(0);
    materialID = INVALID_MATERIAL_ID;
    {
        float candidate = SphereIntersection(
            rayOrigin,
            rayDirection,
            uLightPosition,
            uLightRadius,
            intersectionNormal
        );
        UpdateIfIntersected(
            t,
            candidate,
            intersectionNormal,
            LAMP_MATERIAL_ID,
            normal,
            materialID
        );
    }
    return t;
}

vec2 SphericalUV(vec3 dir)
{
    dir = normalize(dir);
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * PI);
    float v = 0.5 - asin(dir.y) / PI;
    return fract(vec2(u, v));
}

vec3 GetSkyColor(vec3 dir)
{
    vec2 uv = SphericalUV(dir);
    return texture(iChannel0, uv).rgb;
}

float SdVolume(vec3 p)
{
    vec3 sphereCenter = vec3(-10.0, 10.0, 0.0);
    float sphereRadius = 10.0;
    vec3 torusCenter = vec3(30.0, 10.0, 0.0);
    float torusR = 12.0;
    float torusr = 5.0;
    vec3 boxCenter = vec3(-5.0, 10.0, 30.0);
    vec3 boxHalfExtents = vec3(4.0, 4.0, 4.0);
    float boxRoundRadius = 1.0;
    vec3 cubeCenter = vec3(-50.0, 5.0, 0.0);
    vec3 cubeHalfExtents = vec3(10.0, 10.0, 10.0);
    float cubeRoundRadius = 1.0;

    float dSphere = (uObjectShape == 1)
    ? SdTorus(p, sphereCenter, sphereRadius, 3.0)
    : SdSphere(p, sphereCenter, sphereRadius);
    float dBox = (uObjectShape == 2)
    ? SdSphere(p, boxCenter, 3.0)
    : SdRoundedBox(p, boxCenter, boxHalfExtents, boxRoundRadius);
    float dTorus = (uObjectShape == 3)
    ? SdRoundedBox(p, torusCenter, vec3(torusR, torusr, torusr), 1.0)
    : SdTorus(p, torusCenter, torusR, torusr);
    float dCube = SdCube(p, cubeCenter, cubeHalfExtents, cubeRoundRadius);

    float d = min(dCube, min(dSphere, min(dTorus, dBox)));

    #if USE_3D_NOISE_TEXTURE
        // Sample at two different scales for the shape deformation
        vec3 baseCoord = p * 0.02;
        vec3 animOffset = vec3(
            sin(iTime * 0.15) * 0.3,
            cos(iTime * 0.1) * 0.2,
            sin(iTime * 0.2) * 0.25
        );

        // First sample - larger scale
        vec3 coord1 = fract(baseCoord + animOffset);
        float noise1 = texture(uNoiseTexture, coord1).r;

        // Second sample - smaller scale for detail
        vec3 coord2 = fract(baseCoord * 2.0 + animOffset * 1.5);
        float noise2 = texture(uNoiseTexture, coord2).r;

        // Blend the two noise samples
        float noiseValue = noise1 * 0.7 + noise2 * 0.3;

        // Center the noise around 0 but with a smaller range to reduce holes
        d += NOISE_HEIGHT * ((noiseValue - 0.5) * 0.7);
    #else
        vec3 fbmCoord = (p + vec3(iTime * 2.0, 0.0, iTime * 2.0)) / NOISE;
        d += 1.0;
    #endif

    return d;
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
            lightVis *= BeerLambert(VOLUMETRIC_ABSORPTION, marchSize);
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
) {
    vec3 lightPos = uLightPosition;
    float lightDist = length(lightPos - position);
    vec3 lightDir = normalize(lightPos - position);
    vec3 lightColor = uLightColor * GetLightAttenuation(lightDist);

    #if CAST_SHADOW_ON_OPAQUE
    if (!IsColorInsignificant(lightColor)) {
        lightColor *= VolumeLightVisibility(
            position, lightDir, lightDist,
            MAX_SHADOWMARCH_STEPS,
            0.6
        );
    }
    #endif

    float specular = pow(max(dot(reflectionDir, lightDir), 0.0), 8.0);
    color += lightColor * specular * GetMaterialAlbedo(materialID);
    color += GetMaterialEmissive(materialID);
    color += AMBIENT_LIGHT * GetMaterialAlbedo(materialID);
}

vec3 Render(in vec3 rayOrigin, in vec3 rayDir)
{
    vec3 vColor = vec3(0.0);
    vec3 oColor = vec3(0.0);
    float fDepth = SCENE_MAX_T;
    float oVisibility = 1.0;
    const float marchSize = 0.2;  // Reduced from 0.6 to 0.2 for finer detail

    vec3 normal = vec3(0.0);
    vec3 vnormal = vec3(0.0);
    int vmaterialId = INVALID_MATERIAL_ID;
    int materialId = INVALID_MATERIAL_ID;

    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }

    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);

    if (vDepth > 0.0) {
        for (int i = 0; i < MAX_VOLUME_STEPS; i++) {
            vDepth += marchSize;
            if (vDepth > oDepth) break;

            vec3 p = rayOrigin + rayDir * vDepth;
            float sdfValue = SdVolume(p);
            bool inVolume = (sdfValue < 0.0);
            if (inVolume) {
                float prevVisibility = oVisibility;
                oVisibility *= BeerLambert(VOLUMETRIC_ABSORPTION * FogDensity(p, sdfValue), marchSize);
                if (oVisibility < MIN_OPACITY) {
                    break;
                }
                float marchAbsorption = prevVisibility - oVisibility;
                {
                    vec3 lightPos = uLightPosition;
                    float lightDist = length(lightPos - p);
                    vec3 lightDir = normalize(lightPos - p);
                    vec3 lightCol = uLightColor * GetLightAttenuation(lightDist);
                    if (!IsColorInsignificant(lightCol)) {
                        lightCol *= VolumeLightVisibility(
                            p, lightDir, lightDist,
                            MAX_LIGHTMARCH_STEPS, marchSize * 1.4
                        );
                    }
                    vColor += marchAbsorption * VOLUMETRIC_ALBEDO * lightCol;
                }
                vColor += marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
            }
        }
    }

    if (materialId != INVALID_MATERIAL_ID) {
        vec3 position = rayOrigin + rayDir * oDepth;
        if (IsLightSource(materialId)) {
            oColor = GetSkyColor(rayDir);
        } else {
            vec3 reflectionDir = reflect(rayDir, normal);
            CalculateLighting(position, normal, reflectionDir, materialId, oColor);
        }
    } else {
        oColor = GetSkyColor(rayDir);
    }

    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}

//------------------------------------------------------------------
// Main entry point: Use precomputed ray data from the vertex shader
//------------------------------------------------------------------
in vec2 vUV;
in vec3 vRayOrigin;
in vec3 vRayDirection;

void main()
{
    // Use the interpolated values computed in the vertex shader.
    vec2 uv = vUV;
    vec3 rayOrigin = vRayOrigin;
    vec3 rayDirection = vRayDirection;

    vec3 color = vec3(0.0);
    vec3 normal = vec3(0.0);
    int materialID = INVALID_MATERIAL_ID;

    float depth = IntersectOpaqueScene(rayOrigin, rayDirection, materialID, normal);
    color = Render(rayOrigin, rayDirection);

    #if USE_BLUE_NOISE
    if (Luminance(color) > NOISE_THRESHOLD) {
    float noiseVal = texture(iChannel0, uv).r - 0.5;
    color += noiseVal * NOISE_JITTER;
}
    #endif

    color = LinearToSRGB(color);
    fragColor = vec4(color, 1.0);
}