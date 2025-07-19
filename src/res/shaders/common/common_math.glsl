#ifndef COMMON_MATH_GLSL
#define COMMON_MATH_GLSL
#ifndef PI
#define PI 3.14159265359
#endif
#ifndef EXTINCTION_MULT
#define EXTINCTION_MULT 1.0
#endif
#ifndef MIN_OPACITY
#define MIN_OPACITY 0.05
#endif


const float INV_FOUR_PI = 0.07957747154594767;

float BeerLambert(float sigmaT, float distanceT){

    return exp(-sigmaT * distanceT);
}


float powder(float d){

    return 1.0 - exp(-uPowderStrength * d);
}



float HenyeyGreenstein(float cosTheta, float g){

    float g2 = g * g;
    float denom = pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
    return (1.0 - g2) * INV_FOUR_PI / denom;
}

float HenyeyGreensteinNormal(float cosTheta, float g)
{
    float g2 = g * g;
    float denom = pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
    return (1.0 - g2) * PI / denom;
}


float getLuminance(vec3 col)   { return dot(col, vec3(0.3,0.59,0.11)); }


vec3  mask(vec3 v, float closestT)    { return step(v, vec3(closestT)); }

vec3  LinearToSRGB(vec3 rgb){

    rgb = clamp(rgb, 0.0, 1.0);
    return mix(
    pow(rgb, vec3(1.0/2.4))*1.055 - 0.055,
    rgb * 12.92,
    mask(rgb, 0.0031308)
    );
}
vec2 sphericalUV(vec3 dir){

    dir = normalize(dir);
    float u = 0.5 + atan(dir.z, dir.x) / (2.0*PI);
    float v = 0.5 - asin(dir.y)       /  PI;
    return fract(vec2(u,v));
}
const mat3 rotationM = mat3(
0.00,  0.80,  0.60,
-0.80,  0.36, -0.48,
-0.60, -0.48,  0.64
);



#ifndef GET_GRD
float getNoise(vec3 p);
#endif

/*float fbm(vec3 x){

    float f = 2.0, s = 0.5, a = 0.0, b = 0.5;
    for (int i = 0; i < 4; ++i)
    {
        a += b * getNoise(x);
        b *= s;
        x  = f * rotationM * x;
    }
    return a;
} */


float fbm(vec3 p)
{
    float a = 0.5;
    float f = 0.0;
    for(int i = 0; i < uNoiseOctaves; ++i)
    {
        f += getNoise(p) * a;
        p *= 2.02;
        a *= 0.55;
    }
    return f;
}





float fbmBillow(vec3 p) {
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < uNoiseOctaves; i++) {
        float n = getNoise(p * freq) * 2.0 - 1.0;
        sum += amp * (1.0 - abs(n));
        freq *= 2.0;
        amp  *= 0.5;
    }
    return sum;
}



float opSmoothUnion(float d1, float d2, float k){

    float h = clamp(0.5 + 0.5*(d2-d1)/k, 0.0, 1.0);
    return mix(d2, d1, h) - k*h*(1.0-h);
}





#endif
