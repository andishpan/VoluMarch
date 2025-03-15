import org.lwjgl.BufferUtils;
import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import org.newdawn.slick.SlickException;
import org.newdawn.slick.UnicodeFont;
import org.newdawn.slick.font.effects.ColorEffect;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.awt.image.DataBufferByte;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;

import static org.lwjgl.glfw.Callbacks.glfwFreeCallbacks;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.ARBVertexArrayObject.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.system.MemoryUtil.*;

import java.io.*;
import java.text.DecimalFormat;

import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.system.MemoryUtil.*;

import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.system.MemoryUtil.*;

import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.system.MemoryUtil.*;

public class VolumeRaymarchLWJGL {
    private long window;
    private static final int width = 1280;
    private static final int height = 720;

    // Refactored helper classes.
    private ShaderProgram shader;
    private Renderer renderer;
    private InputHandler inputHandler;
    private TextRenderer textRenderer;

    // Timing.
    private long startTime;
    private double lastFrameTime;
    private float deltaTime;

    // Camera variables.
    private Vector3f cameraPosition = new Vector3f(0.0f, 30.0f, 40.0f);
    private Vector3f cameraLookAt   = new Vector3f(20.0f, 10.0f, 0.0f);
    private Vector3f cameraUp       = new Vector3f(0.0f, 1.0f, 0.0f);

    // Additional rendering parameters.
    private int currentShape = 0;
    private int currentMethod = 0;
    private Material[] materials;
    private Texture skyTexture;

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

        // Initialize shader program.
        String vertexShaderPath = "vertex.glsl";
        String fragmentShaderPath = "beer-lambert.glsl";
        shader = new ShaderProgram(vertexShaderPath, fragmentShaderPath);

        // Set initial camera uniforms.
        glUseProgram(shader.getID());
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraPosition"),
                cameraPosition.x, cameraPosition.y, cameraPosition.z);
        glUniform3f(glGetUniformLocation(shader.getID(), "uCameraLookAt"),
                cameraLookAt.x, cameraLookAt.y, cameraLookAt.z);
        glUniform1f(glGetUniformLocation(shader.getID(), "uLensHeight"), 2.0f);
        glUniform1f(glGetUniformLocation(shader.getID(), "uFocalDistance"), 7.0f);

        // Set light uniforms.
        Vector3f scaledLightColor = new Vector3f(1.0f, 1.0f, 1.0f).multiply(250.0f);
        glUniform3f(glGetUniformLocation(shader.getID(), "uLightPosition"), 0.0f, 60.0f, 0.0f);
        glUniform3f(glGetUniformLocation(shader.getID(), "uLightColor"),
                scaledLightColor.x, scaledLightColor.y, scaledLightColor.z);
        glUniform1f(glGetUniformLocation(shader.getID(), "uLightRadius"), 5.0f);
        glUseProgram(0);

        // Initialize renderer.
        renderer = new Renderer(shader);

        // Initialize input handler.
        inputHandler = new InputHandler(window);

        // Initialize text renderer.
        textRenderer = new TextRenderer(width, height);
        textRenderer.createTextShaders("C:\\RT\\VoluMarch\\src\\res\\shaders\\text_vertex.glsl",
                "C:\\RT\\VoluMarch\\src\\res\\shaders\\text_fragment.glsl");
        textRenderer.initFontQuad();
        textRenderer.setUpFonts("Welcome");

        // Load the sky texture.
        skyTexture = new Texture("Sky.jpg");

        // Initialize materials.
        materials = new Material[2];
        materials[0] = new Material(new Vector3f(1.0f, 1.0f, 1.0f),
                new Vector3f(1.0f, 1.0f, 1.0f), 1);
        materials[1] = new Material(new Vector3f(0.6f, 0.6f, 0.7f),
                new Vector3f(0.0f, 0.0f, 0.0f), 0);
        Material.uploadMaterialUniforms(shader.getID(), materials);

        startTime = System.currentTimeMillis();
        lastFrameTime = glfwGetTime();

        // Setup key callbacks.
        setupKeyCallbacks();

        // (Mouse callbacks are handled by InputHandler.)
    }

    private void loop() {
        while (!glfwWindowShouldClose(window)) {
            double currentFrameTime = glfwGetTime();
            deltaTime = (float)(currentFrameTime - lastFrameTime);
            lastFrameTime = currentFrameTime;
            glfwPollEvents();

            handleKeyboardInput();

            // Compute elapsed time.
            float elapsedTime = (System.currentTimeMillis() - startTime) * 0.001f;
            float mouseX = inputHandler.getMouseX();
            float mouseY = inputHandler.getMouseY();
            boolean mouseDown = inputHandler.isMouseDown();

            glViewport(0, 0, width, height);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            // Render the 3D scene using our new renderer method (which sets all uniforms as before).
            renderer.render(elapsedTime, width, height,
                    mouseX, mouseY, mouseDown,
                    cameraPosition, cameraLookAt, cameraUp,
                    currentShape, currentMethod, materials, skyTexture);

            // Render overlay text.
            textRenderer.renderFonts();

            glfwSwapBuffers(window);
        }
    }

    private void handleKeyboardInput() {
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
    }

    private void setupKeyCallbacks() {
        glfwSetKeyCallback(window, (win, key, scancode, action, mods) -> {
            if (action == GLFW_PRESS) {
                switch (key) {
                    case GLFW_KEY_M:
                        currentShape = (currentShape + 1) % 4;
                        System.out.println("Switched to shape: " + currentShape);
                        break;
                    case GLFW_KEY_N:
                        currentShape = (currentShape - 1 + 4) % 4;
                        System.out.println("Switched to shape: " + currentShape);
                        break;
                    case GLFW_KEY_O:
                        currentMethod = (currentMethod + 1) % 2;
                        System.out.println("Switched to method: " + currentMethod);
                        break;
                }
            }
        });
    }

    private void cleanup() {
        shader.cleanup();
        renderer.cleanup();
        textRenderer.cleanup();
        if (skyTexture != null) {
            skyTexture.delete();
        }
        glfwFreeCallbacks(window);
        glfwDestroyWindow(window);
        glfwTerminate();
        glfwSetErrorCallback(null).free();
    }
}



