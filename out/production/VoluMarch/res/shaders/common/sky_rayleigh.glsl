#ifndef SKY_RAYLEIGH_GLSL
#define SKY_RAYLEIGH_GLSL


float getGlow(float dist, float radius, float intensity){
    dist = max(dist, 1e-6);
    return pow(radius/dist, intensity);
}

vec3 getRayleighSky(vec3 rayO, vec3 rayD)
{

    float mu = dot(rayD, normalize(uSunDirection));
    float phase  = 3.0 * (1.0 + mu * mu) / (16.0 *  3.14159265359);

    float tau = exp(-max(rayO.y, 0.0) / 40.0);


    return 3.0 * (vec3(5.802e-3f, 13.558e-3f, 33.100e-3f) * 100) * phase * tau;
    //return vec3(0.0,0.0,0.0);ja
    //return vec3(0.53, 0.81, 0.92);
    //return vec3(0.10, 0.15, 0.35);
    //return vec3(0.0,0.0,0.0);
}





#endif
