#ifndef RENDER_SETTINGS_GLSL
#define RENDER_SETTINGS_GLSL
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
uniform float uVolumetricScattering;
uniform float uPhaseG;

//shape
uniform int uObjectShape;
uniform int uPrevShape;
uniform float uShapeTransition;

//noise
uniform int uCurrentNoise;
uniform float uNoiseScale;
uniform float uNoiseHeight;
uniform int uTilePeriod;


//steps
uniform int uMaxSteps;
uniform int uMaxVolumeSteps;
uniform int uMaxShadowMarchSteps;
uniform int uMaxLightMarchSteps;
uniform float uStepSize;
uniform float uShadowStepSize;

uniform samplerCube uEnvironmentMap;

//scattering
uniform float uForwardScattering;
uniform float uBackwardScattering;
uniform float uPowderStrength;
uniform float uBlendFactor;

#define WATER_MATERIAL_ID 2
#define PI 3.14159
#define EPSILON 0.0001
#define USE_BLUE_NOISE 0
#define NUM_LIGHTS 0

const float EXTINCTION_MULT = 1.0;

#define MIN_OPACITY 0.05 // 0.01, 0.002
#define NOISE_JITTER 0.02
#define SCENE_MAX_T 900.0
#define NUM_SCATTER_OCTAVES 4
#define SURFACE_DIST 0.03
#define INVALID_MATERIAL_ID int(-1)
#define NUM_MATERIALS 3

#endif