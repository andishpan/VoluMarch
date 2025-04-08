import imgui.ImGui;
import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
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

    private long startTime;
    private double lastFrameTime;
    private float deltaTime;


    private Material[] materials;
    private Texture    blueNoise;
    private Texture3D  noiseTexture3D;

    private boolean debugMode = true;

    private RenderSettings settings = new RenderSettings();
    private GuiController guiController;

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

        glfwSetKeyCallback(window, (win, key, scancode, action, mods) -> {
            if (action == GLFW_PRESS && key == GLFW_KEY_F1) {
                debugMode = !debugMode;
                System.out.println("Debug mode is now " + (debugMode ? "ON" : "OFF"));
            }
        });

        glfwMakeContextCurrent(window);
        glfwSwapInterval(1);
        GL.createCapabilities();

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

        String vertexShaderPath   = "vertex.glsl";
        String fragmentShaderPath = "fragment_c.glsl";
        shader = new ShaderProgram(vertexShaderPath, fragmentShaderPath);
//gui
        guiController = new GuiController(window, settings);


        glUseProgram(shader.getID());
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraPosition"),
                settings.cameraPos.x, settings.cameraPos.y, settings.cameraPos.z);
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraLookAt"),
                settings.cameraLookAt.x, settings.cameraLookAt.y, settings.cameraLookAt.z);
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraUp"),
                settings.cameraUp.x, settings.cameraUp.y, settings.cameraUp.z);
        glUseProgram(0);

        renderer = new Renderer(shader);
        // inputHandler = new InputHandler(window);

        //  textRenderer = new TextRenderer(width, height);
        // textRenderer.createTextShaders("C:\\RT\\VoluMarch\\src\\res\\shaders\\text_vertex.glsl",
        //    "C:\\RT\\VoluMarch\\src\\res\\shaders\\text_fragment.glsl");
        //  textRenderer.initFontQuad();
        // textRenderer.setUpFonts("Volumetric Rendering Example");

        blueNoise = new Texture("BayerDithering.png");
        noiseTexture3D = new Texture3D("C:\\RT\\VoluMarch\\src\\res\\shaders\\textures\\VolumeCloud.bin", 64, 64, 64);

// light,debug,water
        materials = new Material[3];


        materials[0] = new Material(
                new Vector3f(1.0f, 1.0f, 1.0f),
                new Vector3f(1.0f, 1.0f, 1.0f),
                1
        );


        materials[1] = new Material(
                new Vector3f(0.6f, 0.6f, 0.7f),
                new Vector3f(0.0f, 0.0f, 0.0f),
                0
        );


        materials[2] = new Material(
                new Vector3f(0.0f, 0.2f, 0.3f),
                new Vector3f(0.02f, 0.04f, 0.05f),
                0
        );


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


            if (debugMode) {
                guiController.newFrame();
                guiController.render(deltaTime);
            }

            float elapsedTime = (System.currentTimeMillis() - startTime) * 0.001f;
           /* float mouseX = inputHandler.getMouseX();
            float mouseY = inputHandler.getMouseY();
            boolean mouseDown = inputHandler.isMouseDown(); */
            glViewport(0, 0, width, height);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
           renderer.render(elapsedTime, width, height, settings, materials, blueNoise, noiseTexture3D);
           /* renderer.render(elapsedTime,
                    width,
                    height,
                    settings.getCameraPos(),
                    settings.getCameraLookAt(),
                    settings.getCameraUp(),
                    settings.getCurrentShape(),settings.getPreviousShape(),settings.getShapeTransition(),
                    settings.getCurrentMethod(),
                    settings.getCurrentNoise(),
                    materials,
                    blueNoise,
                    settings.getSunDirection(),
                    settings.getSunIntensity(),
                    settings.getVolumetricAbsorption(),noiseTexture3D,settings.getNoiseOctaves(),settings.getNoiseHeight(),settings.getNoiseScale(),settings.getMaxSteps(),settings.getMaxVolumeSteps(),settings.getMaxShadowMarchSteps(),settings.getMaxLightMarchSteps()
            ); */

            //textRenderer.renderFonts();

            if (debugMode) {
                ImGui.render();
                guiController.renderDrawData();
            }
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
