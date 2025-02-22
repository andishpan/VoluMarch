
#version 330
layout(location = 0) in vec3 vertices;
layout(location = 1) in vec3 colordata;
layout(location = 2) in vec3 normalsData;
layout(location = 3) in vec2 uvKoordinates;

uniform mat4 transformationMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat4 projectionMatrix;
uniform vec3 lightPos;
uniform vec3 viewPos;
uniform vec3 lightColor;

out vec3 color;
out vec2 fragUV;

void main() {

    vec4 vertexPos = viewMatrix * transformationMatrix * vec4(vertices, 1.0);
    gl_Position = projectionMatrix *  vertexPos;
    mat3 normalMatrix = inverse(transpose(mat3(transformationMatrix)));
    vec3 normal = normalize(normalMatrix * normalsData);

    vec3 light = normalize(lightPos - vertexPos.xyz);
    vec3 view = normalize( -vertexPos.xyz);
    vec3 reflected = reflect(-light, normal);

    float spec = pow(max(dot(view, reflected), 0.0), 32.0);
    float diff = max(dot(normal, light), 0.0);
    vec3 ambient = 0.1 * lightColor;

    vec3 result = (ambient + diff + spec) * lightColor * colordata;

    fragUV = uvKoordinates;
    color = result;
}






