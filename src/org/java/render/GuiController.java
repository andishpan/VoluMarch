package org.java.render;

import imgui.ImGui;
import imgui.ImGuiIO;
import imgui.flag.ImGuiCond;
import imgui.flag.ImGuiConfigFlags;
import imgui.flag.ImGuiWindowFlags;
import imgui.gl3.ImGuiImplGl3;
import imgui.glfw.ImGuiImplGlfw;

import static org.lwjgl.glfw.GLFW.*;

import imgui.type.ImBoolean;
import org.java.utility.Vector3f;


public class GuiController {
    private final RendererSSBO renderer;
    private final ImBoolean useBlueNoise = new ImBoolean(false);
    private final ImBoolean useSkyDome = new ImBoolean(false);
    Vector3f forward;
    private RenderSettings settings;
    private ImGuiImplGlfw imGuiGlfw;
    private ImGuiImplGl3 imGuiGl3;
    private long window;
    private boolean mouseLookActive = false;
    private double lastMouseX = -1;
    private double lastMouseY = -1;
    private float yaw;
    private float pitch;
    private int activeContext = 0;
    private String[] shapeLabels = {"MixedVolume", "Sphere", "Torus", "Cube", "Cumulus", "Stratocumulus", "Stratus", "Smoke"};
    private String[] methodLabels = {"Beer-Lambert", "HG", "MOS", "Powder", "Beer-Lambert-AABB", "HG-AABB", "MOS-AABB","Powder-AABB"};
    private String[] noiseLabels = {"Inigo-Gradient", "Cellular", "3D Texture"};

    private String[] noiseVariantPaths;

    public GuiController(long window, RenderSettings settings, RendererSSBO renderer) {
        this.settings = settings;
        this.window = window;
        this.renderer = renderer;


        ImGui.createContext();
        ImGuiIO io = ImGui.getIO();
        io.addConfigFlags(ImGuiConfigFlags.DockingEnable | ImGuiConfigFlags.ViewportsEnable);
        io.getFonts().addFontDefault();

        ImGui.styleColorsDark();
        ImGui.getStyle().setWindowRounding(0.0f);

        imGuiGlfw = new ImGuiImplGlfw();
        imGuiGl3 = new ImGuiImplGl3();
        imGuiGlfw.init(window, true);
        imGuiGl3.init("#version 420");

    }

    public void setNoiseVariantPaths(String[] paths) {
        this.noiseVariantPaths = paths;
    }

    public String getCurrentShapeLabel() {
        return shapeLabels[settings.currentShape];
    }

    public String getShapeName(int shapeIndex) {
        String[] shapeLabels = {"MixedVolume", "Sphere", "Torus", "Cube", "Cumulus", "Stratocumulus", "Stratus", "Smoke"};
        return shapeLabels[Math.max(0, Math.min(shapeIndex, shapeLabels.length - 1))];
    }

    public String getNoiseName(int noiseIndex) {
        String[] noiseLabels = {"Inigo-Gradient", "Perlin-Worley", "3D Texture"};
        return noiseLabels[Math.max(0, Math.min(noiseIndex, noiseLabels.length - 1))];
    }

    public String getMethodName(int methodIndex) {
        String[] methodLabels = {"Beer-Lambert", "Compare1", "Powder", "4 Octave Scattering", "Multiple Scattering", "Single Scattering", "Compare2"};
        return methodLabels[Math.max(0, Math.min(methodIndex, methodLabels.length - 1))];
    }

    public void newFrame() {
        imGuiGlfw.newFrame();
        imGuiGl3.newFrame();
        ImGui.newFrame();
    }

    public void render(float deltaTime) {
        ImGui.begin("Volume Control Panel");
        //System.out.println("GUI sees settings: " + System.identityHashCode(settings));

//        ImGui.text("Edit target:");
//        ImGui.sameLine();
//        if (ImGui.radioButton("A##ctx", activeContext == 0)) activeContext = 0;
//        ImGui.sameLine();
//        if (ImGui.radioButton("B##ctx", activeContext == 1)) activeContext = 1;

        RenderSettings preset = new RenderSettings();
        RenderSettings.applyMethodPreset(preset, settings.getCurrentQuality());
        ImGui.separator();
        ImGui.text("Volume Form");
        if (ImGui.beginCombo("Shape", shapeLabels[settings.currentShape])) {
            for (int i = 0; i < shapeLabels.length; i++) {
                boolean selected = (settings.currentShape == i);
                if (ImGui.selectable(shapeLabels[i], selected) && !selected) {
                    settings.previousShape = settings.currentShape;
                    settings.currentShape = i;
                    settings.shapeTransition = 0.0f;
                }
                if (selected) {
                    ImGui.setItemDefaultFocus();
                }
            }
            ImGui.endCombo();
        }
        if (settings.shapeTransition < 1.0f) {
            settings.shapeTransition += deltaTime * settings.transitionSpeed;
            settings.shapeTransition = Math.min(settings.shapeTransition, 1.0f);
        }
        ImGui.separator();
        ImGui.text("Quality Preset");


        if (ImGui.button("Low")) {
            settings.setCurrentQuality(RenderSettings.Quality.LOW);
            RenderSettings.applyMethodPreset(settings, RenderSettings.Quality.LOW);
        }
        ImGui.sameLine();


        if (ImGui.button("Mid")) {
            settings.setCurrentQuality(RenderSettings.Quality.MID);
            RenderSettings.applyMethodPreset(settings, RenderSettings.Quality.MID);
        }
        ImGui.sameLine();


        if (ImGui.button("High")) {
            settings.setCurrentQuality(RenderSettings.Quality.HIGH);
            RenderSettings.applyMethodPreset(settings, RenderSettings.Quality.HIGH);
        }
        ImGui.sameLine();


        if (ImGui.button("Ultra")) {
            settings.setCurrentQuality(RenderSettings.Quality.ULTRA);
            RenderSettings.applyMethodPreset(settings, RenderSettings.Quality.ULTRA);
        }



//        ImGui.separator();
//        ImGui.text("Display");
//        int[] screens = {settings.numScreens};
//        if (ImGui.sliderInt("Screens", screens, 1, 2)) {
//            settings.numScreens = screens[0];
//        }
//        if (settings.numScreens == 2) {
//            ImGui.separator();
//            ImGui.text("Shaders");
//
//            if (ImGui.beginCombo("Shader A", methodLabels[settings.screenMethods[0]])) {
//                for (int i = 0; i < methodLabels.length; i++) {
//                    boolean sel = settings.screenMethods[0] == i;
//                    if (ImGui.selectable(methodLabels[i], sel)) {
//                        settings.screenMethods[0] = i;
//                    }
//                    if (sel) ImGui.setItemDefaultFocus();
//                }
//                ImGui.endCombo();
//            }
//
//            if (ImGui.beginCombo("Shader B", methodLabels[settings.screenMethods[1]])) {
//                for (int i = 0; i < methodLabels.length; i++) {
//                    boolean sel = settings.screenMethods[1] == i;
//                    if (ImGui.selectable(methodLabels[i], sel)) {
//                        settings.screenMethods[1] = i;
//                    }
//                    if (sel) ImGui.setItemDefaultFocus();
//                }
//                ImGui.endCombo();
//            }
//        }


        ImGui.separator();
        ImGui.text("Method Shaders");
        if (ImGui.beginCombo("Scattering", methodLabels[settings.currentMethod])) {
            for (int i = 0; i < methodLabels.length; i++) {
                boolean selected = (settings.currentMethod == i);
                if (ImGui.selectable(methodLabels[i], selected)) {
                    settings.currentMethod = i;
                }
                if (selected) {
                    ImGui.setItemDefaultFocus();
                }
            }
            ImGui.endCombo();
        }

        ImGui.separator();
        ImGui.text("Noise Type");
        if (ImGui.beginCombo("Noise", noiseLabels[settings.currentNoise])) {
            for (int i = 0; i < noiseLabels.length; i++) {
                boolean selected = (settings.currentNoise == i);
                if (ImGui.selectable(noiseLabels[i], selected)) {
                    settings.currentNoise = i;
                    String selectedLabel = noiseLabels[i];
                    String selectedShader = (noiseVariantPaths != null && i < noiseVariantPaths.length)
                            ? noiseVariantPaths[i]
                            : "Unknown";

                    System.out.printf("Selected Noise: %s | Shader Path: %s\n", selectedLabel, selectedShader);
                }
                if (selected) {
                    ImGui.setItemDefaultFocus();
                }
            }
            ImGui.endCombo();
        }


        ImGui.separator();
        ImGui.text("Light Properties");
        float[] sunDirectionArr = {settings.sunDirection.x, settings.sunDirection.y, settings.sunDirection.z};
        if (ImGui.sliderFloat3("SunDirection", sunDirectionArr, -1.0f, 1.0f)) {
            settings.sunDirection.x = sunDirectionArr[0];
            settings.sunDirection.y = sunDirectionArr[1];
            settings.sunDirection.z = sunDirectionArr[2];
        }
        if (ImGui.smallButton("r##sunDirection")) {
            settings.sunDirection.x = preset.sunDirection.x;
            settings.sunDirection.y = preset.sunDirection.y;
            settings.sunDirection.z = preset.sunDirection.z;
        }

        float[] intensityArr = {settings.sunIntensity};
        ImGui.sliderFloat("Sun Intensity", intensityArr, 0.0f, 10.0f);
        settings.sunIntensity = intensityArr[0];
        if (ImGui.smallButton("r##sunIntesity")) {
            settings.sunIntensity = preset.sunIntensity;
        }


        ImGui.separator();
        ImGui.text("Iterations");
        float[] stepSizeArray = {settings.stepSize};
        ImGui.sliderFloat("Step Size", stepSizeArray, 0.0f, 5.0f);
        settings.stepSize = stepSizeArray[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##stepSize")) {
            settings.stepSize = preset.stepSize;
        }

        float[] shadowStepSizeArray = {settings.shadowStepSize};
        ImGui.sliderFloat("Shadow Step Size", shadowStepSizeArray, 0.0f, 5.0f);
        settings.shadowStepSize = shadowStepSizeArray[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##shadowStepSize")) {
            settings.shadowStepSize = preset.shadowStepSize;
        }

        ImGui.separator();
        ImGui.text("Optical Properties");
        float[] absorptionArr = {settings.volumetricAbsorption};
        ImGui.sliderFloat("Volumetric Absorption",
                absorptionArr, 0.0f, 2.0f,
                "%.5f");
        settings.volumetricAbsorption = absorptionArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##absorption")) {
            settings.volumetricAbsorption = preset.volumetricAbsorption;
        }

        float[] scatteringArr = {settings.volumetricScattering};

        ImGui.sliderFloat("Volumetric Scattering",
                scatteringArr, 0.0f, 2.0f,
                "%.5f");
        settings.volumetricScattering = scatteringArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##scattering")) {
            settings.volumetricScattering = preset.volumetricScattering;
        }

        ImGui.separator();
        ImGui.text("Thresholds");
        float[] transmittanceThreshold = {settings.transmittanceThreshold};
        if (ImGui.sliderFloat("Transmittance Threshold", transmittanceThreshold, 0.0f, 1.0f))
            settings.transmittanceThreshold = transmittanceThreshold[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##transmittanceThreshold")) {
            settings.transmittanceThreshold = preset.transmittanceThreshold;
        }
        float[] sdfHitThreshold = {settings.sdfHitThreshold};
        if (ImGui.sliderFloat("SDF Hit Threshold.", sdfHitThreshold, 0.0f, 1.0f))
            settings.sdfHitThreshold = sdfHitThreshold[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##sdfHitThreshold")) {
            settings.sdfHitThreshold = preset.sdfHitThreshold;
        }

        float[] maxRayDistance = {settings.maxRayDistance};
        if (ImGui.sliderFloat("Max Ray Distance", maxRayDistance, 0.0f, 5000.0f))
            settings.maxRayDistance = maxRayDistance[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##maxRayDistance")) {
            settings.maxRayDistance = preset.maxRayDistance;
        }


        ImGui.separator();
        ImGui.text("Forward/Backward");
        float[] phaseG_Array = {settings.phaseG};
        ImGui.sliderFloat("Phase g",
                phaseG_Array, -0.9f, 0.9f);
        settings.phaseG = phaseG_Array[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##phaseG")) {
            settings.phaseG = preset.phaseG;
        }


        ImGui.separator();
        ImGui.text("Noise Properties");
        float[] noiseScaleArr = {settings.noiseScale};
        ImGui.sliderFloat("Noise Scale", noiseScaleArr, 1.0f, 30.0f);
        settings.noiseScale = noiseScaleArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##noiseScale")) {
            settings.noiseScale = preset.noiseScale;
        }

        float[] noiseHeightArr = {settings.noiseHeight};
        ImGui.sliderFloat("Noise Height", noiseHeightArr, 0.0f, 50.0f);
        settings.noiseHeight = noiseHeightArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##noiseHeight")) {
            settings.noiseHeight = preset.noiseHeight;
        }

        int[] noiseOctavesArr = {settings.noiseOctaves};
        ImGui.sliderInt("Noise Octaves", noiseOctavesArr, 0, 10);
        settings.noiseOctaves = noiseOctavesArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##noiseOctaves")) {
            settings.noiseOctaves = preset.noiseOctaves;
        }


        int[] mosOctavesArr = {settings.numMosOctaves};
        ImGui.sliderInt("MOS Octaves", mosOctavesArr, 0, 8);
        settings.numMosOctaves = mosOctavesArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##MOSOctaves")) {
            settings.numMosOctaves = preset.numMosOctaves;
        }

        ImGui.separator();
        ImGui.text("Powder Properties");
        int powderMethodIndex = java.util.Arrays.asList(methodLabels).indexOf("Powder");
        if (settings.currentMethod == powderMethodIndex) {
            float[] powderStrengthArr = {settings.powderStrength};
            ImGui.sliderFloat("Powder Strength", powderStrengthArr, 0.0f, 20.0f);
            settings.powderStrength = powderStrengthArr[0];
            ImGui.sameLine();
            if (ImGui.smallButton("r##powderStrength")) {
                settings.powderStrength = preset.powderStrength;
            }
        }

        ImGui.separator();
        ImGui.text("SDF");
        float[] blendRadiusArr = {settings.sdfBlendRadius};
        ImGui.sliderFloat("SDF Blend Radius", blendRadiusArr, 0.0f, 20.0f);
        settings.sdfBlendRadius = blendRadiusArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##sdfBlendRadius")) {
            settings.sdfBlendRadius = preset.sdfBlendRadius;
        }


        ImGui.separator();
        ImGui.text("Blue Noise");
        if (ImGui.checkbox("Use Blue Noise", useBlueNoise)) {
            settings.useBlueNoise = useBlueNoise.get();
        }

        ImGui.separator();
        ImGui.text("Sky Dome");
        if (ImGui.checkbox("Use Sky Dome", useSkyDome)) {
            settings.useCubeMap = useSkyDome.get();
        }


        float[] noiseJ = {settings.noiseJitter};
        if (ImGui.sliderFloat(" Blue Noise Jitter", noiseJ, 0.0f, 1.0f)) settings.noiseJitter = noiseJ[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##blueNoiseJitter")) {
            settings.noiseJitter = preset.noiseJitter;
        }
        ImGui.separator();
        ImGui.text("Step Caps");

        int[] maxStepsArr = {settings.maxSteps};
        ImGui.sliderInt("Max Steps", maxStepsArr, 1, 250);
        settings.maxSteps = maxStepsArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##maxSteps")) {
            settings.maxSteps = preset.maxSteps;
        }

        int[] maxVolStepsArr = {settings.maxVolumeSteps};
        ImGui.sliderInt("Max Volume Steps", maxVolStepsArr, 1, 250);
        settings.maxVolumeSteps = maxVolStepsArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##maxVolumeSteps")) {
            settings.maxVolumeSteps = preset.maxVolumeSteps;
        }


        int[] maxLightStepsArr = {settings.maxShadowSteps};
        ImGui.sliderInt("Max Shadow Steps", maxLightStepsArr, 1, 120);
        settings.maxShadowSteps = maxLightStepsArr[0];
        ImGui.sameLine();
        if (ImGui.smallButton("r##maxShadowSteps")) {
            settings.maxShadowSteps = preset.maxShadowSteps;
        }

        ImGui.end();


        ImGui.setNextWindowPos(10, 10, ImGuiCond.Always);
        ImGui.setNextWindowSize(250, 0);
        ImGui.begin("Volume Analysis Panel", ImGuiWindowFlags.NoResize | ImGuiWindowFlags.AlwaysAutoResize);


        Vector3f cloudCenter = new Vector3f(0.0f, 20.0f, -25.0f);
        float distanceToCloud = settings.cameraPos.subtract(cloudCenter).length();
        ImGui.sameLine();

        if (ImGui.smallButton("r##cameraPos")) {
            settings.cameraPos.x = preset.cameraPos.x;
            settings.cameraPos.y = preset.cameraPos.y;
            settings.cameraPos.z = preset.cameraPos.z;

            settings.cameraLookAt.x = preset.cameraLookAt.x;
            settings.cameraLookAt.y = preset.cameraLookAt.y;
            settings.cameraLookAt.z = preset.cameraLookAt.z;

            settings.cameraUp.x = preset.cameraUp.x;
            settings.cameraUp.y = preset.cameraUp.y;
            settings.cameraUp.z = preset.cameraUp.z;
        }

        if (distanceToCloud < 20.0f) {
            ImGui.textColored(1.0f, 0.2f, 0.2f, 1.0f, String.format("Distance to Cloud: %.2f", distanceToCloud));
        } else if (distanceToCloud < 50.0f) {
            ImGui.textColored(1.0f, 1.0f, 0.0f, 1.0f, String.format("Distance to Cloud: %.2f", distanceToCloud));
        } else {
            ImGui.textColored(0.2f, 1.0f, 0.2f, 1.0f, String.format("Distance to Cloud: %.2f", distanceToCloud));
        }

        ImGui.text(String.format("Camera Position: (%.1f, %.1f, %.1f)",
                settings.cameraPos.x, settings.cameraPos.y, settings.cameraPos.z));

        ImGui.text(String.format("Look At: (%.1f, %.1f, %.1f)",
                settings.cameraLookAt.x, settings.cameraLookAt.y, settings.cameraLookAt.z));

        ImGui.text(String.format("Camera Up: (%.1f, %.1f, %.1f)",
                settings.cameraUp.x, settings.cameraUp.y, settings.cameraUp.z));

        int width = settings.resolutionX;
        int height = settings.resolutionY;

        RendererSSBO.LoopStats stats = renderer.fetchLoopStats(width, height);

        ImGui.separator();
        ImGui.text("Average Step Counts:");
        ImGui.text(String.format("Volume Steps: %d", (int) stats.volume()));
        ImGui.text(String.format("Shadow Steps: %d", (int) stats.shadow()));
        ImGui.text(String.format("SDF Steps: %d", (int) stats.sdf()));


        ImGui.text(String.format("SPH: %d", (int) stats.sph()));
        ImGui.text(String.format("SPP: %d", (int) stats.spp()));

        ImGui.separator();
        if (ImGui.button("Save Screenshot")) {
            settings.requestScreenshot();
            System.out.println("Screenshot requested");
        }


        ImGui.separator();
        if (ImGui.button("Predict Cloud")) {
            settings.requestPrediction();
            settings.markPredictionStarted();
            System.out.println("Prediction requested");
        }


        if (settings.isPredictionInProgress()) {
            ImGui.text("Prediction: thinking...");
            ImGui.progressBar(0.0f);
        } else {
            float score = settings.getLastCloudScore();
            String label = settings.getLastCloudLabel();
            ImGui.text(String.format("Prediction: %s (%.2f%%)", label, score * 100f));
            ImGui.progressBar(score);
        }




        ImGui.end();


    }


    public void updateCameraFromKeyboard(float deltaTime) {
        ImGuiIO io = ImGui.getIO();
        if (io.getWantCaptureKeyboard()) return;

        float speed = 20.0f * deltaTime;

        Vector3f forward = settings.cameraLookAt.subtract(settings.cameraPos).normalize();
        Vector3f right = forward.cross(settings.cameraUp).normalize();

        boolean moved = false;

        if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) {
            settings.cameraPos = settings.cameraPos.add(forward.scale(speed));
            settings.cameraLookAt = settings.cameraLookAt.add(forward.scale(speed));
            moved = true;
        }
        if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) {
            settings.cameraPos = settings.cameraPos.subtract(forward.scale(speed));
            settings.cameraLookAt = settings.cameraLookAt.subtract(forward.scale(speed));
            moved = true;
        }
        if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS) {
            settings.cameraPos = settings.cameraPos.subtract(right.scale(speed));
            settings.cameraLookAt = settings.cameraLookAt.subtract(right.scale(speed));
            moved = true;
        }
        if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) {
            settings.cameraPos = settings.cameraPos.add(right.scale(speed));
            settings.cameraLookAt = settings.cameraLookAt.add(right.scale(speed));
            moved = true;
        }
        if (glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS) {
            settings.cameraPos = settings.cameraPos.subtract(settings.cameraUp.scale(speed));
            settings.cameraLookAt = settings.cameraLookAt.subtract(settings.cameraUp.scale(speed));
            moved = true;
        }
        if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS) {
            settings.cameraPos = settings.cameraPos.add(settings.cameraUp.scale(speed));
            settings.cameraLookAt = settings.cameraLookAt.add(settings.cameraUp.scale(speed));
            moved = true;
        }


        if (moved) {

        }
    }

    public void updateMouseLook(float deltaTime) {
        ImGuiIO io = ImGui.getIO();

        if (glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_RIGHT) == GLFW_PRESS) {
            if (!mouseLookActive) {

                mouseLookActive = true;
                glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);


                Vector3f forward = settings.cameraLookAt.subtract(settings.cameraPos).normalize();


                yaw = (float) Math.toDegrees(Math.atan2(forward.z, forward.x));

                pitch = (float) Math.toDegrees(Math.asin(forward.y));


                lastMouseX = -1;
                lastMouseY = -1;
            }

            double[] xpos = new double[1];
            double[] ypos = new double[1];
            glfwGetCursorPos(window, xpos, ypos);

            if (lastMouseX < 0 || lastMouseY < 0) {
                lastMouseX = xpos[0];
                lastMouseY = ypos[0];
                return;
            }

            double dx = xpos[0] - lastMouseX;
            double dy = lastMouseY - ypos[0];

            lastMouseX = xpos[0];
            lastMouseY = ypos[0];

            float sensitivity = 0.1f;
            yaw += (float) (dx * sensitivity);
            pitch += (float) (dy * sensitivity);
            pitch = Math.max(-89.9f, Math.min(89.9f, pitch));


            float radYaw = (float) Math.toRadians(yaw);
            float radPitch = (float) Math.toRadians(pitch);
            float x = (float) (Math.cos(radYaw) * Math.cos(radPitch));
            float y = (float) (Math.sin(radPitch));
            float z = (float) (Math.sin(radYaw) * Math.cos(radPitch));
            Vector3f newForward = new Vector3f(x, y, z).normalize();
            settings.cameraLookAt = settings.cameraPos.add(newForward);

        } else {
            if (mouseLookActive) {
                mouseLookActive = false;
                glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
            }
            lastMouseX = -1;
            lastMouseY = -1;
        }
    }


    public void renderDrawData() {
        imGuiGl3.renderDrawData(ImGui.getDrawData());
    }

}
