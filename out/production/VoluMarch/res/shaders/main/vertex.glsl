#version 430 core
#include "common/render_settings.glsl"
layout(location = 0) in vec3 aPos;

/*uniform vec3 uCameraPosition;
uniform vec3 uCameraLookAt;
uniform vec3 uCameraUp;
uniform vec3 uResolution; */

out vec3 vRayOrigin;
out vec3 vRayDirection;

void main() {
    // screen-space quad coordinates (aPos in [-1, 1])
    vec2 uv = aPos.xy;

    // camera basis vectors
    vec3 forward = normalize(uCameraLookAt - uCameraPosition);
    vec3 right = normalize(cross(forward, uCameraUp));
    vec3 up  = cross(right, forward);

    float aspectRatio = uResolution.x / uResolution.y;
    float fov = radians(45.0);// horizontal FOV in radians
    float scale = tan(fov * 0.5);

    // convert screen position to camera space ray direction
    vec3 rayDir = normalize(forward +
    uv.x * aspectRatio * scale * right +
    uv.y * scale * up);

    vRayOrigin  = uCameraPosition;
    vRayDirection = rayDir;

    gl_Position = vec4(aPos, 1.0);
}
