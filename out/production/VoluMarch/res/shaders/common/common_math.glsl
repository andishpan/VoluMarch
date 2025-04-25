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
float BeerLambert(float sigma_a, float distanceT)
{
    return exp(-sigma_a * distanceT);
}

float HenyeyGreenstein(float cosTheta, float g)
{
    float g2 = g * g;
    return (1.0 - g2) /
    pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
}

float DualLobeHG(float cosT, float gFwd, float gBack, float mixF)
{
    return mix(HenyeyGreenstein(cosT, gBack),
    HenyeyGreenstein(cosT, gFwd),
    mixF);
}
float MultipleOctaveScattering(float density, float g)
{
    const int   OCTAVES = 4;
    const float atten   = 0.2;
    const float contrib = 0.4;
    const float eccAtt  = 0.1;
    const float BASE_CT = 0.3;

    float a = 1.0, b = 1.0, c = 1.0, lum = 0.0;
    for (int i = 0; i < OCTAVES; ++i)
    {
        float phase = HenyeyGreenstein(BASE_CT * c, g);
        float T     = exp(-density * EXTINCTION_MULT * a);
        lum += b * phase * T;

        a *= atten;
        b *= contrib;
        c *= (1.0 - eccAtt);
    }
    return lum;
}
float getLuminance(vec3 col)   { return dot(col, vec3(0.3,0.59,0.11)); }
bool  isColorTooDark(vec3 col) { return getLuminance(col) < 0.009;     }

vec3  mask(vec3 v, float t)    { return step(v, vec3(t)); }

vec3  LinearToSRGB(vec3 rgb)
{
    rgb = clamp(rgb, 0.0, 1.0);
    return mix(
    pow(rgb, vec3(1.0/2.4))*1.055 - 0.055,
    rgb * 12.92,
    mask(rgb, 0.0031308)
    );
}
vec2 sphericalUV(vec3 dir)
{
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

#ifndef GET_NOISE_DEFINED
float getNoise(vec3 p);
#endif

float fbm(vec3 x)
{
    float f = 2.0, s = 0.5, a = 0.0, b = 0.5;
    for (int i = 0; i < 4; ++i)
    {
        a += b * getNoise(x);
        b *= s;
        x  = f * rotationM * x;
    }
    return a;
}
float opSmoothUnion(float d1, float d2, float k)
{
    float h = clamp(0.5 + 0.5*(d2-d1)/k, 0.0, 1.0);
    return mix(d2, d1, h) - k*h*(1.0-h);
}

#endif
