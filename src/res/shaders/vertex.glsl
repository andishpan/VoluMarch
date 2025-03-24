#version 330 core

// Input: full-screen quad vertex positions in NDC (x,y in [-1,1], z ignored)
layout(location = 0) in vec3 aPos;

// Uniforms for camera and screen parameters
uniform vec3 uCameraPosition;
uniform vec4 iMouse;        // (x, y, 0, 0) when pressed
uniform vec3 iResolution;   // (width, height, depth=1)
uniform mat4 uViewMatrix;

out vec3 vRayOrigin;      // Precomputed ray origin (with mouse offset)
out vec3 vRayDirection;   // Precomputed initial ray direction

void main() {


    // Adjust camera position using mouse Y (similar to your fragment shader)
    vec3 cameraPos = uCameraPosition;
    //cameraPos.y += (iMouse.y / iResolution.y) * 90.0;

    // Compute camera basis from the view matrix
    vec3 cameraForward = normalize(-vec3(uViewMatrix[2][0], uViewMatrix[2][1], uViewMatrix[2][2]));
    vec3 cameraRight   = normalize(vec3(uViewMatrix[0][0], uViewMatrix[0][1], uViewMatrix[0][2]));
    vec3 cameraUp      = normalize(vec3(uViewMatrix[1][0], uViewMatrix[1][1], uViewMatrix[1][2]));

    // Calculate aspect ratio and lens width (here, lensWidth equals the aspect ratio)
    float aspectRatio = iResolution.x / iResolution.y;
    float lensWidth = aspectRatio;

    // aPos.xy is already in NDC space [-1,1]. Use it directly to compute the ray direction.
    vRayDirection = normalize(cameraForward + aPos.x * cameraRight * lensWidth + aPos.y * cameraUp);
    vRayOrigin = cameraPos;

    // Output the vertex position as usual.
    gl_Position = vec4(aPos, 1.0);
}
