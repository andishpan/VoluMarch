import imgui.ImGui;
import imgui.ImGuiIO;
import imgui.flag.ImGuiConfigFlags;
import imgui.gl3.ImGuiImplGl3;
import imgui.glfw.ImGuiImplGlfw;

public class GuiController {
    private RenderSettings settings;
    private ImGuiImplGlfw imGuiGlfw;
    private ImGuiImplGl3 imGuiGl3;



    private String[] shapeLabels = { "MixedVolume", "Sphere", "Torus", "Cube" };
    private String[] methodLabels = { "Single", "Multiple Octave", "Backward Scattering", "Forward Scattering", "Dual Lobe" };
    private String[] noiseLabels  = { "Perlin", "InigoQuilez", "Perlin-Worley", "Worley", "Precomputed" };


    public GuiController(long window, RenderSettings settings) {
        this.settings = settings;


        ImGui.createContext();
        ImGuiIO io = ImGui.getIO();
        io.addConfigFlags(ImGuiConfigFlags.DockingEnable);
        io.getFonts().addFontDefault();

        imGuiGlfw = new ImGuiImplGlfw();
        imGuiGl3  = new ImGuiImplGl3();
        imGuiGlfw.init(window, true);
        imGuiGl3.init("#version 330");

      /*  if (!ImGui.getIO().getFonts().isBuilt()) {
            System.err.println("Font atlas not built!");
        } else {
            System.out.println("Font atlas is ready!");
        } */
    }

    public void newFrame() {
        imGuiGlfw.newFrame();
        imGuiGl3.newFrame();
        ImGui.newFrame();
    }

    public void render(float deltaTime) {
        ImGui.begin("Cloud Control Panel");


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


        if (ImGui.beginCombo("Noise", noiseLabels[settings.currentNoise])) {
            for (int i = 0; i < noiseLabels.length; i++) {
                boolean selected = (settings.currentNoise == i);
                if (ImGui.selectable(noiseLabels[i], selected)) {
                    settings.currentNoise = i;
                }
                if (selected) {
                    ImGui.setItemDefaultFocus();
                }
            }
            ImGui.endCombo();
        }


        ImGui.sliderFloat3("Sun Direction", settings.sunDirection, -1.0f, 1.0f);

        float[] intensityArr = { settings.sunIntensity };
        ImGui.sliderFloat("Sun Intensity", intensityArr, 0.0f, 5.0f);
        settings.sunIntensity = intensityArr[0];

        float[] absorptionArr = { settings.volumetricAbsorption };
        ImGui.sliderFloat("Volumetric Absorption", absorptionArr, 0.0f, 2.0f);
        settings.volumetricAbsorption = absorptionArr[0];

        float[] noiseScaleArr = { settings.noiseScale };
        ImGui.sliderFloat("Noise Scale", noiseScaleArr, 1.0f, 30.0f);
        settings.noiseScale = noiseScaleArr[0];

        float[] noiseHeightArr = { settings.noiseHeight };
        ImGui.sliderFloat("Noise Height", noiseHeightArr, 0.0f, 50.0f);
        settings.noiseHeight = noiseHeightArr[0];

        float[] forwardScatteringArr = { settings.forwardScattering };
        ImGui.sliderFloat("Forward Scattering", forwardScatteringArr, 0.0f, 2.0f);
        settings.forwardScattering = forwardScatteringArr[0];
        float[] backwardScatteringArr = { settings.backwardScattering };
        ImGui.sliderFloat("Backward Scattering", backwardScatteringArr, 0.0f, 2.0f);
        settings.backwardScattering = backwardScatteringArr[0];

        float[] ambientLightArr = { settings.ambientLight };
        ImGui.sliderFloat("Ambient Light", ambientLightArr, 0.0f, 10.2f);
        settings.ambientLight = ambientLightArr[0];

        float[] albedoArr = { settings.volumetricAlbedo[0],
                settings.volumetricAlbedo[1],
                settings.volumetricAlbedo[2] };
        if (ImGui.colorEdit3("Volumetric Albedo", albedoArr)) {
            settings.volumetricAlbedo[0] = albedoArr[0];
            settings.volumetricAlbedo[1] = albedoArr[1];
            settings.volumetricAlbedo[2] = albedoArr[2];
        }


        boolean useBlueNoiseArr = settings.useBlueNoise ;
        if (ImGui.checkbox("Use Blue Noise", useBlueNoiseArr)) {
            settings.useBlueNoise = useBlueNoiseArr;
        }

        int[] maxStepsArr = { settings.maxSteps };
        ImGui.sliderInt("Max Steps", maxStepsArr, 1, 50);
        settings.maxSteps = maxStepsArr[0];

        int[] maxVolStepsArr = { settings.maxVolumeSteps };
        ImGui.sliderInt("Max Volume Steps", maxVolStepsArr, 1, 50);
        settings.maxVolumeSteps = maxVolStepsArr[0];

        int[] maxShadowStepsArr = { settings.maxShadowMarchSteps };
        ImGui.sliderInt("Max Shadow Steps", maxShadowStepsArr, 1, 50);
        settings.maxShadowMarchSteps = maxShadowStepsArr[0];

        int[] maxLightStepsArr = { settings.maxLightMarchSteps };
        ImGui.sliderInt("Max Light Steps", maxLightStepsArr, 1, 20);
        settings.maxLightMarchSteps = maxLightStepsArr[0];

        ImGui.end();
    }


    public void renderDrawData() {
        imGuiGl3.renderDrawData(ImGui.getDrawData());
    }

}
