#version 330 core
/*===========================================================================*/
/*  F R A G M E N T   S H A D E R                                            */
/*===========================================================================*/

/* ------------------------------------------------------------------------- */
/*  colour & counter outputs                                                 */
/* ------------------------------------------------------------------------- */
layout(location = 0) out vec4  fragColor;   // final LDR/HDR RGB + α
layout(location = 1) out uvec4 fragSteps;   // primary | shadow | sdf | bounce
layout(location = 2) out float fragCloudMask;


/* ------------------------------------------------------------------------- */
/*  common include blocks                                                    */
/* ------------------------------------------------------------------------- */
#ifndef RENDER_SETTINGS_GLSL
#include "common/render_settings.glsl"
#endif
#ifndef COMMON_MATH_GLSL
#include "common/common_math.glsl"
#endif
#ifndef COMMON_SDF_GLSL
#include "common/common_sdf.glsl"
#endif
#ifndef COMMON_VOLUME_GLSL
#include "common/common_volume.glsl"
#endif

/* ------------------------------------------------------------------------- */
/*  forward declaration of raymarch                                          */
/*  (parameter names don’t have to match; types/order MUST)                  */
/* ------------------------------------------------------------------------- */
#ifndef RAYMARCH_DECL
vec3 raymarch
(
vec3  rayOrigin,          vec3  rayDir,
out   vec3  outVolColor,out float outTransmittance,
out   int   outPrimary,   out   int outShadow,
out   int   outSdf,       out   int outBounce
);
#define RAYMARCH_DECL
#endif

/* ------------------------------------------------------------------------- */
/*  varyings                                                                 */
/* ------------------------------------------------------------------------- */
in vec3 vRayOrigin;
in vec3 vRayDirection;

/* ------------------------------------------------------------------------- */
/*  main                                                                     */
/* ------------------------------------------------------------------------- */
void main()
{
    /* counters returned from raymarch() ---------------------------------- */
    vec3 volumeColor;
    float transmittance;
    int  primarySteps, shadowSteps, sdfSteps, bounceSteps;

    /* integrate the volume ---------------------------------------------- */
    vec3 hdrColor = raymarch(vRayOrigin, vRayDirection,
    volumeColor,transmittance,
    primarySteps, shadowSteps,
    sdfSteps,     bounceSteps);

    float extinction = 1.0 - clamp(transmittance, 0.0, 1.0);
    fragCloudMask = extinction > 0.01 ? 1.0 : 0.0;  // binary mask


    /* optional dithering ------------------------------------------------- */
    #if USE_BLUE_NOISE
    if (getLuminance(volumeColor) > 0.01)
    {
        float noiseVal = texture(iChannel0,
        gl_FragCoord.xy / uResolution.xy).r;
        hdrColor += (noiseVal - 0.5) * NOISE_JITTER;
    }
    #endif

    /* encode and store --------------------------------------------------- */
    fragColor  = vec4(LinearToSRGB(hdrColor), 1.0);
    fragSteps  = uvec4(primarySteps,
    shadowSteps,
    sdfSteps,
    bounceSteps);     // <— *real* bounce counter
}
