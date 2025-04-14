#ifndef GET_NOISE_DEFINED
#define GET_NOISE_DEFINED


vec3 random3(vec3 p) {
    return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}

float worleyNoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    float nearest = 1.0;
    float secondNearest = 1.0;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 point = random3(i + neighbor);
                float d = length(neighbor + point - f);

                if (d < nearest) {
                    secondNearest = nearest;
                    nearest = d;
                } else if (d < secondNearest) {
                    secondNearest = d;
                }
            }
        }
    }

    return nearest;
}

float getNoise(vec3 p) {
    return worleyNoise(p);
}
#endif
