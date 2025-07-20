float marchShadow(vec3 p, vec3 lightDir){

    uint localShadow = 0u;
    float t = uShadowStepSize;
    float transmittance = 1.0;
    float nearestHitT = uMaxRayDistance;
    for (int s = 0; s < uMaxShadowSteps; ++s){
        localShadow++;
        if (t > uMaxRayDistance) break;

        vec3 sp = p + lightDir * t;
        float sdf  = getVolume(sp);
        if (sdf > 0.0)
        {
            t += max(sdf, uShadowStepSize);
            continue;
        }
        float density = getDensity(sp, sdf);

        float sigmaA  = uVolumetricAbsorption  * density;
        float sigmaS  = uVolumetricScattering * density;
        float sigmaT  = sigmaA + sigmaS;

        float stepTr  = exp(-sigmaT * uShadowStepSize);
        transmittance *= stepTr;
        if (transmittance < uTransmittanceThreshold) break;

        t += uShadowStepSize;
    }

    atomicAdd(shadow, localShadow);
    return transmittance;

}





void getShapeAABB(int shapeId, out vec3 boxMin, out vec3 boxMax) {
    if (shapeId == 0) {
        float r = 8.0;
        float blend = sdfBlendRadius;
        vec3 c = vec3(0.0, 20.0, -25.0);

        float ext = r + blend;
        boxMin = c + vec3(-8.0 - ext, -ext, -ext);
        boxMax = c + vec3(8.0 + ext, ext, ext);
    }
    else if (shapeId == 1) {
        float r = 8.0;
        vec3 c = vec3(0.0, 20.0, -25.0);
        boxMin = c - vec3(r);
        boxMax = c + vec3(r);
    }
    else if (shapeId == 2) {
        float R = 12.0;
        float r = 5.0;
        vec3 c = vec3(0.0, 20.0, -25.0);
        float torusExtent = R + r;
        boxMin = c - vec3(torusExtent);
        boxMax = c + vec3(torusExtent);
    }
    else {
        boxMin = vec3(-1000.0);
        boxMax = vec3(1000.0);
    }
}
float rayAABBExitDistance(vec3 rayOrigin, vec3 rayDir, vec3 boxMin, vec3 boxMax) {
    vec3 invDir = 1.0 / rayDir;

    vec3 tMin = (boxMin - rayOrigin) * invDir;
    vec3 tMax = (boxMax - rayOrigin) * invDir;

    vec3 t1 = min(tMin, tMax);
    vec3 t2 = max(tMin, tMax);

    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar  = min(min(t2.x, t2.y), t2.z);

    if (tFar < 0.0 || tNear > tFar) {
        return 0.0;
    }

    return tFar - max(tNear, 0.0);
}




float marchShadowAABB(vec3 p, vec3 lightDir) {
    uint localShadow = 0u;
    float t = uShadowStepSize;
    float transmittance = 1.0;
    vec3 boxMin, boxMax;
    getShapeAABB(uObjectShape, boxMin, boxMax);
    float maxT = rayAABBExitDistance(p, lightDir, boxMin, boxMax);
    if (maxT == 0.0) return 1.0;

    for (int s = 0; s < uMaxShadowSteps; ++s) {
        localShadow++;
        if (t > maxT) break;

        vec3 sp = p + lightDir * t;
        float sdf = getVolume(sp);

        if (sdf > 0.0) {
            t += max(sdf, uShadowStepSize);
            continue;
        }

        float density = getDensity(sp, sdf);
        float sigmaA = uVolumetricAbsorption * density;
        float sigmaS = uVolumetricScattering * density;
        float sigmaT = sigmaA + sigmaS;

        float stepTr = exp(-sigmaT * uShadowStepSize);
        transmittance *= stepTr;

        if (transmittance < uTransmittanceThreshold) break;

        t += uShadowStepSize;
    }

    atomicAdd(shadow, localShadow);
    return transmittance;
}
