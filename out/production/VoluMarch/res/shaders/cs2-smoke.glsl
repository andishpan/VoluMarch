#version 330 core

// Fragment shader outputs
out vec4 fragColor;

// ShaderToy-style uniforms
uniform vec3  iResolution;   // (width, height, depth=1)
uniform float iTime;         // Elapsed time in seconds
uniform vec4  iMouse;        // (x, y, 0, 0) when pressed, else (0,0,0,0)
uniform sampler2D iChannel0; // If you want to bind a noise texture or something else


// Camera uniforms
uniform vec3  uCameraPosition;
uniform vec3  uCameraLookAt;
uniform float uLensHeight;
uniform float uFocalDistance;



// Single light uniform
uniform vec3 uLightPosition;  // Position of the light in world space
uniform vec3 uLightColor;     // Color/intensity of the light
uniform float uLightRadius;   // Radius for the light's spherical influence


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
#define USE_BLUE_NOISE 0

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
uniform int uObjectShape; // sphere, rbox,torus
uniform int uCurrentMethod; // Beer-Lambert, Multiple Octave scattering


const float EXTINCTION_MULT = 1.0;


// Reduced ambient so the scene is mostly dark, lit by the lamp
const vec3 AMBIENT_LIGHT = vec3(0.01, 0.005, 0.005);

// Volume
const vec3 VOLUMETRIC_ALBEDO = vec3(0.95, 0.95, 0.95);

const float VOLUMETRIC_ABSORPTION = 0.25;

// Minimum opacity for volume steps
#define MIN_OPACITY 0.05
#define NOISE_JITTER 0.02
#define NOISE_THRESHOLD 0.03

// Volume shape
#define BLEND_STRENGTH 1.75
#define GROUND_STICK 13.
#define NUM_OCTAVES 4
#define NOISE 3
#define NOISE_HEIGHT 2.0

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

float PhaseFunction(float g, float mu) {
    return (1.0 - g * g) / (4.0 * PI * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
}




//--------------------------------
//  Multiple Octave Scattering Function
//--------------------------------
float MultipleOctaveScattering(float density, float mu) {
    float attenuation = 0.6;   // Controls how quickly extinction decreases per octave
    float contribution = 1.1;  // Determines the weight of each octave's contribution
    float phaseAttenuation = 0.4; // Influences the phase function's impact across octaves

    const float scatteringOctaves = 8.0; // Number of scattering events

    float a = 1.0;  // Extinction multiplier for each octave
    float b = 1.0; // Contribution multiplier for each octave
    float c = 1.0; // Phase function modifier for each octave
    float g = 0.85; // Asymmetry parameter for PhaseFunction

    float luminance = 0.0;

    for (float i = 0.0; i < scatteringOctaves; i++) {
        float phaseFunction = PhaseFunction(0.1 * c, mu);
        float beers = exp(-density * EXTINCTION_MULT * a);

        luminance += b * phaseFunction * beers;

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

    // The lamp (as a small sphere)
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
    // Normalize direction just in case
    dir = normalize(dir);

    // Spherical/equirectangular:
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * PI);
    float v = 0.5 - asin(dir.y) / PI;

    // Wrap UV if out of [0..1]
    return fract(vec2(u, v));
}

vec3 GetSkyColor(vec3 dir)
{
    vec2 uv = SphericalUV(dir);
    // Sample iChannel0
    return texture(iChannel0, uv).rgb;
}


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

float SdVolume(vec3 p)
{
    // Define original positions and sizes
    vec3 sphereCenter = vec3(-10.0, 10.0, 0.0);
    float sphereRadius = 10.0;

    vec3 torusCenter = vec3(30.0, 10.0, 0.0);
    float torusR = 12.0;
    float torusr = 5.0;

    vec3 boxCenter = vec3(-5.0, 10.0, 30.0);
    vec3 boxHalfExtents = vec3(4.0, 4.0, 4.0);
    float boxRoundRadius = 1.0;

    // Define smaller cube parameters for clouds
    vec3 cubeCenter = vec3(-50.0, 5.0, 0.0); // Position the cube closer to the ground or desired location
    vec3 cubeHalfExtents = vec3(10.0, 10.0, 10.0); // Reduced size of the cube
    float cubeRoundRadius = 1.0; // Reduced rounding for sharper edges (optional)


    // Combine shapes based on uObjectShape
    float dSphere = (uObjectShape == 1)
    ? SdTorus(p, sphereCenter, sphereRadius, 3.0)
    : SdSphere(p, sphereCenter, sphereRadius);

    float dBox = (uObjectShape == 2)
    ? SdSphere(p, boxCenter, 3.0)
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
}





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

float VolumeLightVisibility_MU(
in vec3 rO,
in vec3 rDir,
in float maxT,
in int numSteps,
in float marchSize,
   float mu // New parameter: cosine of the angle
) {
    float t = 0.0;
    float lightVis = 1.0;
    for (int i = 0; i < numSteps; i++) {
        t += marchSize;
        if (t > maxT) break;
        vec3 p = rO + t * rDir;
        if (SdVolume(p) < 0.0) {
            float density = FogDensity(p, SdVolume(p));
            lightVis *= MultipleOctaveScattering(0.1, mu);
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
    // Example in CalculateLighting function
    vec3 lightPos   = uLightPosition;
    float lightDist = length(lightPos - position);
    vec3 lightDir   = normalize(lightPos - position);
    vec3 lightColor = uLightColor * GetLightAttenuation(lightDist);

    // Calculate mu (cosine of the angle between view direction and light direction)
    float mu = dot(-normalize(reflectionDir), lightDir); // Adjust based on desired angle
    #if CAST_SHADOW_ON_OPAQUE
    // Shadow: volume-based

    if(uCurrentMethod == 1){
        if (!IsColorInsignificant(lightColor)) {
            lightColor *= VolumeLightVisibility_MU(
                position, lightDir, lightDist,
                MAX_SHADOWMARCH_STEPS,
                0.6,
                mu
            );
        }
    }else if(uCurrentMethod == 0){
        if (!IsColorInsignificant(lightColor)) {
            lightColor *= VolumeLightVisibility(
                position, lightDir, lightDist,
                MAX_SHADOWMARCH_STEPS,
                0.6
            );
        }
    }


    #endif

    // Specular lighting
    float specular = pow(max(dot(reflectionDir, lightDir), 0.0), 8.0);
    color += lightColor * specular * GetMaterialAlbedo(materialID);

    // Add emissive color
    color += GetMaterialEmissive(materialID);

    // Add ambient light
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
        float attenuationExponent = 2.0; // Example exponent value
        float mu = 0.0; // Initialize mu; will compute per step
        for (int i = 0; i < MAX_VOLUME_STEPS; i++) {
            vDepth += marchSize;
            if (vDepth > oDepth) break;

            vec3 p = rayOrigin + rayDir * vDepth;
            float sdfValue = SdVolume(p);
            bool inVolume  = (sdfValue < 0.0);
            if (inVolume) {
                float prevVisibility = oVisibility;



                if(uCurrentMethod == 1){
                    // Calculate local density
                    float density = VOLUMETRIC_ABSORPTION * FogDensity(p, sdfValue);

                    // Calculate mu (cosine of angle between light direction and view direction)
                    vec3 lightDir = normalize(uLightPosition - p);
                    mu = dot(rayDir, lightDir); // Adjust based on desired angle relationship

                    // Apply MultipleOctaveScattering
                    oVisibility *= MultipleOctaveScattering(density, mu);
                }else if(uCurrentMethod == 0){
                    oVisibility *= BeerLambert(VOLUMETRIC_ABSORPTION * FogDensity(p, sdfValue), marchSize);
                }


                if (oVisibility < MIN_OPACITY) {
                    break;
                }
                float marchAbsorption = prevVisibility - oVisibility;

                // Single lamp
                {
                    vec3 lightPos  = uLightPosition;
                    float lightDist= length(lightPos - p);
                    vec3 lightDir  = normalize(lightPos - p);
                    vec3 lightCol  = uLightColor * GetLightAttenuation(lightDist);

                    if(uCurrentMethod == 1){
                        if (!IsColorInsignificant(lightCol)) {
                            float localMu = dot(lightDir, rayDir); // Define mu based on step's light direction
                            lightCol *= VolumeLightVisibility_MU(
                                p, lightDir, lightDist,
                                MAX_LIGHTMARCH_STEPS, marchSize * 1.4,
                                localMu
                            );
                        }
                    }else if(uCurrentMethod == 0){
                        if (!IsColorInsignificant(lightCol)) {
                            lightCol *= VolumeLightVisibility(
                                p, lightDir, lightDist,
                                MAX_LIGHTMARCH_STEPS, marchSize * 1.4
                            );
                        }
                    }


                    vColor += marchAbsorption * VOLUMETRIC_ALBEDO * lightCol;
                }

                // Ambient
                vColor += marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
            }
        }
    }

    // 4) Opaque shading or sky
    if (materialId != INVALID_MATERIAL_ID)
    {
        // We hit an object
        vec3 position = rayOrigin + rayDir * oDepth;

        if (IsLightSource(materialId)) {
            // Output a distinct color for light sources
            oColor = GetSkyColor(rayDir);
            //oColor = vec3(0.0,0.0,0.0);
        } else {
            // For other materials, calculate lighting
            vec3 reflectionDir = reflect(rayDir, normal);

            // Use the existing CalculateLighting function
            CalculateLighting(position, normal, reflectionDir, materialId, oColor);
        }
    }
    else
    {
        // No intersection => sample sky texture
        oColor = GetSkyColor(rayDir);
    }

    // Combine
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}


//--------------------------------
//   main() Entry Point
//--------------------------------
void main()
{
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 uv = fragCoord / iResolution.xy;

    float aspectRatio = iResolution.x / iResolution.y;
    float lensWidth   = aspectRatio;

    // kamera richtungen
    vec3 cameraForward = normalize(-vec3(uViewMatrix[2][0], uViewMatrix[2][1], uViewMatrix[2][2]));
    vec3 cameraRight   = normalize(vec3(uViewMatrix[0][0], uViewMatrix[0][1], uViewMatrix[0][2]));
    vec3 cameraUp      = normalize(vec3(uViewMatrix[1][0], uViewMatrix[1][1], uViewMatrix[1][2]));

    // move camera up and down
    vec3 cameraPosition = uCameraPosition;
    cameraPosition.y += (iMouse.y / iResolution.y) * 90.0;

    // Build the ray
    vec3 rayOrigin    = cameraPosition;
    vec3 rayDirection = normalize(cameraForward + (uv.x * 2.0 - 1.0) * cameraRight * lensWidth + (uv.y * 2.0 - 1.0) * cameraUp * 1.0);

    // Initialize outputs
    vec3 color = vec3(0.0);
    vec3 normal = vec3(0.0);
    int materialID = INVALID_MATERIAL_ID;

    // render volumetric scene
    float depth = IntersectOpaqueScene(rayOrigin, rayDirection, materialID, normal);


    // normal rendering
    color = Render(rayOrigin, rayDirection);


    // Optionally apply noise
    #if USE_BLUE_NOISE
    if (Luminance(color) > NOISE_THRESHOLD) {
    float noiseVal = texture(iChannel0, uv).r - 0.5;
    color += noiseVal * NOISE_JITTER;
}
    #endif

    // Convert to sRGB
    color = LinearToSRGB(color);
    fragColor = vec4(color, 1.0);
}