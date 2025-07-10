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
    public float volumetricAbsorption = 0.06188f;
    public float volumetricScattering = 0.33996f;
    public float phaseG = 0.100f;
    public boolean useBlueNoise;
    public float powderStrength = 0.9f;
    public float sdfBlendRadius = 6.0f;
    public float noiseScale = 18.879f;
    public float noiseHeight = 6.413f;
//    public float noiseScale = 10.0f;
//    public float noiseHeight = 16.0f;
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


    private float lastCloudScore = -1f;

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
                rs.powderStrength = 2.0f;
                rs.sdfBlendRadius = 2.0f;

                rs.numMosOctaves = 2;
                rs.volumetricAbsorption = 0.06188f;
                rs.volumetricScattering = 0.33996f;


            }
            case MID -> {

                rs.maxSteps = rs.maxVolumeSteps = 50;
                rs.maxShadowSteps = 25;
                rs.stepSize = 0.80f;
                rs.shadowStepSize = 0.80f * 1.4f;
                rs.noiseOctaves = 5;

                rs.powderStrength = 4.0f;
                rs.useBlueNoise = false;

                rs.numMosOctaves = 4;
                rs.volumetricAbsorption = 0.06188f;
                rs.volumetricScattering = 0.33996f;

            }
            case HIGH -> {


                rs.maxSteps = rs.maxVolumeSteps = 80;
                rs.maxShadowSteps = 40;
                rs.stepSize = 0.40f;
                rs.shadowStepSize = 0.40f * 1.3f;
                rs.noiseOctaves = 7;

                rs.powderStrength = 6.0f;

                rs.useBlueNoise = false;
                rs.numMosOctaves = 6;
                rs.volumetricAbsorption = 0.06188f;
                rs.volumetricScattering = 0.33996f;

            }


            case ULTRA -> {
                rs.maxSteps = rs.maxVolumeSteps = 120;
                rs.maxShadowSteps = 60;
                rs.stepSize = 0.25f;
                rs.shadowStepSize = 0.25f * 1.2f;
                rs.noiseOctaves = 10;

                rs.powderStrength = 8.0f;

                rs.numMosOctaves = 8;

                rs.useBlueNoise = false;
                rs.volumetricAbsorption = 0.06188f;
                rs.volumetricScattering = 0.33996f;


            }
        }


    }

    public static void applyScenePreset(RenderSettings rs, Scene scene) {

        rs.setCurrentScene(scene);

        Vector3f cloudCenter = new Vector3f(0.0f, 20.0f, -25.0f);

        rs.ambientLight = 0.10f;
        rs.sunColour = new Vector3f(1.0f, 0.95f, 0.8f);

        switch (scene) {
            case BACKLIT_FOG -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(0.0f, 5.0f, 35.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                Vector3f viewDir = new Vector3f(rs.cameraLookAt).subtract(rs.cameraPos).normalize();
                rs.setSunDirection(new Vector3f(viewDir).negate());
                rs.sunIntensity = 5.0f;
            }

            case SPOTLIGHT_SMOKE -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(0.0f, 3.0f, 30.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                rs.setSunDirection(new Vector3f(0.0f, 1.0f, 0.0f));
                rs.sunIntensity = 8.0f;
            }

            case TOP_DOWN_CLOUD -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(0.0f, 60.0f, 0.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 0.0f, -1.0f);

                rs.setSunDirection(new Vector3f(0.0f, 1.0f, -0.15f).normalize());
                rs.sunIntensity = 6.0f;
            }

            case RIM_LIGHTING -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(-30.0f, 10.0f, 30.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                rs.setSunDirection(new Vector3f(0.354f, 0.707f, -0.612f));
                rs.sunIntensity = 5.0f;
            }

            case SIDE_FILL -> {
                rs.cameraPos = new Vector3f(-48.6f, 25.9f, 1.7f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                rs.setSunDirection(new Vector3f(-0.999f, 0.052f, 0.000f));
                rs.sunIntensity = 4.0f;
            }

            case FRONT_FILL -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(0.0f, 5.0f, -35.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                rs.setSunDirection(new Vector3f(0.0f, 0.052f, 0.999f));
                rs.sunIntensity = 5.0f;
            }

            case NEUTRAL -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(0.0f, 10.0f, 35.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                rs.setSunDirection(new Vector3f(0.0f, 1.0f, 0.0f));
                rs.sunIntensity = 6.0f;
            }

            case WARM -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(-25.0f, 8.0f, 35.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                rs.setSunDirection(new Vector3f(0.0f, 0.052f, -0.999f));
                rs.sunColour = new Vector3f(1.0f, 0.80f, 0.60f);
                rs.sunIntensity = 8.0f;
            }

            case DARK -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(10.0f, 15.0f, 40.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                rs.setSunDirection(new Vector3f(-0.1f, 0.3f, -0.95f));
                rs.sunColour = new Vector3f(0.60f, 0.70f, 1.00f);
                rs.sunIntensity = 0.8f;
                rs.ambientLight = 0.02f;
            }

            case DIFFUSE -> {
                rs.cameraPos = new Vector3f(cloudCenter).add(0.0f, 8.0f, 40.0f);
                rs.cameraLookAt = new Vector3f(cloudCenter);
                rs.cameraUp = new Vector3f(0.0f, 1.0f, 0.0f);

                rs.setSunDirection(new Vector3f(0.0f, 1.0f, 0.0f));
                rs.sunIntensity = 0.0f;
                rs.ambientLight = 0.40f;
            }
        }

        rs.viewDir = new Vector3f(rs.cameraLookAt).subtract(rs.cameraPos);
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
