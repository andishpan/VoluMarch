import org.lwjgl.*;
import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import static org.lwjgl.glfw.Callbacks.*;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.system.MemoryUtil.*;

import imgui.ImGui;
import imgui.ImGuiIO;
import imgui.flag.ImGuiConfigFlags;
import imgui.flag.ImGuiBackendFlags;
import imgui.gl3.ImGuiImplGl3;
import imgui.glfw.ImGuiImplGlfw;

public class VolumeRaymarchLWJGLWithImGui {

    private long window;
    private static final int width = 1280;
    private static final int height = 720;

    private ShaderProgram shader;
    private Renderer renderer;
    private InputHandler inputHandler;
    private TextRenderer textRenderer;

    private long startTime;
    private double lastFrameTime;
    private float deltaTime;

    
    private Vector3f cameraLookAt = new Vector3f(0.0f, -0.5f, -1.0f);
    private Vector3f cameraUp     = new Vector3f(0.0f, 1.0f, 0.0f);
    private Vector3f cameraPosition = new Vector3f(0.0f, 50.0f, 0.0f);

    private Material[] materials;
    private Texture blueNoise;
    private Texture3D noiseTexture3D;

    
    private ImGuiImplGlfw imGuiGlfw = new ImGuiImplGlfw();
    private ImGuiImplGl3  imGuiGl3  = new ImGuiImplGl3();

    public static void main(String[] args) {
        new VolumeRaymarchLWJGLWithImGui().run();
    }

    public void run() {
        init();
        loop();
        cleanup();
    }

    
    
    
    private void init() {
        
        GLFWErrorCallback.createPrint(System.err).set();
        if (!glfwInit()) {
            throw new IllegalStateException("Unable to initialize GLFW");
        }

        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

        window = glfwCreateWindow(width, height, "Volume Raymarch LWJGL", NULL, NULL);
        if (window == NULL) {
            throw new RuntimeException("Failed to create GLFW window");
        }

        glfwMakeContextCurrent(window);
        glfwSwapInterval(1);
        GL.createCapabilities();

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

        
        String vertexShaderPath = "vertex.glsl";
        String fragmentShaderPath = "fragment_c.glsl";
        shader = new ShaderProgram(vertexShaderPath, fragmentShaderPath);

        glUseProgram(shader.getID());
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraPosition"),
                cameraPosition.x, cameraPosition.y, cameraPosition.z);
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraLookAt"),
                cameraLookAt.x, cameraLookAt.y, cameraLookAt.z);
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraUp"),
                cameraUp.x, cameraUp.y, cameraUp.z);
        glUseProgram(0);

        renderer = new Renderer(shader);
        inputHandler = new InputHandler(window);

        textRenderer = new TextRenderer(width, height);
        textRenderer.createTextShaders("C:\\RT\\VoluMarch\\src\\res\\shaders\\text_vertex.glsl",
                "C:\\RT\\VoluMarch\\src\\res\\shaders\\text_fragment.glsl");
        textRenderer.initFontQuad();
        textRenderer.setUpFonts("Volumetric Rendering");

        
        blueNoise = new Texture("BayerDithering.png");
        noiseTexture3D = new Texture3D("VolumeCloud.exr", 64, 64, 64);

        
        materials = new Material[2];
        materials[0] = new Material(
                new Vector3f(1.0f, 1.0f, 1.0f),
                new Vector3f(1.0f, 1.0f, 1.0f),
                1);
        materials[1] = new Material(
                new Vector3f(0.6f, 0.6f, 0.7f),
                new Vector3f(0.0f, 0.0f, 0.0f),
                0);
        Material.uploadMaterialUniforms(shader.getID(), materials);

        
        glUseProgram(shader.getID());
        noiseTexture3D.bind(1);
        glUniform1i(glGetUniformLocation(shader.getID(), "uNoiseTexture"), 1);
        glUseProgram(0);

        
        startTime = System.currentTimeMillis();
        lastFrameTime = glfwGetTime();

        setupKeyCallbacks();
        initImGui(); 
    }

    
    
    
    private void initImGui() {
        
        ImGui.createContext();

        
        ImGuiIO io = ImGui.getIO();

        io.addConfigFlags(ImGuiConfigFlags.NavEnableKeyboard); 
        io.addBackendFlags(ImGuiBackendFlags.HasMouseCursors);

        
        
        
        
        io.getFonts().addFontDefault();
        io.getFonts().build();
        

        
        imGuiGlfw.init(window, true);
        imGuiGl3.init("#version 330");
    }

    
    
    
    private void loop() {
        while (!glfwWindowShouldClose(window)) {
            double currentFrameTime = glfwGetTime();
            deltaTime = (float) (currentFrameTime - lastFrameTime);
            lastFrameTime = currentFrameTime;

            glfwPollEvents();
            handleKeyboardInput();

            
            imGuiGlfw.newFrame();
            ImGui.newFrame();

            
            glViewport(0, 0, width, height);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            float elapsedTime = (System.currentTimeMillis() - startTime) * 0.001f;
            float mouseX = inputHandler.getMouseX();
            float mouseY = inputHandler.getMouseY();
            boolean mouseDown = inputHandler.isMouseDown();

            
            Vector3f camPos = new Vector3f(
                    ParameterController.cameraX,
                    ParameterController.cameraY,
                    ParameterController.cameraZ);

            glUseProgram(shader.getID());
            int locSunIntensity = glGetUniformLocation(shader.getID(), "uSunIntensity");
            if (locSunIntensity >= 0) {
                glUniform1f(locSunIntensity, ParameterController.sunIntensity);
            }
            int locAbsorption = glGetUniformLocation(shader.getID(), "VOLUMETRIC_ABSORPTION");
            if (locAbsorption >= 0) {
                glUniform1f(locAbsorption, ParameterController.volumetricAbsorption);
            }
            int locCamera = glGetUniformLocation(shader.getID(), "uCameraPosition");
            if (locCamera >= 0) {
                glUniform3f(locCamera, camPos.x, camPos.y, camPos.z);
            }
            int locSunDir = glGetUniformLocation(shader.getID(), "uSunDirection");
            if (locSunDir >= 0) {
                glUniform3f(locSunDir,
                        ParameterController.sunDirX,
                        ParameterController.sunDirY,
                        ParameterController.sunDirZ);
            }
            int locEnableBlueNoise = glGetUniformLocation(shader.getID(), "USE_BLUE_NOISE");
            if (locEnableBlueNoise >= 0) {
                glUniform1i(locEnableBlueNoise, ParameterController.enableBlueNoise ? 1 : 0);
            }
            int locStepSize = glGetUniformLocation(shader.getID(), "STEP_SIZE");
            if (locStepSize >= 0) {
                glUniform1f(locStepSize, ParameterController.stepSize);
            }
            int locMaxSteps = glGetUniformLocation(shader.getID(), "MAX_STEPS");
            if (locMaxSteps >= 0) {
                glUniform1i(locMaxSteps, ParameterController.maxSteps);
            }
            int locShape = glGetUniformLocation(shader.getID(), "uObjectShape");
            if (locShape >= 0) {
                glUniform1i(locShape, ParameterController.shapeIndex);
            }
            int locMethod = glGetUniformLocation(shader.getID(), "uCurrentMethod");
            if (locMethod >= 0) {
                glUniform1i(locMethod, ParameterController.methodIndex);
            }
            glUseProgram(0);

            
            renderer.render(
                    elapsedTime, width, height,
                    mouseX, mouseY, mouseDown,
                    camPos, cameraLookAt, cameraUp,
                    ParameterController.shapeIndex,
                    ParameterController.methodIndex,
                    materials, blueNoise
            );

            
            textRenderer.renderFonts();

            
            buildImGuiInterface();

            
            ImGui.render();
            imGuiGl3.renderDrawData(ImGui.getDrawData());

            glfwSwapBuffers(window);
        }
    }

    
    
    
    private void buildImGuiInterface() {
        ImGui.begin("Raymarch Parameters");

        
        float[] camX = { ParameterController.cameraX };
        float[] camY = { ParameterController.cameraY };
        float[] camZ = { ParameterController.cameraZ };
        if (ImGui.dragFloat("Camera X", camX, 0.2f)) {
            ParameterController.cameraX = camX[0];
        }
        if (ImGui.dragFloat("Camera Y", camY, 0.2f)) {
            ParameterController.cameraY = camY[0];
        }
        if (ImGui.dragFloat("Camera Z", camZ, 0.2f)) {
            ParameterController.cameraZ = camZ[0];
        }

        
        float[] sunI = { ParameterController.sunIntensity };
        if (ImGui.dragFloat("Sun Intensity", sunI, 0.01f, 0f, 10f)) {
            ParameterController.sunIntensity = sunI[0];
        }
        float[] sdX = { ParameterController.sunDirX };
        float[] sdY = { ParameterController.sunDirY };
        float[] sdZ = { ParameterController.sunDirZ };
        if (ImGui.dragFloat("Sun Dir X", sdX, 0.01f)) { ParameterController.sunDirX = sdX[0]; }
        if (ImGui.dragFloat("Sun Dir Y", sdY, 0.01f)) { ParameterController.sunDirY = sdY[0]; }
        if (ImGui.dragFloat("Sun Dir Z", sdZ, 0.01f)) { ParameterController.sunDirZ = sdZ[0]; }

        
        float[] abs = { ParameterController.volumetricAbsorption };
        if (ImGui.dragFloat("Absorption", abs, 0.01f, 0f, 2f)) {
            ParameterController.volumetricAbsorption = abs[0];
        }
        float[] step = { ParameterController.stepSize };
        if (ImGui.dragFloat("Step Size", step, 0.01f, 0.1f, 2f)) {
            ParameterController.stepSize = step[0];
        }
        int[] ms = { ParameterController.maxSteps };
        if (ImGui.dragInt("Max Steps", ms, 1, 1, 200)) {
            ParameterController.maxSteps = ms[0];
        }

        
        int[] shapeVal = { ParameterController.shapeIndex };
        if (ImGui.sliderInt("Shape Index", shapeVal, 0, 3)) {
            ParameterController.shapeIndex = shapeVal[0];
        }
        int[] methodVal = { ParameterController.methodIndex };
        if (ImGui.sliderInt("Method Index", methodVal, 0, 3)) {
            ParameterController.methodIndex = methodVal[0];
        }

        
        boolean bn = ParameterController.enableBlueNoise;
        if (ImGui.checkbox("Enable BlueNoise", bn)) {
            ParameterController.enableBlueNoise = !bn;
        }

        ImGui.end();
    }

    
    
    
    private void handleKeyboardInput() {
        float camSpeed = 20.0f * deltaTime;
        if (inputHandler.isKeyPressed(GLFW_KEY_W)) {
            ParameterController.cameraZ -= camSpeed;
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_S)) {
            ParameterController.cameraZ += camSpeed;
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_A)) {
            ParameterController.cameraX -= camSpeed;
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_D)) {
            ParameterController.cameraX += camSpeed;
        }
    }

    private void setupKeyCallbacks() {
        glfwSetKeyCallback(window, (win, key, scancode, action, mods) -> {
            if (action == GLFW_PRESS) {
                switch (key) {
                    case GLFW_KEY_ESCAPE:
                        glfwSetWindowShouldClose(window, true);
                        break;
                    case GLFW_KEY_M:
                        ParameterController.shapeIndex = (ParameterController.shapeIndex + 1) % 4;
                        System.out.println("Switched to shape: " + ParameterController.shapeIndex);
                        break;
                    case GLFW_KEY_N:
                        ParameterController.shapeIndex =
                                (ParameterController.shapeIndex - 1 + 4) % 4;
                        System.out.println("Switched to shape: " + ParameterController.shapeIndex);
                        break;
                    case GLFW_KEY_O:
                        ParameterController.methodIndex =
                                (ParameterController.methodIndex + 1) % 4;
                        System.out.println("Switched to method: " + ParameterController.methodIndex);
                        break;
                }
            }
        });
    }

    
    
    
    private void cleanup() {
        shader.cleanup();
        renderer.cleanup();
        textRenderer.cleanup();
        if (blueNoise != null) {
            blueNoise.delete();
        }
        if (noiseTexture3D != null) {
            noiseTexture3D.delete();
        }

        
        disposeImGui();

        
        glfwFreeCallbacks(window);
        glfwDestroyWindow(window);
        glfwTerminate();
        glfwSetErrorCallback(null).free();
    }

    private void disposeImGui() {
        
        
        
        ImGui.destroyContext();
    }
}
