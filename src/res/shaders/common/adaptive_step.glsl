#ifndef ADAPTIVE_STEP_GLSL
#define ADAPTIVE_STEP_GLSL
const float MIN_SDF_STEP  = 0.3;
const float MAX_SDF_STEP  = 4.0;
const float OUTSIDE_SDF_FACTOR = 0.8;

const float MIN_VOL_STEP  = 0.05;
const float MAX_VOL_STEP  = 1.0;
const float MAX_T_ERR = 0.05;// 0.01, 0.002
const float MIN_SIGMA_T = 1e-3;


float adaptiveStep(float sdf, float density)
{

    if (sdf > 0.0)
    {
        float step = sdf * OUTSIDE_SDF_FACTOR;
        return clamp(step, MIN_SDF_STEP, MAX_SDF_STEP);
    }


    float sigmaT = max((uVolumetricAbsorption + uVolumetricScattering) * density,
    MIN_SIGMA_T);
    float step = -log(1.0 - MAX_T_ERR) / sigmaT;
    return clamp(step, MIN_VOL_STEP, MAX_VOL_STEP);

}

#endif
