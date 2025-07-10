#ifndef COMMON_MATH_GLSL
#define COMMON_MATH_GLSL
#ifndef PI
#define PI 3.14159265359
#endif
#ifndef EXTINCTION_MULT
#define EXTINCTION_MULT 1.0
#endif



const float INV_FOUR_PI = 0.07957747154594767;

float BeerLambert(float sigmaT, float distanceT){

    return exp(-sigmaT * distanceT);
}

//powder
/*float Powder(float sigma_t, float distanceT) {

  return exp(-sigma_t * distanceT) * (1.0 - exp(-sigma_t * distanceT * 2.0));
} */
/*float Powder(float sigma_t, float distanceT) {
  float T1 = exp(-sigma_t * distanceT);
  float T2 = exp(-sigma_t * distanceT * 2.0);
  return T1 * (1.0 - T2);
} */

float powder(float d)
{
    return 1.0 - exp(-uPowderStrength * d);
}

// 1 - exp(-d * 2)
/*float Powder(float sigma_t, float distanceT, float k){

  return 1.0 - exp(-sigma_t * distanceT * k);
} */
float LinearExtinction(float k, float distanceT)
{
    return max(1.0 - k * distanceT, 0.0);
}

float SchlickExtinction(float k, float distanceT)
{
    return 1.0 / (1.0 + k * distanceT);
}

/*float HenyeyGreenstein(float cosTheta, float g){


  float g2 = g * g;
  return (1.0 - g2) /
  pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
} */

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

float DualLobeHG(float cosT, float gFwd, float gBack, float mixF){

    return mix(HenyeyGreenstein(cosT, gBack),
    HenyeyGreenstein(cosT, gFwd),
    mixF);
}


float RayleighPhase(float cosTheta) {
    return (3.0 / (16.0 * PI)) * (1.0 + cosTheta * cosTheta);
}

float MiePhase(float cosTheta, float g) {
    float g2 = g * g;
    return (3.0 * (1.0 - g2)) / (8.0 * PI * (2.0 + g2)) * (1.0 + cosTheta * cosTheta) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5);
}

float MultipleOctaveScattering(float density, float g, float marchSize){

    const int OCTAVES = 5;
    const float atten = 0.4;
    const float contrib = 0.6;
    const float eccAtt  = 0.2;
    const float BASE_CT = 0.9;

    float a = 1.0, b = 1.0, c = 1.0, lum = 0.0;
    for (int i = 0; i < NUM_SCATTER_OCTAVES; ++i)
    {
        float phase = HenyeyGreenstein(BASE_CT * c, g);
        float T = BeerLambert(uVolumetricAbsorption, marchSize);
        lum += b * phase * max(0.2, T);


        a *= atten;
        b *= contrib;
        c *= (1.0 - eccAtt);
    }
    return lum;
}
float getLuminance(vec3 col) { return dot(col, vec3(0.3, 0.59, 0.11)); }
bool  isColorTooDark(vec3 col) { return getLuminance(col) < 0.009; }

vec3  mask(vec3 v, float closestT)  { return step(v, vec3(closestT)); }

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
    float v = 0.5 - asin(dir.y) /  PI;
    return fract(vec2(u, v));
}
const mat3 rotationM = mat3(
0.00, 0.80, 0.60,
-0.80, 0.36, -0.48,
-0.60, -0.48, 0.64
);

vec3 wrapp(in vec3 p)// world → tile space
{
    // GLSL’s mod() gives the right sign for positives only,
    // so shift into positive range first, then wrap.
    return mod(p, 64.0);
}

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


/*float fbm(vec3 p)
{
    float a = 0.5;
    float f = 0.0;
    for (int i = 0; i < uNoiseOctaves; ++i)
    {
        f += abs(getNoise(p)) * a;
        p *= 2.02;
        a *= 0.55;
    }
    return f;
} */

float fbm(vec3 p)
{

    return getNoise(p);
}
/*float fbm01(vec3 p){
  return fbm(p) / 1.1;
} */
float getBillow(vec3 p) {
    // getCombinedNoise returns in roughly [–1…1]
    float n = getNoise(p);
    return 1.0 - abs(n);
}


float fbmBillow(vec3 p) {
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < uNoiseOctaves; i++) {
        // sample, bias to –1…1 then billow
        float n = getNoise(p * freq) * 2.0 - 1.0;
        sum += amp * (1.0 - abs(n));
        freq *= 2.0;
        amp  *= 0.5;
    }
    return sum;
}


/*float fbm(vec3 p) {
  float f = 1.0;
  float a = 0.5;
  float sum = 0.0;

  for (int i = 0; i < uNoiseOctaves; ++i) {

  sum += a * abs(getNoise(p));

  f *= 2.0;
  a *= 0.5;
  }

  return sum;
} */







float opSmoothUnion(float d1, float d2, float k){

    float h = clamp(0.5 + 0.5*(d2-d1)/k, 0.0, 1.0);
    return mix(d2, d1, h) - k*h*(1.0-h);
}





#endif
