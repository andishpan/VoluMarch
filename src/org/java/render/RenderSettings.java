package org.java.render;
import org.java.utility.Vector3f;

public class RenderSettings {

    private boolean referenceMode = false;

    //camera
    public Vector3f cameraPos = new Vector3f(0.0f, 40.0f, -5.0f);
    public Vector3f cameraLookAt   = new Vector3f(0.0f, -0.5f, -1.0f);
    public Vector3f cameraUp       = new Vector3f(0.0f, 1.0f, 0.0f);

    //cloud
    public float[] sunDirection = { -0.8f, 0.2f, -1.0f };
    public float   sunIntensity = 1.2f;
    public float   volumetricAbsorption = 0.1f;
    public float   volumetricScattering = 0.1f;
    public float   phaseG = 0.1f;
    public boolean useBlueNoise = true;

    //powder
    public float powderStrength = 0.9f;
    public float blendFactor = 0.8f;



    // noise
    public float noiseScale = 10.0f;
    public float noiseHeight = 16.0f;
    public int currentNoise = 0;
    public int tilePeriod = 8;

    //scattering
    public float forwardScattering = 0.6f;
    public float backwardScattering = -0.6f;
    public float ambientLight = 0.1f;
    public float[] volumetricAlbedo = {1.0f, 0.98f, 0.95f};

    // shape
    public int currentShape = 0;
    public int previousShape = 0;
    public float shapeTransition = 1.0f;
    public final float transitionSpeed = 1.5f;

    // methods
    public int currentMethod = 0;


    // steps
    public int maxSteps = 256;
    public int maxVolumeSteps = 256;
    public int maxShadowMarchSteps = 8;
    public int maxLightMarchSteps = 8;
    public float stepSize = 0.6f;
    public float shadowStepSize = 0.6f * 1.4f;






    public int getCurrentNoise() {
        return currentNoise;
    }
    public int getCurrentMethod() {
        return currentMethod;
    }


    public boolean isReferenceMode() {
        return referenceMode;
    }

    public void setReferenceMode(boolean referenceMode) {
        this.referenceMode = referenceMode;
    }




}
