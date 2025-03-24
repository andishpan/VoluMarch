#version 330 core

// Fragment shader outputs
out vec4 fragColor;

// ShaderToy-style uniforms
uniform vec3  iResolution;   // (width, height, depth=1)
uniform float iTime;         // Elapsed time in seconds
uniform vec4  iMouse;        // (x, y, 0, 0) when pressed, else (0,0,0,0)
uniform sampler2D iChannel0; // blue noise


// Camera uniforms
uniform vec3  uCameraPosition;
uniform vec3  uCameraLookAt;
uniform float uLensHeight;
uniform float uFocalDistance;



// Single light uniform
uniform vec3 uSunDirection;  // Direction from which the sun's light comes (normalized)
uniform float uSunIntensity; // A multiplier for the sun's brightness

uniform mat4 uViewMatrix;
//--------------------------------
//           #define(s)
//--------------------------------
#define PI 3.14159
#define LARGE_NUMBER 1e20
#define EPSILON 0.0001
#define SCENE_MAX_T 900.0

// Features
#define CAST_SHADOW_ON_OPAQUE 1
#define USE_BLUE_NOISE 1

//--------------------------------
//  Here is where we define we have
//  only 1 lamp, so it's a single
//  small lamp in the scene
//--------------------------------
#define NUM_LIGHTS 0

//--------------------------------
//light const
//--------------------------------
#define LIGHT_ATTENUATION 1.3

// Debug mode uniform
uniform int uObjectShape; // sphere, rbox,torus

const float EXTINCTION_MULT = 1.0;



const vec3 AMBIENT_LIGHT = vec3(0.04, 0.05, 0.07); // slight blue tint


// Volume
const vec3 VOLUMETRIC_ALBEDO = vec3(1.0, 0.98, 0.95);


//bigger value => denser clouds
const float VOLUMETRIC_ABSORPTION = 0.1;

// Minimum opacity for volume steps
#define MIN_OPACITY 0.05
#define NOISE_JITTER 0.02
#define NOISE_THRESHOLD 0.03

// Volume shape
#define BLEND_STRENGTH 1.75
#define GROUND_STICK 13.
#define NUM_OCTAVES 16
#define NOISE 10
#define NOISE_HEIGHT 16.0

// Raymarch
#define MAX_STEPS 40
#define MAX_VOLUME_STEPS 40
#define MAX_SHADOWMARCH_STEPS 25
#define MAX_LIGHTMARCH_STEPS 25
#define SURFACE_DIST 0.03

// Materials
#define INVALID_MATERIAL_ID int(-1)
#define LAMP_MATERIAL_ID 0
#define DEBUG_MATERIAL_ID 1
#define NUM_MATERIALS (LAMP_MATERIAL_ID + NUM_LIGHTS + 1)
#define MATERIAL_IS_LIGHT_SOURCE 0x1
#define ENABLE_SPACE_WARPING 1 // set to 0 to disable warping easily
uniform vec3 uAlbedo[NUM_MATERIALS];
uniform vec3 uEmissive[NUM_MATERIALS];
uniform int uFlags[NUM_MATERIALS];



// Check if material is a light source
bool IsLightSource(int materialID) {
    return (uFlags[materialID] & MATERIAL_IS_LIGHT_SOURCE) != 0;
}



// Get material properties directly from indexed uniforms
vec3 GetMaterialAlbedo(int materialID) {
    return uAlbedo[materialID];
}

vec3 GetMaterialEmissive(int materialID) {
    return uEmissive[materialID];
}

int GetMaterialFlags(int materialID) {
    return uFlags[materialID];
}


//--------------------------------
//   Helper for light attenuation
//--------------------------------
float GetLightAttenuation(float distanceToLight)
{
    // ~ 1 / distance^1.3
    return 1.0 / pow(distanceToLight, LIGHT_ATTENUATION);
}

//--------------------------------
//   Beer-Lambert
//--------------------------------
float BeerLambert(float absorptionCoefficient, float distanceTraveled) {
    return exp(-absorptionCoefficient * distanceTraveled);
}

//--------------------------------
//   HenyeyGreenstein
//--------------------------------

float HenyeyGreenstein(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
}

float DualLobeHG(float cosTheta, float gForward, float gBackward, float mixFactor) {
    float hgForward  = HenyeyGreenstein(cosTheta, gForward);
    float hgBackward = HenyeyGreenstein(cosTheta, gBackward);
    return mix(hgBackward, hgForward, mixFactor);
}

//--------------------------------
//   MultipleOctaveScattering
//--------------------------------
float MultipleOctaveScattering(float density, float mu)
{
    float attenuation      = 0.2;
    float contribution     = 0.4;
    float phaseAttenuation = 0.1;
    const float scatteringOctaves = 4.0;

    // Multipliers for light absorption and scattering
    float a = 1.0; // distance-based attenuation (like depth)
    float b = 1.0; // per-octave intensity contribution
    float c = 1.0; // phase function attenuation
    float g = 0.85; // asymmetry for phase function (forward scattering)


    float gF = 0.6;   // Forward lobe
    float gB = -0.3;  // Backward lobe
    float mixFactor = 0.8; // 0 = pure backscatter, 1 = pure forward

    float luminance = 0.0;

    for (float i = 0.0; i < scatteringOctaves; i++) {
        float phaseFunction = HenyeyGreenstein(0.3 * c, mu); // Your HG or dual-lobe function


       float beers = exp(-density * EXTINCTION_MULT * a); // Like Beer-Lambert

        luminance += b * phaseFunction * beers;

        // Attenuate for next octave
        a *= attenuation;
        b *= contribution;
        c *= (1.0 - phaseAttenuation);
    }

    return luminance;
}


//--------------------------------
//   DualScattering
//--------------------------------
float DualScattering(float density, float mu)
{
    float attenuation      = 0.2;
    float contribution     = 0.4;
    float phaseAttenuation = 0.1;
    const float scatteringOctaves = 4.0;

    // Multipliers for light absorption and scattering
    float a = 1.0; // distance-based attenuation (like depth)
    float b = 1.0; // per-octave intensity contribution
    float c = 1.0; // phase function attenuation
    float g = 0.85; // asymmetry for phase function (forward scattering)


    float gF = 0.6;   // Forward lobe
    float gB = -0.3;  // Backward lobe
    float mixFactor = 0.8; // 0 = pure backscatter, 1 = pure forward

    float luminance = 0.0;

    for (float i = 0.0; i < scatteringOctaves; i++) {
        // float phaseFunction = HenyeyGreenstein(0.3 * c, mu); // Your HG or dual-lobe function
        float phaseFunction = DualLobeHG(mu, gF, gB, mixFactor);

        float beers = exp(-density * EXTINCTION_MULT * a); // Like Beer-Lambert

        luminance += b * phaseFunction * beers;

        // Attenuate for next octave
        a *= attenuation;
        b *= contribution;
        c *= (1.0 - phaseAttenuation);
    }

    return luminance;
}


//--------------------------------
//        Color Utilities
//--------------------------------
float Luminance(vec3 color) {
    return (color.r * 0.3) + (color.g * 0.59) + (color.b * 0.11);
}

bool IsColorInsignificant(vec3 color) {
    const float minValue = 0.009;
    return Luminance(color) < minValue;
}

// Returns component-wise 1 if f < value, else 0
vec3 LessThan(vec3 f, float value)
{
    return vec3(
    (f.x < value) ? 1.0 : 0.0,
    (f.y < value) ? 1.0 : 0.0,
    (f.z < value) ? 1.0 : 0.0
    );
}

// Convert from linear to sRGB
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
        float n = perlinNoise(x);
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
    float density = abs(fbm(p / 6.0) + 0.5);
    return sdfMultiplier * density;
}





//--------------------------------
//  SDF shapes
//--------------------------------

float sdPlane(vec3 p) {
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

//--------------------------------
//   Intersect Opaque Scene
//--------------------------------
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
    // Normalize direction just in case
    dir = normalize(dir);

    // Spherical/equirectangular:
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * PI);
    float v = 0.5 - asin(dir.y) / PI;

    // Wrap UV if out of [0..1]
    return fract(vec2(u, v));
}

/*vec3 GetSkyColor(vec3 dir)
{
    vec2 uv = SphericalUV(dir);
    // Sample iChannel0
    return texture(iChannel0, uv).rgb;
}*/


//--------------------------------
//  Volumetric SDF
//--------------------------------


/*float SdVolume(vec3 p)
{
    // 1) Distances for each shape
    float dSphere = SdSphere(p, vec3(-10.0, 10.0, 0.0), 10.0);
    float dTorus  = SdTorus(p,  vec3(30.0, 10.0, 0.0), 12.0, 5.0);
    float dBox    = SdRoundedBox(p, vec3(-15.0, 10.0, 30.0), vec3(3.0, 3.0, 3.0), 1.0);

    // 2) If you want them *completely separate*, use plain min() instead of SdSmoothUnion.
    float d = min(dSphere, min(dTorus, dBox));

    // 3) Add the fractal noise offset => fluffy/cloudy edges on each shape
    vec3 fbmCoord = (p + vec3(iTime * 2.0, 0.0, iTime * 2.0)) / NOISE;
    d += NOISE_HEIGHT * fbm(fbmCoord);

    return d;
} */

/*float SdVolume(vec3 p)
{
    // Define original positions and sizes
    vec3 sphereCenter = vec3(-10.0, 0.0, -35.0);
    float sphereRadius = 10.0;

    vec3 torusCenter = vec3(30.0, 0.0, -35.0);
    float torusR = 12.0;
    float torusr = 5.0;

    vec3 boxCenter = vec3(-5.0, 0.0, -35.0);
    vec3 boxHalfExtents = vec3(4.0, 4.0, 4.0);
    float boxRoundRadius = 1.0;

    // Define smaller cube parameters for clouds
    vec3 cubeCenter = vec3(-50.0, 0.0, -35.0); // Position the cube closer to the ground or desired location
    vec3 cubeHalfExtents = vec3(10.0, 10.0, 10.0); // Reduced size of the cube
    float cubeRoundRadius = 1.0; // Reduced rounding for sharper edges (optional)


    // Combine shapes based on uObjectShape
    float dSphere = (uObjectShape == 1)
    ? SdTorus(p, sphereCenter, sphereRadius, 3.0)
    : sdSphere(p, sphereCenter, sphereRadius);

    float dBox = (uObjectShape == 2)
    ? sdSphere(p, boxCenter, 3.0)
    : SdRoundedBox(p, boxCenter, boxHalfExtents, boxRoundRadius);

    float dTorus = (uObjectShape == 3)
    ? SdRoundedBox(p, torusCenter, vec3(torusR, torusr, torusr), 1.0)
    : SdTorus(p, torusCenter, torusR, torusr);

    // Add the cube SDF for volumetric clouds
    float dCube = SdCube(p, cubeCenter, cubeHalfExtents, cubeRoundRadius);

    // Combine the distances using minimum (union) for volumetric clouds
    // You can adjust the blending method as needed
    float d = min(dCube, min(dSphere, min(dTorus, dBox)));

    // Add animated fractal noise for volumetric effects
    vec3 fbmCoord = (p + vec3(iTime * 2.0, 0.0, iTime * 2.0)) / NOISE;
    d += NOISE_HEIGHT * fbm(fbmCoord);

    return d;
} */


//------------------------------------
// 2) 3D Noise (fBm)
//------------------------------------
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



// Smooth union function provided:
float opSmoothUnion( float d1, float d2, float k )
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h);
}

/*float SdVolume(vec3 p)
{
    // Scale the position to enlarge the entire cloud structure.
    float scaleFactor = 1.2;
    p /= scaleFactor;

    // Define centers for three cloud layers
    vec3 center1 = vec3(0.0, 20.0, -25.0);      // Bottom cloud
    vec3 center2 = vec3(30.0, 35.0, -25.0);     // Middle cloud
    vec3 center3 = vec3(-20.0, 45.0, -25.0);     // Top cloud
    float radius = 8.0;

    // Bottom cloud formation
    float d1 = length(p - center1) - radius;
    vec3 offset2 = vec3(8.0, 0.0, 0.0);
    float d2 = length(p - (center1 + offset2)) - radius;
    vec3 offset3 = vec3(-8.0, 0.0, 0.0);
    float d3 = length(p - (center1 + offset3)) - radius;

    // Middle cloud formation (slightly smaller)
    float d4 = length(p - center2) - radius;
    vec3 offset4 = vec3(6.0, 0.0, 0.0);
    float d5 = length(p - (center2 + offset4)) - radius ;
    vec3 offset5 = vec3(-6.0, 0.0, 0.0);
    float d6 = length(p - (center2 + offset5)) - radius;

    // Top cloud formation (even smaller)
    float d7 = length(p - center3) - radius ;
    vec3 offset6 = vec3(4.0, 0.0, 0.0);
    float d8 = length(p - (center3 + offset6)) - radius ;
    vec3 offset7 = vec3(-4.0, 0.0, 0.0);
    float d9 = length(p - (center3 + offset7)) - radius;

    float k = 2.0; // Smoothing factor

    // Combine bottom cloud spheres
    float dSpheresBottom = opSmoothUnion(opSmoothUnion(d1, d2, k), d3, k);

    // Combine middle cloud spheres
    float dSpheresMiddle = opSmoothUnion(opSmoothUnion(d4, d5, k), d6, k);

    // Combine top cloud spheres
    float dSpheresTop = opSmoothUnion(opSmoothUnion(d7, d8, k), d9, k);

    // Combine all three layers
    float dAllClouds = opSmoothUnion(
        opSmoothUnion(dSpheresBottom, dSpheresMiddle, k),
        dSpheresTop,
        k
    );

    // Add noise to create cloud-like appearance
    vec3 fbmCoord = (p + vec3(iTime * 0.5, 0.0, iTime * 0.5)) / NOISE;
   // vec3 fbmCoord = p / NOISE;
    dAllClouds += NOISE_HEIGHT * fbm(fbmCoord);

    // Reverse the scaling on the distance so it fits the scene scale
    return dAllClouds * scaleFactor;
} */



float SdVolume(vec3 p)
{

    float scaleFactor = 1.2;
    p /= scaleFactor;

    vec3 center1 = vec3(0.0, 20.0, -25.0);

    float radius = 8.0;

    float d1 = length(p - center1) - radius;
    vec3 offset2 = vec3(8.0, 0.0, 0.0);
    float d2 = length(p - (center1 + offset2)) - radius;
    vec3 offset3 = vec3(-8.0, 0.0, 0.0);
    float d3 = length(p - (center1 + offset3)) - radius;

    float k = 2.0; // Smoothing factor

    // Combine bottom cloud spheres
    float cloud = opSmoothUnion(opSmoothUnion(d1, d2, k), d3, k);


    // Add noise to create cloud-like appearance
    vec3 fbmCoord = (p + vec3(iTime * 0.5, 0.0, iTime * 0.5)) / NOISE;
    // vec3 fbmCoord = p / NOISE;
    cloud += NOISE_HEIGHT * fbm(fbmCoord);

    // Reverse the scaling on the distance so it fits the scene scale
    return cloud * scaleFactor;
}

// cloud morphing
/* SdVolume(vec3 p)
{
    float tCycle = mod(iTime, 30.0);
    float phase = tCycle / 30.0;

    float dReal = computeRealCloudSDF(p); // your original real cloud shape
    float dSphere = sdSphere(p, vec3(0, 10, -25), 12.0);
    float dCube = SdCube(p, vec3(0, 10, -25), vec3(8.0), 1.0);

    float sdf;

    if (phase < 0.33) {
        float t = smoothstep(0.0, 0.33, phase);
        sdf = mix(dReal, dSphere, t);
    }
    else if (phase < 0.66) {
        float t = smoothstep(0.33, 0.66, phase);
        sdf = mix(dSphere, dCube, t);
    }
    else {
        float t = smoothstep(0.66, 1.0, phase);
        sdf = mix(dCube, dReal, t);
    }

    // Add detail
    sdf += NOISE_HEIGHT * fbm(p / NOISE);
    return sdf;
} */







/*float SdVolume(vec3 pos)
{
    vec3 fbmCoord = (pos + 2.0 * vec3(iTime, 0.0, iTime)) / 1.5;
    float sdfValue = sdSphere(pos, vec3(-8.0, 2.0 + 20.0 * sin(iTime), -1), 5.6);
    sdfValue = opSmoothUnion(sdfValue, sdSphere(pos, vec3(8.0, 8.0 + 12.0 * cos(iTime), 3), 5.6), 3.0);
    sdfValue = opSmoothUnion(sdfValue, sdSphere(pos, vec3(5.0 * sin(iTime), 3.0, 0), 8.0), 3.0)
    + 7.0 * fbm(fbmCoord / 3.2);
    //sdfValue = opSmoothUnion(sdfValue, sdPlane(pos + vec3(0, 0.1, 0)), 3.0);
    return sdfValue;
} */






//--------------------------------
//   First pass: volume or not?
//--------------------------------
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

//--------------------------------
//   Volume Light Visibility
//--------------------------------
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


//--------------------------------
//     Diffuse lighting
//--------------------------------
vec3 Diffuse(in vec3 normal, in vec3 lightVec, in vec3 diffuseColor)
{
    float nDotL = dot(normal, lightVec);
    return clamp(nDotL, 0.0, 1.0) * diffuseColor;
}

//--------------------------------
//   Summation of (single) Light
//--------------------------------
void CalculateLighting(
    vec3 position,
    vec3 normal,
    vec3 reflectionDir,
    int materialID,
inout vec3 color
)
{
    // Use the sun's direction; ensure it's normalized.
    vec3 lightDir   = normalize(uSunDirection);
    // Set a constant sun light color using a bright, white or slightly yellowish tint.
    vec3 lightColor = vec3(1.0, 0.95, 0.8) * uSunIntensity;

    // Diffuse lighting (Lambertian)
    vec3 diffuse = Diffuse(normal, lightDir, GetMaterialAlbedo(materialID));
    color += lightColor * diffuse;

    // Specular lighting (Phong)
    float specular = pow(max(dot(reflectionDir, lightDir), 0.0), 8.0);
    color += lightColor * specular * GetMaterialAlbedo(materialID);

    // Add emissive color
    color += GetMaterialEmissive(materialID);

    // Add ambient light (you might adjust this for a daytime scene)
    color += AMBIENT_LIGHT * GetMaterialAlbedo(materialID);
}





//--------------------------------
//        Main Render
//--------------------------------
vec3 Render(in vec3 rayOrigin, in vec3 rayDir)
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

    // 1) Intersect with opaque geometry
    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }

    // 2) Check volumetric
    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);

    // 3) Raymarch volume if we entered
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
               // oVisibility *= BeerLambert(VOLUMETRIC_ABSORPTION * FogDensity(p, sdfValue), marchSize);
                // Transmittance (classic)
                float T = BeerLambert(VOLUMETRIC_ABSORPTION * fog, marchSize);
                oVisibility *= T;
                float marchAbsorption = prevVisibility - oVisibility;



                if (oVisibility < MIN_OPACITY) {
                    break;
                }


                // Sun light contribution
                vec3 lightDir = normalize(uSunDirection);
                vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;

                // Powder in-scattering
                float powderStrength = 0.7;
                float mu = dot(-rayDir, lightDir);
                powderStrength *= clamp(1.0 - mu, 0.0, 1.0); // More glow on back side

                float powder = 1.0 - exp(-VOLUMETRIC_ABSORPTION *fog * marchSize * powderStrength);

                if (!IsColorInsignificant(lightCol)) {
                    lightCol *= VolumeLightVisibility(
                        p, lightDir, 1000.0, // Using a large distance for sun light
                        MAX_LIGHTMARCH_STEPS, marchSize * 1.4
                    );
                }

               // vec3 lightTint = mix(vec3(1.0, 0.95, 0.8), vec3(1.0, 0.6, 0.3), pow(1.0 - mu, 2.0));
              //  lightCol *= lightTint;

                // Final contribution (you can weight this!)
                //vec3 scatterLight = lightCol * powder;
                float blend = 0.6; // try 0.4 - 0.7
                vec3 scatterLight = mix(marchAbsorption * lightCol, powder * lightCol, blend);

                vColor += scatterLight * VOLUMETRIC_ALBEDO;
                vColor += marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
            }
        }
    }

    // 4) Opaque shading or sky
    if (materialId != INVALID_MATERIAL_ID)
    {
        // We hit an object
        vec3 position = rayOrigin + rayDir * oDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        CalculateLighting(position, normal, reflectionDir, materialId, oColor);
    }
    else
    {
        // No intersection => sample sky texture
        //oColor = vec3(0.7, 0.85, 1.0);
        oColor = vec3(0.2, 0.5, 1.0);
    }

    // Combine
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

    // 1) Intersect with opaque geometry
    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }

    // 2) Check volumetric
    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);

    // 3) Raymarch volume if we entered
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

                    oVisibility *= BeerLambert(VOLUMETRIC_ABSORPTION * fog, localStep);

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

                    // Ambient light
                    vColor += amplitude * marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
                }
            }

            // Octave falloff
            amplitude *= 0.5;       // reduce influence
            scatterScale *= 2.0;    // more detail
        }

    }

    // 4) Opaque shading or sky
    if (materialId != INVALID_MATERIAL_ID)
    {
        // We hit an object
        vec3 position = rayOrigin + rayDir * oDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        CalculateLighting(position, normal, reflectionDir, materialId, oColor);
    }
    else
    {
        // No intersection => sample sky texture
        oColor = vec3(0.7, 0.85, 1.0);
    }

    // Combine
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

    // 1) Intersect with opaque geometry
    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }

    // 2) Check volumetric
    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);

    // 3) Raymarch volume if we entered
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

                    oVisibility *= BeerLambert(VOLUMETRIC_ABSORPTION * fog, localStep);

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

                    // Ambient light
                    vColor += amplitude * marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
                }
            }

            // Octave falloff
            amplitude *= 0.5;       // reduce influence
            scatterScale *= 2.0;    // more detail
        }

    }

    // 4) Opaque shading or sky
    if (materialId != INVALID_MATERIAL_ID)
    {
        // We hit an object
        vec3 position = rayOrigin + rayDir * oDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        CalculateLighting(position, normal, reflectionDir, materialId, oColor);
    }
    else
    {
        // No intersection => sample sky texture
        oColor = vec3(0.7, 0.85, 1.0);
    }

    // Combine
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

    // 1) Intersect with opaque geometry
    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }

    // 2) Check volumetric
    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);

    // 3) Raymarch volume if we entered
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
                    oVisibility *= BeerLambert(VOLUMETRIC_ABSORPTION * fog, localStep);

                    if (oVisibility < MIN_OPACITY) break;

                    float marchAbsorption = prevVisibility - oVisibility;

                    vec3 viewDir = -rayDir;
                    vec3 lightDir = normalize(uSunDirection);
                    vec3 lightCol = vec3(1.0, 0.95, 0.8) * uSunIntensity;


                    if (!IsColorInsignificant(lightCol)) {
                        float cosTheta = dot(viewDir, lightDir);

                        // Example parameters:
                        float gF = 0.6;   // Forward lobe
                        float gB = -0.3;  // Backward lobe
                        float mixFactor = 0.8; // 0 = pure backscatter, 1 = pure forward
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

                    // Ambient
                    vColor += amplitude * marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
                }
            }

            // Octave falloff
            amplitude *= 0.5;       // reduce influence
            scatterScale *= 2.0;    // more detail
        }

    }

    // 4) Opaque shading or sky
    if (materialId != INVALID_MATERIAL_ID)
    {
        // We hit an object
        vec3 position = rayOrigin + rayDir * oDepth;
        vec3 reflectionDir = reflect(rayDir, normal);
        CalculateLighting(position, normal, reflectionDir, materialId, oColor);
    }
    else
    {
        // No intersection => sample sky texture
        oColor = vec3(0.7, 0.85, 1.0);
    }

    // Combine
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}


//------------------------------------------------------------------
// Main entry point: Use precomputed ray data from the vertex shader
//------------------------------------------------------------------

in vec3 vRayOrigin;
in vec3 vRayDirection;

void main()
{

    vec3 rayOrigin = vRayOrigin;
    vec3 rayDirection = vRayDirection;

    vec3 color = vec3(0.0);
    vec3 normal = vec3(0.0);
    int materialID = INVALID_MATERIAL_ID;

    float depth = IntersectOpaqueScene(rayOrigin, rayDirection, materialID, normal);
    color = Render(rayOrigin, rayDirection);

    // Optionally apply noise
    #if USE_BLUE_NOISE
     // We'll use the same uv that you use for your screen, i.e. fragCoord / iResolution
    // but you can scale it to tile if your blue noise texture is small
    float noiseVal = texture(iChannel0, gl_FragCoord.xy / iResolution.xy).r;

    // Dither only where color is significant, or always.
    // The code below only dithers if color is above NOISE_THRESHOLD.
    if (Luminance(color) > NOISE_THRESHOLD)
    {
        color += (noiseVal - 0.5) * NOISE_JITTER;
        // e.g. NOISE_JITTER = 0.02 for subtle dithering
    }
    #endif

    // Convert to sRGB
    color = LinearToSRGB(color);
    fragColor = vec4(color, 1.0);
}