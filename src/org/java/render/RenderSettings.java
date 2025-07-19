package org.java.render;

import org.java.utility.Vector3f;

public class RenderSettings {

    public final float transitionSpeed = 1.5f;
    public int numScreens = 1;
    public int resolutionX;
    public int resolutionY;
    public Vector3f cameraPos = new Vector3f(4.0f, 1.2f, -81.3f);
    public Vector3f cameraLookAt = new Vector3f(0.5f, 33.9f, -7.8f);
    public Vector3f cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);
    public Vector3f sunDirection = new Vector3f(0.372f, 0.512f, -0.116f);
    public Vector3f sunColour = new Vector3f(1.0f, 0.95f, 0.8f);
    public float sunIntensity = 5.0f;
//    public float volumetricAbsorption = 0.06188f;
//    public float volumetricScattering = 0.33996f;
public float volumetricAbsorption = 0.06188f;
    public float volumetricScattering = 0.10108f;
    public float phaseG = 0.100f;
    public boolean useBlueNoise;
    public boolean useCubeMap;
    public float powderStrength = 0.9f;
    public float sdfBlendRadius = 6.0f;
//    public float noiseScale = 18.879f;
//    public float noiseHeight = 6.413f;
//    public float noiseScale = 10.0f;
//    public float noiseHeight = 16.0f;

        public float noiseScale = 7.923f;
    public float noiseHeight = 8.472f;
    public int currentNoise = 0;
    public int tilePeriod;
    public int noiseOctaves;
    public float forwardScattering = 0.6f;
    public float backwardScattering = -0.6f;
    public float ambientLight = 0.1f;
    public int currentShape = 0;
    public int previousShape = 0;
    public float shapeTransition = 1.0f;
    public float transmittanceThreshold = 0.01f;
    public float sdfHitThreshold = 0.03f;
    public float noiseJitter = 0.02f;
    public float maxRayDistance = 1000.0f;
    public int currentMethod = 0;
    public int[] screenMethods = new int[]{currentMethod, currentMethod};
    public int numMosOctaves;
    public int maxSteps;
    public int maxVolumeSteps;
    public int maxShadowSteps;
    public float stepSize;
    public float shadowStepSize;
    Vector3f viewDir = new Vector3f(cameraLookAt).subtract(cameraPos);
    private boolean referenceMode = false;
    private String customMethodName = null;
    private boolean takeScreenshot = false;
    private boolean predictCurrentRender = false;
    private Quality currentQuality = null;
    private Scene currentScene = Scene.BACKLIT_FOG;

    private volatile String lastCloudLabel = "";
    private volatile float  lastCloudScore = 0f;





    // add these methods:
    public void setLastCloudLabel(String label) {
        this.lastCloudLabel = label;
    }
    public String getLastCloudLabel() {
        return lastCloudLabel;
    }

    private volatile boolean predictionInProgress = false;

    public void markPredictionStarted() {
        predictionInProgress = true;
    }
    public void markPredictionDone() {
        predictionInProgress = false;
    }
    public boolean isPredictionInProgress() {
        return predictionInProgress;
    }





    public void setLastCloudScore(float s) { this.lastCloudScore = s; }
    public float getLastCloudScore()   { return lastCloudScore; }

    public static void applyMethodPreset(RenderSettings rs, Quality q) {
        rs.setCurrentQuality(q);
        switch (q) {
            case LOW -> {
                rs.maxSteps = rs.maxVolumeSteps = 30;
                rs.maxShadowSteps = 15;
                rs.stepSize = 1.20f;
                rs.shadowStepSize = 1.20f * 1.5f;
                rs.noiseOctaves = 2;

                rs.useBlueNoise = false;
                rs.powderStrength = 20.0f;


                rs.numMosOctaves = 2;
//                rs.volumetricAbsorption = 0.06188f;
//                rs.volumetricScattering = 0.33996f;
                rs.sdfBlendRadius = 2.0f;


            }
            case MID -> {

                rs.maxSteps = rs.maxVolumeSteps = 50;
                rs.maxShadowSteps = 25;
                rs.stepSize = 0.80f;
                rs.shadowStepSize = 0.80f * 1.4f;
                rs.noiseOctaves = 5;

                rs.powderStrength = 10.0f;
                rs.useBlueNoise = false;
                rs.sdfBlendRadius = 4.0f;

                rs.numMosOctaves = 4;
//                rs.volumetricAbsorption = 0.06188f;
//                rs.volumetricScattering = 0.33996f;

            }
            case HIGH -> {


                rs.maxSteps = rs.maxVolumeSteps = 80;
                rs.maxShadowSteps = 40;
                rs.stepSize = 0.40f;
                rs.shadowStepSize = 0.40f * 1.3f;
                rs.noiseOctaves = 7;
                rs.sdfBlendRadius = 6.0f;
                rs.powderStrength = 15.0f;

                rs.useBlueNoise = false;
                rs.numMosOctaves = 6;
//                rs.volumetricAbsorption = 0.06188f;
//                rs.volumetricScattering = 0.33996f;

            }


            case ULTRA -> {
                rs.maxSteps = rs.maxVolumeSteps = 120;
                rs.maxShadowSteps = 60;
                rs.stepSize = 0.25f;
                rs.shadowStepSize = 0.25f * 1.2f;
                rs.noiseOctaves = 10;
                rs.sdfBlendRadius = 8.0f;
                rs.powderStrength = 20.0f;

                rs.numMosOctaves = 8;

                rs.useBlueNoise = false;
//                rs.volumetricAbsorption = 0.06188f;
//                rs.volumetricScattering = 0.33996f;


            }
        }


    }



    public void setSunDirection(Vector3f direction) {
        sunDirection.set(direction);
    }

    public boolean isScreenshotRequested() {
        return takeScreenshot;
    }

    public void requestScreenshot() {
        takeScreenshot = true;
    }

    public void clearScreenshotFlag() {
        takeScreenshot = false;
    }

    public void clearPredictionFlag() {
        predictCurrentRender = false;
    }

    public boolean isPredictionRequested() {
        return predictCurrentRender;
    }

    public void requestPrediction() {
        predictCurrentRender = true;
    }

    public float getTransmittanceThreshold() {
        return transmittanceThreshold;
    }

    public void setTransmittanceThreshold(float v) {
        transmittanceThreshold = v;
    }

    public Quality getCurrentQuality() {
        return currentQuality;
    }

    public void setCurrentQuality(Quality quality) {
        this.currentQuality = quality;
    }

    public int getCurrentNoise() {
        return currentNoise;
    }

    public void setCurrentNoise(int noise) {
        currentNoise = noise;
    }

    public int getCurrentMethod() {
        return currentMethod;
    }

    public void setCurrentMethod(int method) {
        currentMethod = method;
    }

    public String getCustomMethodName() {
        return customMethodName;
    }

    public void setCustomMethodName(String name) {
        this.customMethodName = name;
    }

    public void setResolutionX(int resolutionX) {
        this.resolutionX = resolutionX;
    }

    public void setResolutionY(int resolutionY) {
        this.resolutionY = resolutionY;
    }

    public boolean isReferenceMode() {
        return referenceMode;
    }

    public void setReferenceMode(boolean referenceMode) {
        this.referenceMode = referenceMode;
    }

    public Scene getCurrentScene() {
        return currentScene;
    }

    public void setCurrentScene(Scene scene) {
        this.currentScene = scene;

    }


    public enum Quality {LOW, MID, HIGH, ULTRA}

    public enum Scene {
        BACKLIT_FOG,
        SPOTLIGHT_SMOKE,
        TOP_DOWN_CLOUD,
        RIM_LIGHTING,
        SIDE_FILL,
        FRONT_FILL,
        NEUTRAL,
        WARM,
        DARK,
        DIFFUSE
    }


}
