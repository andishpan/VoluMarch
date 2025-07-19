#version 430 core
#extension GL_ARB_shader_atomic_counters : require

#ifndef RENDER_SETTINGS_GLSL
#include "common/render_settings.glsl"
#endif
#ifndef COMMON_MATH_GLSL
#include "common/common_math.glsl"
#endif
#ifndef COMMON_SDF_GLSL
#include "common/common_sdf.glsl"
#endif


#ifndef GET_NOISE_DEFINED
float getNoise(vec3 p);
#endif



#ifndef RAYMARCH_DECL
vec3 raymarch(vec3 rayOrigin, vec3 rayDirection, out vec3 outvolumeColor);
#define RAYMARCH_DECL
#endif




in vec3 vRayOrigin;
in vec3 vRayDirection;

void main() {
    vec3 volumeColor = vec3(0.0);

    vec3 color = raymarch(vRayOrigin, vRayDirection, volumeColor);

    if (uUseBlueNoise){
        if (getLuminance(volumeColor) > 0.01) {
            float layer = fract(uTime) * float(64);
            vec3 uvw  = vec3(gl_FragCoord.xy / uResolution.xy, layer);
            float noiseVal = texture(uBlueNoise, uvw).r;

            color += (noiseVal - 0.5) * uNoiseJitter;
            //color = vec3(1.0,1.0,1.0);
        }

    }



    color = LinearToSRGB(color);
    fragColor = vec4(color, 1.0);


}


