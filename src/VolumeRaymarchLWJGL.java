import imgui.ImGui;
import imgui.ImGuiIO;
import imgui.flag.ImGuiConfigFlags;
import imgui.gl3.ImGuiImplGl3;
import imgui.glfw.ImGuiImplGlfw;
import org.lwjgl.BufferUtils;
import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;

import java.nio.FloatBuffer;

import static org.lwjgl.glfw.Callbacks.glfwFreeCallbacks;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.system.MemoryUtil.*;

public class VolumeRaymarchLWJGL {
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

    // --------------------------------------------------
    // NEW: Cloud/lighting parameters that ImGui controls
    // --------------------------------------------------
    private float[] sunDirection = {-0.8f, 0.2f, -1.0f}; // X,Y,Z
    private float   sunIntensity = 1.2f;
    // This was a #define in the shader; we’ll make it a uniform so we can tweak it:
    private float   volumetricAbsorption = 0.1f;

    // The user can select which scattering method, etc.
    // Let’s say we have up to 4:
    private final String[] methodLabels = { "Single", "Multiple Octave", "Dual Octave", "Dual Lobe" };
    private int currentMethod = 0;

    private final String[] noiseLabels = { "Perlin", "Worley", "Perlin-Worley", "InigoQuilez" };
    private int currentNoise = 0;
    // Example shape selector:
    private final String[] shapeLabels = { "MixedVolume", "Sphere", "Torus", "Cube" };

    public int previousShape = 0;
    public float shapeTransition = 1.0f; // Fully transitioned at start
    private final float transitionSpeed = 1.5f; // seconds to blend

    private int currentShape = 0;

    // Existing camera positions
    private Vector3f cameraPosition = new Vector3f(0.0f, 50.0f, 20.0f);
    private Vector3f cameraLookAt   = new Vector3f(0.0f, -0.5f, -1.0f);
    private Vector3f cameraUp       = new Vector3f(0.0f, 1.0f, 0.0f);

    private ImGuiImplGlfw imGuiGlfw;
    private ImGuiImplGl3  imGuiGl3;

    private Material[] materials;
    private Texture    blueNoise;
    private Texture3D  noiseTexture3D;

    public static void main(String[] args) {
        new VolumeRaymarchLWJGL().run();
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

        String vertexShaderPath   = "vertex.glsl";
        String fragmentShaderPath = "fragment_c.glsl";
        shader = new ShaderProgram(vertexShaderPath, fragmentShaderPath);

        // ImGui Initialization
        ImGui.createContext();
        ImGuiIO io = ImGui.getIO();
        io.addConfigFlags(ImGuiConfigFlags.DockingEnable);
        io.getFonts().addFontDefault();

        imGuiGlfw = new ImGuiImplGlfw();
        imGuiGl3  = new ImGuiImplGl3();
        imGuiGlfw.init(window, true);

        imGuiGl3.init("#version 330");

        if (!ImGui.getIO().getFonts().isBuilt()) {
            System.err.println("❌ Font atlas not built!");
        } else {
            System.out.println("✅ Font atlas is ready!");
        }

        // Example: set up some initial shader uniforms
        glUseProgram(shader.getID());
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraPosition"),
                cameraPosition.x, cameraPosition.y, cameraPosition.z);
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraLookAt"),
                cameraLookAt.x, cameraLookAt.y, cameraLookAt.z);
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraUp"),
                cameraUp.x, cameraUp.y, cameraUp.z);


        glUseProgram(0);

        // Create renderer, etc.
        renderer = new Renderer(shader);
       // inputHandler = new InputHandler(window);

      //  textRenderer = new TextRenderer(width, height);
       // textRenderer.createTextShaders("C:\\RT\\VoluMarch\\src\\res\\shaders\\text_vertex.glsl",
            //    "C:\\RT\\VoluMarch\\src\\res\\shaders\\text_fragment.glsl");
      //  textRenderer.initFontQuad();
       // textRenderer.setUpFonts("Volumetric Rendering Example");

        blueNoise = new Texture("BayerDithering.png");
        noiseTexture3D = new Texture3D("C:\\RT\\VoluMarch\\src\\res\\shaders\\textures\\perlin_shader_style.bin", 64, 64, 64);


        materials = new Material[2];
        materials[0] = new Material(new Vector3f(1.0f, 1.0f, 1.0f),
                new Vector3f(1.0f, 1.0f, 1.0f), 1);
        materials[1] = new Material(new Vector3f(0.6f, 0.6f, 0.7f),
                new Vector3f(0.0f, 0.0f, 0.0f), 0);
        Material.uploadMaterialUniforms(shader.getID(), materials);


        glUseProgram(shader.getID());
        noiseTexture3D.bind(1);
        glUniform1i(glGetUniformLocation(shader.getID(), "uNoiseTexture"), 1);
        glUseProgram(0);

        startTime = System.currentTimeMillis();
        lastFrameTime = glfwGetTime();

       // setupKeyCallbacks();
    }

    private void loop() {

        while (!glfwWindowShouldClose(window)) {
            double currentFrameTime = glfwGetTime();
            deltaTime = (float) (currentFrameTime - lastFrameTime);
            lastFrameTime = currentFrameTime;

            glfwPollEvents();
          //  handleKeyboardInput();


            //  ImGui frame

            imGuiGlfw.newFrame();
            imGuiGl3.newFrame();
            ImGui.newFrame();


            ImGui.begin("Cloud Control Panel");







            if (ImGui.beginCombo("Shape", shapeLabels[currentShape])) {
                for (int i = 0; i < shapeLabels.length; i++) {
                    boolean selected = (currentShape == i);
                    if (ImGui.selectable(shapeLabels[i], selected)) {
                        if (!selected) {
                            previousShape = currentShape;
                            currentShape = i;
                            shapeTransition = 0.0f;
                        }
                    }
                    if (selected) ImGui.setItemDefaultFocus();
                }
                ImGui.endCombo();
            }

            if (shapeTransition < 1.0f) {
                shapeTransition += deltaTime * transitionSpeed;
                shapeTransition = Math.min(shapeTransition, 1.0f);
            }



            if (ImGui.beginCombo("Scattering", methodLabels[currentMethod])) {
                for (int i = 0; i < methodLabels.length; i++) {
                    boolean selected = (currentMethod == i);
                    if (ImGui.selectable(methodLabels[i], selected)) {
                        currentMethod = i;
                    }
                    if (selected) {
                        ImGui.setItemDefaultFocus();
                    }
                }
                ImGui.endCombo();
            }

//noise method
            if (ImGui.beginCombo("Noise", noiseLabels[currentNoise])) {
                for (int i = 0; i < noiseLabels.length; i++) {
                    boolean selected = (currentNoise == i);
                    if (ImGui.selectable(noiseLabels[i], selected)) {
                        currentNoise = i;
                    }
                    if (selected) {
                        ImGui.setItemDefaultFocus();
                    }
                }
                ImGui.endCombo();
            }

// Sliders
            ImGui.sliderFloat3("Sun Direction", sunDirection, -1.0f, 1.0f);


            float[] sunIntensityArr = { sunIntensity };
            ImGui.sliderFloat("Sun Intensity", sunIntensityArr, 0.0f, 5.0f);
            sunIntensity = sunIntensityArr[0];

            float[] absorptionArr = { volumetricAbsorption };
            ImGui.sliderFloat("Volumetric Absorption", absorptionArr, 0.0f, 2.0f);
            volumetricAbsorption = absorptionArr[0];

          //  System.out.println("WantCaptureMouse: " + ImGui.getIO().getWantCaptureMouse());
          //  System.out.println("WantCaptureKeyboard: " + ImGui.getIO().getWantCaptureKeyboard());

            ImGui.end();



            float elapsedTime = (System.currentTimeMillis() - startTime) * 0.001f;
           /* float mouseX = inputHandler.getMouseX();
            float mouseY = inputHandler.getMouseY();
            boolean mouseDown = inputHandler.isMouseDown(); */

            glViewport(0, 0, width, height);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);


            renderer.render(elapsedTime,
                    width,
                    height,
                    cameraPosition,
                    cameraLookAt,
                    cameraUp,
                    currentShape,previousShape,shapeTransition,
                    currentMethod,
                    currentNoise,
                    materials,
                    blueNoise,
                    sunDirection,
                    sunIntensity,
                    volumetricAbsorption,noiseTexture3D
            );


            //textRenderer.renderFonts();
            ImGui.render();
            imGuiGl3.renderDrawData(ImGui.getDrawData());

            glfwSwapBuffers(window);
        }
    }

   /* private void handleKeyboardInput() {
        float camSpeed = 20.0f * deltaTime;
        if (inputHandler.isKeyPressed(GLFW_KEY_W)) {
            cameraPosition = cameraPosition.add(new Vector3f(0, 0, -camSpeed));
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_S)) {
            cameraPosition = cameraPosition.add(new Vector3f(0, 0, camSpeed));
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_A)) {
            cameraPosition = cameraPosition.add(new Vector3f(-camSpeed, 0, 0));
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_D)) {
            cameraPosition = cameraPosition.add(new Vector3f(camSpeed, 0, 0));
        }
    } */

  /*  private void setupKeyCallbacks() {
        glfwSetKeyCallback(window, (win, key, scancode, action, mods) -> {
            if (action == GLFW_PRESS) {
                switch (key) {
                    case GLFW_KEY_M:
                        currentShape = (currentShape + 1) % shapeLabels.length;
                        System.out.println("Switched to shape: " + currentShape);
                        break;
                    case GLFW_KEY_N:
                        currentShape = (currentShape - 1 + shapeLabels.length) % shapeLabels.length;
                        System.out.println("Switched to shape: " + currentShape);
                        break;
                    case GLFW_KEY_O:
                        currentMethod = (currentMethod + 1) % methodLabels.length;
                        System.out.println("Switched to method: " + currentMethod);
                        break;
                }
            }
        });
    } */

    private void cleanup() {
        shader.cleanup();
        renderer.cleanup();
        //textRenderer.cleanup();
        if (blueNoise != null) {
            blueNoise.delete();
        }
        if (noiseTexture3D != null) {
            noiseTexture3D.delete();
        }
        glfwFreeCallbacks(window);
        glfwDestroyWindow(window);
        glfwTerminate();
       // glfwSetErrorCallback(null).free();
    }
}
