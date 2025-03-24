#version 330 core

#ifdef GL_ES
precision mediump float;
#endif

uniform vec3  iResolution;  // (width, height, 1)
uniform float iTime;        // Time in seconds
uniform vec4  iMouse;       // Not used here

out vec4 fragColor;

//------------------------------------
// 1) Utility & Camera Setup
//------------------------------------
float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

// Creates a rotation matrix to "look at" a target
mat3 lookAt(vec3 fw, vec3 up) {
    fw = normalize(fw);
    vec3 rt = normalize(cross(up, fw));
    vec3 tp = cross(fw, rt);
    return mat3(rt, tp, fw);
}

//------------------------------------
// 2) 3D Noise (fBm)
//------------------------------------
float hash13(vec3 p) {
    p = fract(p * 0.3183099);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    float n000 = hash13(i + vec3(0,0,0));
    float n100 = hash13(i + vec3(1,0,0));
    float n010 = hash13(i + vec3(0,1,0));
    float n110 = hash13(i + vec3(1,1,0));
    float n001 = hash13(i + vec3(0,0,1));
    float n101 = hash13(i + vec3(1,0,1));
    float n011 = hash13(i + vec3(0,1,1));
    float n111 = hash13(i + vec3(1,1,1));

    vec3 u = f*f*(3.0 - 2.0*f);

    float nx00 = mix(n000, n100, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx11 = mix(n011, n111, u.x);
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    return mix(nxy0, nxy1, u.z);
}

float fbm3D(vec3 p) {
    float value = 0.0;
    float amp   = 0.5;
    for(int i=0; i<5; i++){
        value += amp * noise3D(p);
        p *= 2.01;
        amp *= 0.5;
    }
    return value;
}

//------------------------------------
// 2b) Domain Shift Function
//------------------------------------
// Enhanced animation with multiple time-based movements
vec3 domainShift(vec3 pos)
{
    // Base scale for the cloud
    float baseScale = 0.1;

    // Create a gentle floating motion
    float floatY = 0.05 * sin(iTime * 0.1);  // Vertical floating
    float floatX = 0.03 * sin(iTime * 0.10); // Slight horizontal drift
    float floatZ = 0.03 * cos(iTime * 0.10); // Slight forward/back drift

    // Add a subtle rotation effect
    float angle = iTime * 0.1;
    mat2 rot = mat2(cos(angle), -sin(angle),
    sin(angle), cos(angle));

    // Apply rotation to xz plane
    vec2 rotatedXZ = rot * pos.xz;

    // Combine all movements
    vec3 shiftedPos = vec3(rotatedXZ.x, pos.y, rotatedXZ.y);
    shiftedPos += vec3(floatX, floatY, floatZ);

    // Apply the base scale
    return shiftedPos * baseScale;
}

//------------------------------------
// 3) Multi-Octave Scattering
//------------------------------------
vec3 multiScatter(vec3 pos, vec3 lightDir, float density) {
    // Base scattering parameters
    float scatterStrength = 0.3;  // Controls overall scattering intensity
    float phaseG = 0.2;           // Controls forward/backward scattering bias

    // Calculate phase function (Henyey-Greenstein)
    float cosTheta = dot(normalize(pos), lightDir);
    float phase = (1.0 - phaseG * phaseG) / (4.0 * 3.14159 * pow(1.0 + phaseG * phaseG - 2.0 * phaseG * cosTheta, 1.5));

    // Multiple scattering approximation
    vec3 scatterColor = vec3(0.0);
    float totalDensity = 0.0;

    // First order scattering (direct)
    float directScatter = density * scatterStrength * phase;
    scatterColor += vec3(directScatter);
    totalDensity += directScatter;

    // Second order scattering (indirect)
    float indirectScatter = density * density * scatterStrength * 0.5 * phase;
    scatterColor += vec3(indirectScatter);
    totalDensity += indirectScatter;

    // Third order scattering (ambient)
    float ambientScatter = density * density * density * scatterStrength * 0.25 * phase;
    scatterColor += vec3(ambientScatter);
    totalDensity += ambientScatter;

    // Normalize and return
    return scatterColor / (totalDensity + 0.0001);
}

//------------------------------------
// 4) Beer-Lambert Shadow Function
//------------------------------------
float computeLightAttenuation(vec3 startPos, vec3 lightDir)
{
    float distMax   = 20.0;
    float stepSize  = 0.5;
    float t         = 0.0;

    float integratedDensity = 0.0;

    for(int i=0; i<40; i++) {
        if(t > distMax) break;
        vec3 pos = startPos + t*lightDir;

        // Check if inside [0..10] in y
        if(pos.y >= 0.0 && pos.y <= 10.0)
        {
            // Use the same domain shift so it matches the main ray logic
            float n = fbm3D(domainShift(pos));
            float density = smoothstep(0.3, 0.6, n);
            integratedDensity += density * stepSize;
        }
        t += stepSize;
    }

    // Beer-Lambert with adjusted coefficients for multi-scatter
    float absorptionCoeff = 0.5;
    float scatterCoeff = 0.3;
    float atten = exp(-(absorptionCoeff + scatterCoeff) * integratedDensity);
    return atten;
}

//------------------------------------
// 4) Scene & Ray March
//------------------------------------
vec3 rayDirection(vec2 uv, float fovDegrees) {
    vec2 xy = uv*2.0 - 1.0;
    xy.x *= iResolution.x / iResolution.y;
    float z = 1.0 / tan(radians(fovDegrees)*0.5);
    return normalize(vec3(xy, -z));
}

bool inCloudRegion(vec3 pos) {
    return (pos.y>=0.0 && pos.y<=10.0);
}

vec3 renderClouds(vec3 ro, vec3 rd)
{
    float tMax = 100.0;
    float dt   = 0.1;
    float t    = 0.0;

    vec3 sumColor = vec3(0.0);
    float transmittance = 1.0;

    // Single directional light with slight movement
    vec3 lightDir = normalize(vec3(0.3 + 0.1 * sin(iTime * 0.1), 1.0, 0.3 + 0.1 * cos(iTime * 0.1)));

    for(int i=0; i<512; i++){
        if(t>tMax || transmittance<0.01) break;

        vec3 pos = ro + t*rd;

        if(inCloudRegion(pos)) {
            // Use our enhanced domain shift for animated clouds
            float n = fbm3D(domainShift(pos));
            float density = smoothstep(0.3, 0.6, n);

            if(density>0.0){
                // Calculate multi-scatter contribution
                vec3 scatterColor = multiScatter(pos, lightDir, density);

                // Combine direct and scattered light
                float nl = dot(normalize(pos), lightDir);
                float directLight = 0.7 + 0.3*saturate(nl);

                float lightAtten = computeLightAttenuation(pos, lightDir);
                directLight *= lightAtten;

                // Combine direct and scattered light
                vec3 cloudColor = vec3(1.0);
                vec3 finalColor = mix(cloudColor, scatterColor, 0.3);

                float alpha = 1.0 - exp(-density*0.3*dt);

                vec3 contrib = transmittance * finalColor * (directLight + 0.2) * alpha;
                sumColor += contrib;

                transmittance *= (1.0 - alpha);
            }
        }
        t += dt;
    }

    // Brighter sky background
    vec3 skyColor = vec3(0.7, 0.85, 1.0);
    return sumColor + transmittance*skyColor;
}

//------------------------------------
// 5) Main
//------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // Camera
    vec3 cameraPos = vec3(0.0, 2.0, 15.0);
    vec3 target    = vec3(0.0, 2.0, 0.0);
    vec3 up        = vec3(0.0, 1.0, 0.0);

    // Build local frame
    vec3 fw = (target - cameraPos);
    mat3 camMat = lookAt(fw, up);

    float fov = 60.0;
    vec3 rd0 = rayDirection(uv, fov);
    vec3 rd  = normalize(camMat * rd0);

    vec3 color = renderClouds(cameraPos, rd);

    // Gamma
    color = pow(color, vec3(0.4545));

    fragColor = vec4(color, 1.0);
}

// Standard entry point
void main()
{
    mainImage(fragColor, gl_FragCoord.xy);
}