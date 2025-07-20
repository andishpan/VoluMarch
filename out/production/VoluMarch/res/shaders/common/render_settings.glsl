#ifndef RENDER_SETTINGS_GLSL
#define RENDER_SETTINGS_GLSL
//#extension GL_NV_uniform_buffer_std430_layout : enable
layout(location = 0) out vec4  fragColor;
layout(binding = 0) uniform sampler3D  uBlueNoise;
layout(binding = 2) uniform sampler3D  uPrecomputedNoise;
layout(binding = 3) uniform samplerCube uEnvironmentMap;
layout(std430, binding = 0) buffer Counters {
    uint volume;
    uint shadow;
    uint sdf;
    uint entryCount;
};

layout(std140, binding = 1) uniform Settings {

    vec3 uCameraPosition;  float _pad0;
    vec3 uCameraLookAt;  float _pad1;
    vec3 uCameraUp;  float _pad2;

    vec3 uResolution;  float uTime;

//light
    vec3 uSunDirection;  float uSunIntensity;
    vec3 uSunColour; float uAmbientLight;


    int uCurrentMethod;
    float uVolumetricAbsorption;
    float uVolumetricScattering;
    float uPhaseG;

//shape
    int uObjectShape;
    int uPrevShape;
    float uShapeTransition;

//noise
    int uCurrentNoise;
    float uNoiseScale;
    float uNoiseHeight;
    int uTilePeriod;
    int uNoiseOctaves;
    int uNumMosOctaves;
    float _pad_afterNumMos;


//steps
    int uMaxSteps;
    int uMaxVolumeSteps;
    int uMaxShadowSteps;
    float uStepSize;
    float uShadowStepSize;


//scattering
    float uForwardScattering;
    float uBackwardScattering;
    float uPowderStrength;
    float sdfBlendRadius;

    bool uUseBlueNoise;
    bool uUseCubeMap;
    float _pad_useSkydome;

    float uTransmittanceThreshold;
    float uSDFHitThreshold;
    float uNoiseJitter;
    float uMaxRayDistance;
};



vec3 ambientColor;
#define WATER_MATERIAL_ID 2
#define PI 3.14159
#define EPSILON 0.0001
#define USE_BLUE_NOISE 1
#define NUM_LIGHTS 0
const float EXTINCTION_MULT = 1.0;
#define NUM_SCATTER_OCTAVES 4
#define INVALID_MATERIAL_ID int(-1)
#define NUM_MATERIALS 3
#endif