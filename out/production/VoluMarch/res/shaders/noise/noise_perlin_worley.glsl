#ifndef GET_NOISE_DEFINED
#define GET_NOISE_DEFINED


float  TILE_PERIOD = float(uTilePeriod);


void tileCoord(in  vec3  p, out ivec3 pi, out vec3  pf)
{
    pi = ivec3( mod( floor(p), TILE_PERIOD ) );
    pf = fract( p );
}


/*vec3 random3(vec3 p) {
    return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)),
    dot(p, vec3(269.5, 183.3, 246.1)),
    dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
} */

vec3 random3Period(ivec3 ip)
{

    vec3 p = vec3(ip);
    return fract( sin(vec3(
    dot(p, vec3(127.1,311.7, 74.7)),
    dot(p, vec3(269.5,183.3,246.1)),
    dot(p, vec3(113.5,271.9,124.6))) )
    * 43758.5453 );
}

float perlinNoiseTile(vec3 p)
{
    ivec3 Pi;  vec3 Pf;
    tileCoord(p, Pi, Pf);

    vec3 u = Pf*Pf*(3.0-2.0*Pf);


    vec3 g000 = random3Period( Pi + ivec3(0,0,0) );
    vec3 g100 = random3Period( Pi + ivec3(1,0,0) );
    vec3 g010 = random3Period( Pi + ivec3(0,1,0) );
    vec3 g110 = random3Period( Pi + ivec3(1,1,0) );
    vec3 g001 = random3Period( Pi + ivec3(0,0,1) );
    vec3 g101 = random3Period( Pi + ivec3(1,0,1) );
    vec3 g011 = random3Period( Pi + ivec3(0,1,1) );
    vec3 g111 = random3Period( Pi + ivec3(1,1,1) );

    float n000 = dot(g000, Pf - vec3(0,0,0));
    float n100 = dot(g100, Pf - vec3(1,0,0));
    float n010 = dot(g010, Pf - vec3(0,1,0));
    float n110 = dot(g110, Pf - vec3(1,1,0));
    float n001 = dot(g001, Pf - vec3(0,0,1));
    float n101 = dot(g101, Pf - vec3(1,0,1));
    float n011 = dot(g011, Pf - vec3(0,1,1));
    float n111 = dot(g111, Pf - vec3(1,1,1));

    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);

    return mix(nxy0, nxy1, u.z);
}

float worleyNoiseTile(vec3 p)
{
    ivec3 Pi;  vec3 Pf;
    tileCoord(p, Pi, Pf);

    float nearest = 1.0;
    float second  = 1.0;

    for (int z = -1; z <= 1; ++z)
    for (int y = -1; y <= 1; ++y)
    for (int x = -1; x <= 1; ++x)
    {
        ivec3  cell    = Pi + ivec3(x,y,z);
        cell           = ivec3( mod(cell, uTilePeriod) );

        vec3   jitter  = random3Period(cell);
        vec3   diff    = vec3(x,y,z) + jitter - Pf;


        diff = diff - round(diff / TILE_PERIOD) * TILE_PERIOD;

        float d = length(diff);

        if (d < nearest)      { second = nearest; nearest = d; }
        else if (d < second)  { second = d; }
    }
    return nearest;
}


float perlinWorleyNoiseTile(vec3 p)
{
    float perlin = 0.5 * perlinNoiseTile(p) + 0.5;
    float worley = worleyNoiseTile(p * 1.5);
    return perlin * (1.0 - worley);
}


/*float perlinNoise(vec3 p) {
    vec3 pi = floor(p);
    vec3 pf = fract(p);


    vec3 u = pf * pf * (3.0 - 2.0 * pf);


    vec3 g000 = random3(pi + vec3(0.0, 0.0, 0.0));
    vec3 g100 = random3(pi + vec3(1.0, 0.0, 0.0));
    vec3 g010 = random3(pi + vec3(0.0, 1.0, 0.0));
    vec3 g110 = random3(pi + vec3(1.0, 1.0, 0.0));
    vec3 g001 = random3(pi + vec3(0.0, 0.0, 1.0));
    vec3 g101 = random3(pi + vec3(1.0, 0.0, 1.0));
    vec3 g011 = random3(pi + vec3(0.0, 1.0, 1.0));
    vec3 g111 = random3(pi + vec3(1.0, 1.0, 1.0));


    float n000 = dot(g000, pf - vec3(0.0, 0.0, 0.0));
    float n100 = dot(g100, pf - vec3(1.0, 0.0, 0.0));
    float n010 = dot(g010, pf - vec3(0.0, 1.0, 0.0));
    float n110 = dot(g110, pf - vec3(1.0, 1.0, 0.0));
    float n001 = dot(g001, pf - vec3(0.0, 0.0, 1.0));
    float n101 = dot(g101, pf - vec3(1.0, 0.0, 1.0));
    float n011 = dot(g011, pf - vec3(0.0, 1.0, 1.0));
    float n111 = dot(g111, pf - vec3(1.0, 1.0, 1.0));


    float nx00 = mix(n000, n100, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    float nxyz = mix(nxy0, nxy1, u.z);

    return nxyz;
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


float perlinWorleyNoise(vec3 p) {

    float perlin = perlinNoise(p);
    float worley = worleyNoise(p * 1.5);


    perlin = 0.5 * perlin + 0.5;


    return perlin * (1.0 - worley);
}  */

float getNoise(vec3 p){

    return perlinWorleyNoiseTile(p);
}

#endif
