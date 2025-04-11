#version 330 core


layout(location = 0) in vec3 aPos;


uniform vec3 uCameraPosition;

uniform vec3 uResolution;
uniform vec3 uCameraUp;
uniform vec3 uCameraLookAt;


out vec3 vRayOrigin;
out vec3 vRayDirection;

void main() {


    //vec3 cameraPos = uCameraPosition + vec3(0.0, 50.0, 0.0);

    //cameraPos.y += (iMouse.y / uResolution.y) * 90.0;
    //cameraPos.y += 50.0;

    vec3 cameraRight   = normalize(vec3(1.0, 0.0, 0.0));
    
    float aspectRatio = uResolution.x / uResolution.y;
    float lensWidth = aspectRatio;

    vRayDirection = normalize(uCameraLookAt + aPos.x * cameraRight * lensWidth + aPos.y * uCameraUp);
    vRayOrigin = uCameraPosition;


    gl_Position = vec4(aPos, 1.0);
}
