#version 330 core


layout(location = 0) in vec3 aPos;


uniform vec3 uCameraPosition;
uniform vec4 iMouse;
uniform vec3 iResolution;
uniform mat4 uViewMatrix;


out vec2 vUV;
out vec3 vRayOrigin;
out vec3 vRayDirection;

void main() {
    
    vUV = aPos.xy * 0.5 + 0.5;

    
    vec3 cameraPos = uCameraPosition;
    cameraPos.y += (iMouse.y / iResolution.y) * 90.0;

    
    vec3 cameraForward = normalize(-vec3(uViewMatrix[2][0], uViewMatrix[2][1], uViewMatrix[2][2]));
    vec3 cameraRight   = normalize( vec3(uViewMatrix[0][0], uViewMatrix[0][1], uViewMatrix[0][2]));
    vec3 cameraUp      = normalize( vec3(uViewMatrix[1][0], uViewMatrix[1][1], uViewMatrix[1][2]));

    
    float aspectRatio = iResolution.x / iResolution.y;
    float lensWidth = aspectRatio;

    
    vRayDirection = normalize(
        cameraForward
        + aPos.x * cameraRight * lensWidth
        + aPos.y * cameraUp
    );

    
    vRayOrigin = cameraPos;

    
    gl_Position = vec4(aPos, 1.0);
}
