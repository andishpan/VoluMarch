#version 330 core
in vec2 TexCoords;
out vec4 FragColor;

uniform sampler2D textTexture;
uniform vec3 textColor;

void main()
{
    vec4 sampled = texture(textTexture, TexCoords);
    // Multiply the sampled alpha with the desired text color
    FragColor = vec4(textColor, 1.0) * sampled;
}
