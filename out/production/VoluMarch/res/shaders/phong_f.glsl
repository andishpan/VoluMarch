#version 330
in vec4 vertexPosition;
in vec3 color;
in vec3 normals; // N
in vec2 uvs;
out vec3 finalColor;

uniform sampler2D samp;
uniform vec3 lightsource;
uniform vec3 viewPos;
uniform vec3 lightColor;


void main() {

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float shininess = 32.0f;
    vec3 specularColor = vec3(1.0f, 1.0f, 1.0f);


    float ambientStrength = 0.1f;
    ambient = ambientStrength * lightColor;

    //vec3 norm = normalize(normals);
    vec3 light = normalize(lightsource - vertexPosition.xyz);
    float diff = max(dot(normals, light), 0.0);
    diffuse = diff * lightColor;


    float specularStrength = 1.5f;
    vec3 view = normalize( -vertexPosition.xyz);
    vec3 reflected = reflect(-light, normals);
    float spec = pow(max(dot(view, reflected), 0.0), shininess);
    specular = specularStrength * spec * lightColor;


    vec3 textureColor = vec3(texture(samp, uvs));
    vec3 result = ( ambient + diffuse + specular) * color  * textureColor;
    finalColor = result;
}
