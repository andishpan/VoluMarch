#version 330
layout(location = 0) in vec3 vertices;
layout(location = 1) in vec3 colordata;
layout(location = 2) in vec3 normalsData;
layout(location = 3) in vec2 uvKoordinates;
uniform mat4 transformationMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;
out vec3 color;
out vec4 vertexPosition;
out vec3 normals;
out vec2 uvs;

void main() {
    uvs = uvKoordinates;
    color = colordata;
    vertexPosition =  viewMatrix  * transformationMatrix * vec4(vertices, 1.0);
    gl_Position =   projectionMatrix * vertexPosition;
    mat3 normalMatrix = inverse(transpose(mat3(modelMatrix)));
    normals = normalize(normalMatrix * normalsData);
}




