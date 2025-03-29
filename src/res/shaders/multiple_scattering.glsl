#version 330 core


out vec4 fragColor;


uniform vec3  iResolution;   
uniform float iTime;         
uniform vec4  iMouse;        
uniform sampler2D iChannel0; 



uniform vec3  uCameraPosition;
uniform vec3  uCameraLookAt;
uniform float uLensHeight;
uniform float uFocalDistance;




uniform vec3 uLightPosition;  
uniform vec3 uLightColor;     
uniform float uLightRadius;   


uniform mat4 uViewMatrix;



#define PI 3.14159
#define LARGE_NUMBER 1e20
#define EPSILON 0.0001
#define SCENE_MAX_T 900.0


#define CAST_SHADOW_ON_OPAQUE 1
#define USE_BLUE_NOISE 0






#define NUM_LIGHTS 1




#define LIGHT_ATTENUATION 1.3
#define LIGHT_INTENSITY 400.0

const float EXTINCTION_MULT = 1.0; 




const vec3 LAMP_COLOR  = vec3(1.0, 0.8, 0.5);


const vec3 AMBIENT_LIGHT = vec3(0.01, 0.005, 0.005);


const vec3 VOLUMETRIC_ALBEDO = vec3(0.95, 0.95, 0.95);

const float VOLUMETRIC_ABSORPTION = 0.25;


#define MIN_OPACITY 0.05
#define NOISE_JITTER 0.02
#define NOISE_THRESHOLD 0.03


#define BLEND_STRENGTH 1.75
#define GROUND_STICK 13.
#define NUM_OCTAVES 4
#define NOISE 3.
#define NOISE_HEIGHT 2.0


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







struct Material {
    vec3 albedo;
    vec3 emissive;
    int flags;
};



bool IsLightSource(in Material m) {
    return (m.flags & MATERIAL_IS_LIGHT_SOURCE) != 0;
}







float GetLightAttenuation(float distanceToLight)
{
    
    return 1.0 / pow(distanceToLight, LIGHT_ATTENUATION);
}





float PhaseFunction(float g, float mu) {
    return (1.0 - g * g) / (4.0 * PI * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
}





float MultipleOctaveScattering(float density, float mu) {
    float attenuation = 0.6;   
    float contribution = 1.1;  
    float phaseAttenuation = 0.4; 

    const float scatteringOctaves = 8.0; 

    float a = 1.0;  
    float b = 1.0; 
    float c = 1.0; 
    float g = 0.85; 

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




float FogDensity(vec3 p, float sdfValue)
{
    float sdfMultiplier = (sdfValue < 0.0) ? min(abs(sdfValue), 1.0) : 0.0;
    float density = abs(fbm(p / 6.0) + 0.5);
    return sdfMultiplier * density;
}






float SdPlane(vec3 p) {
    
    return p.y;
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






Material NormalMaterial(vec3 albedo, int flags) {
    Material m;
    m.albedo   = albedo;
    m.emissive = vec3(0);
    m.flags    = flags;
    return m;
}




Material GetMaterial(int materialID, vec3 position)
{
    Material materials[NUM_MATERIALS];

    
    materials[DEBUG_MATERIAL_ID] = NormalMaterial(vec3(0.6, 0.6, 0.7), 0);

    
    materials[LAMP_MATERIAL_ID + 0] = NormalMaterial(
        uLightColor,  
        MATERIAL_IS_LIGHT_SOURCE
    );

    Material mat;
    if (materialID < int(NUM_MATERIALS)) {
        mat = materials[materialID];
    } else {
        mat = materials[0]; 
    }

    

    return mat;
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
    
    float dSphere = SdSphere(p, vec3(-10.0, 10.0, 0.0), 10.0);
    float dTorus  = SdTorus(p,  vec3(30.0, 10.0, 0.0), 12.0, 5.0);
    float dBox    = SdRoundedBox(p, vec3(-15.0, 10.0, 30.0), vec3(3.0, 3.0, 3.0), 1.0);

    
    float d = min(dSphere, min(dTorus, dBox));

    
    vec3 fbmCoord = (p + vec3(iTime * 2.0, 0.0, iTime * 2.0)) / NOISE;
    d += NOISE_HEIGHT * fbm(fbmCoord);

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
in float marchSize,
   float mu 
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





vec3 Diffuse(in vec3 normal, in vec3 lightVec, in vec3 diffuseColor)
{
    float nDotL = dot(normal, lightVec);
    return clamp(nDotL, 0.0, 1.0) * diffuseColor;
}


void CalculateLighting(
    vec3 position,
    vec3 normal,
    vec3 reflectionDir,
    Material material,
inout vec3 color
) {
    vec3 lightPos   = uLightPosition;
    float lightDist = length(lightPos - position);
    vec3 lightDir   = normalize(lightPos - position);
    vec3 lightColor = uLightColor * GetLightAttenuation(lightDist);

    
    float mu = dot(-normalize(reflectionDir), lightDir); 

    #if CAST_SHADOW_ON_OPAQUE
    
    if (!IsColorInsignificant(lightColor)) {
        lightColor *= VolumeLightVisibility(
            position, lightDir, lightDist,
            MAX_SHADOWMARCH_STEPS,
            0.6,
            mu
        );
    }
    #endif

    
    color += lightColor * pow(max(dot(reflectionDir, lightDir), 0.0), 8.0);

    
    color += lightColor * Diffuse(normal, lightDir, material.albedo);

    
    color += AMBIENT_LIGHT * material.albedo;
}







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

    
    float oDepth = IntersectOpaqueScene(rayOrigin, rayDir, materialId, normal);
    if (materialId != INVALID_MATERIAL_ID) {
        fDepth = oDepth;
    }

    
    float vDepth = IntersectVolumetric(rayOrigin, rayDir, fDepth, vmaterialId, vnormal);

    
    if (vDepth > 0.0)
    {
        float attenuationExponent = 2.0; 
        float mu = 0.0; 

        for (int i = 0; i < MAX_VOLUME_STEPS; i++) {
            vDepth += marchSize;
            if (vDepth > oDepth) break;

            vec3 p = rayOrigin + rayDir * vDepth;
            float sdfValue = SdVolume(p);
            bool inVolume  = (sdfValue < 0.0);
            if (inVolume) {
                float prevVisibility = oVisibility;

                
                float density = VOLUMETRIC_ABSORPTION * FogDensity(p, sdfValue);

                
                vec3 lightDir = normalize(uLightPosition - p);
                mu = dot(rayDir, lightDir); 

                
                oVisibility *= MultipleOctaveScattering(density, mu);

                if (oVisibility < MIN_OPACITY) {
                    break;
                }
                float marchAbsorption = prevVisibility - oVisibility;

                
                {
                    vec3 lightPos  = uLightPosition;
                    float lightDist= length(lightPos - p);
                    vec3 lightDir  = normalize(lightPos - p);
                    vec3 lightCol  = uLightColor * GetLightAttenuation(lightDist);

                    if (!IsColorInsignificant(lightCol)) {
                        float localMu = dot(lightDir, rayDir); 
                        lightCol *= VolumeLightVisibility(
                            p, lightDir, lightDist,
                            MAX_LIGHTMARCH_STEPS, marchSize * 1.4,
                            localMu
                        );
                    }
                    vColor += marchAbsorption * VOLUMETRIC_ALBEDO * lightCol;
                }

                
                vColor += marchAbsorption * VOLUMETRIC_ALBEDO * AMBIENT_LIGHT;
            }
        }
    }


    
    if (materialId != INVALID_MATERIAL_ID)
    {
        
        vec3 position = rayOrigin + rayDir * oDepth;
        Material material = GetMaterial(materialId, position);

        if (IsLightSource(material)) {
                    
            oColor = GetSkyColor(rayDir);
        } else {
            vec3 reflectionDir = reflect(rayDir, normal);
            CalculateLighting(position, normal, reflectionDir, material, oColor);
        }
    }
    else
    {
        
        oColor = GetSkyColor(rayDir);
    }

    
    return clamp(vColor, 0.0, 1.0) + oVisibility * oColor;
}




float GetCameraPositionYOffset() {
    return 250.0 * (iMouse.y / iResolution.y);
}

float GetRotationFactor() {
    if (iMouse.x <= 0.0) {
        
        return 0.65;
    }
    return iMouse.x / iResolution.x;
}




void main()
{
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 uv = fragCoord / iResolution.xy;

    float aspectRatio = iResolution.x / iResolution.y;
    float lensWidth   =  aspectRatio; 

    
    vec3 cameraForward = normalize(-vec3(uViewMatrix[2][0], uViewMatrix[2][1], uViewMatrix[2][2]));
    vec3 cameraRight   = normalize(vec3(uViewMatrix[0][0], uViewMatrix[0][1], uViewMatrix[0][2]));
    vec3 cameraUp      = normalize(vec3(uViewMatrix[1][0], uViewMatrix[1][1], uViewMatrix[1][2]));

    
    vec3 cameraPosition = uCameraPosition;
    
    cameraPosition.y += (iMouse.y / iResolution.y) * 50.0; 

    
    vec3 rayOrigin    = cameraPosition;
    vec3 rayDirection = normalize(cameraForward + (uv.x * 2.0 - 1.0) * cameraRight * lensWidth + (uv.y * 2.0 - 1.0) * cameraUp * 1.0);

    
    vec3 color = Render(rayOrigin, rayDirection);

    #if USE_BLUE_NOISE
    if (Luminance(color) > NOISE_THRESHOLD) {
    float noiseVal = texture(iChannel0, uv).r - 0.5;
    color += noiseVal * NOISE_JITTER;
}
    #endif

    
    color = LinearToSRGB(color);
    fragColor = vec4(color, 1.0);
}
