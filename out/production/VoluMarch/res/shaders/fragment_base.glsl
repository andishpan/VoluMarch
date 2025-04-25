#version 330 core


out vec4 fragColor;




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

#ifndef GET_NOISE_DEFINED
float getNoise(vec3 p);
#endif



 #ifndef RAYMARCH_DECL
 vec3 raymarch(vec3 rayOrigin, vec3 rayDir, out vec3 outVColor);
 #define RAYMARCH_DECL
 #endif




in vec3 vRayOrigin;
in vec3 vRayDirection;

void main() {
    vec3 vColor = vec3(0.0);
    vec3 color = raymarch(vRayOrigin, vRayDirection, vColor);

    #if USE_BLUE_NOISE
    if (getLuminance(vColor) > 0.01) {
        float noiseVal = texture(iChannel0, gl_FragCoord.xy / uResolution.xy).r;
        color += (noiseVal - 0.5) * NOISE_JITTER;
    }
    #endif

    color = LinearToSRGB(color);
    fragColor = vec4(color, 1.0);
}


