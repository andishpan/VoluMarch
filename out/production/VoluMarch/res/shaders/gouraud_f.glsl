#version 330

in vec3 color;
in vec2 fragUV;

uniform sampler2D textureSampler;

out vec4 finalColor;

void main() {

    vec3 textureColor = texture(textureSampler, fragUV).rgb;

    vec3 newColor = mix(textureColor, color, 0.5);

    finalColor = vec4(newColor, 1.0);
}
