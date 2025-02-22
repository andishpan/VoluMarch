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

public class VolumeRaymarchLWJGL {

    private long window;
    private static int width = 1280;
    private static int height = 720;

    private int programID;
    private int vaoID;

    // Locations of uniforms
    private int iResolutionLoc;
    private int iTimeLoc;
    private int iMouseLoc;
    private int iChannel0Loc;

    // New uniform locations for camera
    private int uCameraPositionLoc;
    private int uCameraLookAtLoc;
    private int uLensHeightLoc;
    private int uFocalDistanceLoc;

    // Uniform locations for light parameters
    private int uLightPositionLoc;
    private int uLightColorLoc;
    private int uLightRadiusLoc;


    // Uniform location for view matrix
    private int uViewMatrixLoc;


    private long startTime;
    private float mouseX = 0.0f, mouseY = 0.0f;
    private boolean mouseDown = false;
    private Texture skyTexture;

    private int currentShape = 0; // sphere,rounded box, torus
    private final int maxShapes = 4;
    private int currentMethod = 0;
    private final int maxMethods= 2;

private int NUM_MATERIALS = 2;
private Material[] materials;



    private static final String VERTEX_SHADER_PATH   = "C:\\RT\\Cloud\\src\\res\\shaders\\vertex.glsl";
    private static final String FRAGMENT_SHADER_PATH = "C:\\RT\\Cloud\\src\\res\\shaders\\fragment.glsl";



    private Vector3f cameraPosition = new Vector3f(0.0f, 30.0f, 40.0f);




    private Vector3f cameraLookAt    = new Vector3f(20.0f, 10.0f, 0.0f);
    private Vector3f cameraUp        = new Vector3f(0.0f, 1.0f, 0.0f);
    private float lensHeight = 2.0f;
    private float focalDistance = 7.0f;

    // Movement parameters
    private float cameraSpeed = 20.0f; // Units per second
    private Vector3f cameraFront = new Vector3f(0.0f, 0.0f, -1.0f); // Initial front vector
    private Vector3f cameraRight = new Vector3f(1.0f, 0.0f, 0.0f);
    private Vector3f cameraUpDirection = new Vector3f(0.0f, 1.0f, 0.0f);
    // Timing
    private double lastFrameTime = 0.0;
    private float deltaTime = 0.0f;


    private Vector3f lightPosition = new Vector3f(0.0f, 60.0f, 0.0f); // Initial position
    private Vector3f lightColor    = new Vector3f(1.0f, 1.0f, 1.0f);
    private float lightRadius      = 5.0f;
    private float lightIntensity = 250.0f;
    private FloatBuffer orthoBuffer = BufferUtils.createFloatBuffer(16);
    private int fontTextureID;
    private int textProgramID;
    private int textVaoID;
    private int textVboID;
    private Matrix4 orthoProjection;

    private int  vboID;

    private void createTextShaders() {
        String vertexCode = loadFileAsString("C:\\RT\\Cloud\\src\\res\\shaders\\text_vertex.glsl");
        String fragmentCode = loadFileAsString("C:\\RT\\Cloud\\src\\res\\shaders\\text_fragment.glsl");

        int vertexShader = compileShader(vertexCode, GL_VERTEX_SHADER);
        int fragmentShader = compileShader(fragmentCode, GL_FRAGMENT_SHADER);

        textProgramID = glCreateProgram();
        glAttachShader(textProgramID, vertexShader);
        glAttachShader(textProgramID, fragmentShader);
        glLinkProgram(textProgramID);

        // Check for linking errors
        int success = glGetProgrami(textProgramID, GL_LINK_STATUS);
        if (success == GL_FALSE) {
            String infoLog = glGetProgramInfoLog(textProgramID);
            throw new RuntimeException("Failed to link text shader program:\n" + infoLog);
        }

        // Cleanup
        glDetachShader(textProgramID, vertexShader);
        glDetachShader(textProgramID, fragmentShader);
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
    }
    public static void main(String[] args) {
        new VolumeRaymarchLWJGL().run();
    }

    public void run() {
        init();
        loop();
        cleanup();
    }

    private void setupOrthographicProjection() {
        // Define the orthographic projection boundaries based on window size
        float left = 0.0f;
        float right = (float) width;
        float bottom = (float) height; // Set bottom to window height
        float top = 0.0f;              // Set top to 0

        // Create the orthographic projection matrix with flipped Y-axis
        orthoProjection = Matrix4.ortho2D(left, right, bottom, top);

        // Allocate the FloatBuffer
        orthoBuffer = BufferUtils.createFloatBuffer(16);

        // Populate the buffer with the matrix data
        orthoProjection.get(orthoBuffer);
    }


    private void init() {
        GLFWErrorCallback.createPrint(System.err).set();
        if (!glfwInit()) {
            throw new IllegalStateException("Unable to initialize GLFW");
        }

        // Request a 24-bit depth buffer
        glfwWindowHint(GLFW_DEPTH_BITS, 24);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

        window = glfwCreateWindow(width, height, "Volume Raymarch LWJGL", NULL, NULL);
        if (window == NULL) {
            throw new RuntimeException("Failed to create the GLFW window");
        }

        glfwMakeContextCurrent(window);
        glfwSwapInterval(1);
        GL.createCapabilities();

        // Enable depth testing and blending
       // glEnable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
       glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

    // Create the view matrix
        Matrix4 viewMatrix = Matrix4.lookAt(cameraPosition, cameraLookAt, cameraUp);

        // Load the skydome texture
        skyTexture = new Texture("Sky.jpg");


        // Initialize key callbacks once
        setupKeyCallbacks();

        // Mouse callbacks
        glfwSetCursorPosCallback(window, (win, xpos, ypos) -> {
            mouseX = (float)xpos;
            mouseY = (float)(height - ypos); // invert y
        });
        glfwSetMouseButtonCallback(window, (win, button, action, mods) -> {
            if (button == GLFW_MOUSE_BUTTON_LEFT) {
                mouseDown = (action == GLFW_PRESS);
            }
        });

         materials = new Material[NUM_MATERIALS];

        // Initialize all materials explicitly
        materials[0] = new Material(new Vector3f(1.0f, 1.0f, 1.0f), new Vector3f(1.0f, 1.0f, 1.0f), 1); // Lamp material (flagged as light source)
        materials[1] = new Material(new Vector3f(0.6f, 0.6f, 0.7f), new Vector3f(0.0f, 0.0f, 0.0f), 0); // Debug material






        createShaders();
        createTextShaders();
        // Setup projection matrices
        setupOrthographicProjection();

        // Initialize 3D quad
        createQuad();

        // Initialize font quad
        initFontQuad();
        //initFontTexture();
        Material.uploadMaterialUniforms(programID, materials);


        setUpFonts("Welcome");

        // Uniform locations
        iResolutionLoc = glGetUniformLocation(programID, "iResolution");
        iTimeLoc       = glGetUniformLocation(programID, "iTime");
        iMouseLoc      = glGetUniformLocation(programID, "iMouse");
        iChannel0Loc   = glGetUniformLocation(programID, "iChannel0");

        // Get uniform locations for camera parameters
        uCameraPositionLoc = glGetUniformLocation(programID, "uCameraPosition");
        uCameraLookAtLoc    = glGetUniformLocation(programID, "uCameraLookAt");
        uLensHeightLoc      = glGetUniformLocation(programID, "uLensHeight");
        uFocalDistanceLoc   = glGetUniformLocation(programID, "uFocalDistance");
        uViewMatrixLoc = glGetUniformLocation(programID, "uViewMatrix");


        // light uniforms
        uLightPositionLoc = glGetUniformLocation(programID, "uLightPosition");



        uLightColorLoc    = glGetUniformLocation(programID, "uLightColor");
        uLightRadiusLoc   = glGetUniformLocation(programID, "uLightRadius");



        startTime = System.currentTimeMillis();

        // Set initial camera parameters and view matrix
        glUseProgram(programID);

// Camera parameters
        glUniform3f(uCameraPositionLoc, cameraPosition.x, cameraPosition.y, cameraPosition.z);
        glUniform3f(uCameraLookAtLoc, cameraLookAt.x, cameraLookAt.y, cameraLookAt.z);
        glUniform1f(uLensHeightLoc, lensHeight);
        glUniform1f(uFocalDistanceLoc, focalDistance);

// View matrix
        float[] viewMatrixArray = viewMatrix.getValuesAsArray();
        glUniformMatrix4fv(uViewMatrixLoc, false, viewMatrixArray);

        // Set initial light uniforms
        glUniform3f(uLightPositionLoc, lightPosition.x, lightPosition.y, lightPosition.z);
        Vector3f scaledLightColor = lightColor.multiply(lightIntensity);
        glUniform3f(uLightColorLoc, scaledLightColor.x, scaledLightColor.y, scaledLightColor.z);
        glUniform1f(uLightRadiusLoc, lightRadius);

        glUseProgram(0);



    }

    private void renderFonts() {
        glUseProgram(textProgramID);

        // Set the projection matrix
        orthoProjection.get(orthoBuffer);
        // **Remove the following line to prevent double flipping**
        // orthoBuffer.flip();

        int projectionLoc = glGetUniformLocation(textProgramID, "projection");
        glUniformMatrix4fv(projectionLoc, false, orthoBuffer);


        int textColorLoc = glGetUniformLocation(textProgramID, "textColor");
        glUniform3f(textColorLoc, 0.0f, 0.0f, 1.0f);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, fontTextureID);
        int samplerLoc = glGetUniformLocation(textProgramID, "textTexture");
        glUniform1i(samplerLoc, 0);

        glBindVertexArray(textVaoID);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        glBindVertexArray(0);

        glBindTexture(GL_TEXTURE_2D, 0);
        glUseProgram(0);
    }



    private void initFontQuad() {
        float[] vertices = {
                // Positions   // Texture Coords
                10.0f,  10.0f,  0.0f, 0.0f, // Bottom-left
                266.0f, 10.0f,  1.0f, 0.0f, // Bottom-right
                266.0f, 266.0f, 1.0f, 1.0f, // Top-right
                10.0f,  266.0f, 0.0f, 1.0f  // Top-left
        };

        textVaoID = glGenVertexArrays();
        textVboID = glGenBuffers();
        glBindVertexArray(textVaoID);

        glBindBuffer(GL_ARRAY_BUFFER, textVboID);
        glBufferData(GL_ARRAY_BUFFER, vertices, GL_STATIC_DRAW);

        // Position attribute
        glVertexAttribPointer(0, 2, GL_FLOAT, false, 4 * Float.BYTES, 0);
        glEnableVertexAttribArray(0);

        // Texture coordinate attribute
        glVertexAttribPointer(1, 2, GL_FLOAT, false, 4 * Float.BYTES, 2 * Float.BYTES);
        glEnableVertexAttribArray(1);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }



    private void setUpFonts(String text) {
        Font font = new Font("Times New Roman", Font.BOLD, 24);
        BufferedImage fontImage = new BufferedImage(256, 256, BufferedImage.TYPE_INT_ARGB);
        Graphics2D graphics = fontImage.createGraphics();

        graphics.setFont(font);
        graphics.drawString(text, 10, 50);
        graphics.dispose();

        int[] pixels = fontImage.getRGB(0, 0, fontImage.getWidth(), fontImage.getHeight(), null, 0, fontImage.getWidth());
        ByteBuffer buffer = BufferUtils.createByteBuffer(fontImage.getWidth() * fontImage.getHeight() * 4);

        for (int y = 0; y < fontImage.getHeight(); y++) {
            for (int x = 0; x < fontImage.getWidth(); x++) {
                int pixel = pixels[y * fontImage.getWidth() + x];
                buffer.put((byte) ((pixel >> 16) & 0xFF)); // Red
                buffer.put((byte) ((pixel >> 8) & 0xFF));  // Green
                buffer.put((byte) (pixel & 0xFF));         // Blue
                buffer.put((byte) ((pixel >> 24) & 0xFF)); // Alpha
            }
        }

        buffer.flip();

        fontTextureID = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, fontTextureID);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fontImage.getWidth(), fontImage.getHeight(), 0, GL_RGBA, GL_UNSIGNED_BYTE, buffer);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        glBindTexture(GL_TEXTURE_2D, 0);
    }


    private void loop() {

        lastFrameTime = glfwGetTime();

        while (!glfwWindowShouldClose(window)) {
            double currentFrameTime = glfwGetTime();
            deltaTime = (float)(currentFrameTime - lastFrameTime);
            lastFrameTime = currentFrameTime;

            glfwPollEvents();

            handleKeyboardInput();
            // Update the view matrix based on camera movement
            updateViewMatrix();


            glViewport(0, 0, width, height);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT); // Clear depth buffer if used

            // Use the main shader program for 3D rendering
            glUseProgram(programID);

            // Update uniform variables
            glUniform1i(glGetUniformLocation(programID, "uObjectShape"), currentShape);
            glUniform1i(glGetUniformLocation(programID, "uCurrentMethod"), currentMethod);

            // Upload material data
            Material.uploadMaterialUniforms(programID, materials);

            float elapsedTime = (System.currentTimeMillis() - startTime) * 0.001f;
            glUniform1f(iTimeLoc, elapsedTime);
            glUniform3f(iResolutionLoc, (float) width, (float) height, 1.0f);




            // iMouse: (x, y, 0, 0) if pressed, else all 0
            float mx = mouseDown ? mouseX : 0.0f;
            float my = mouseDown ? mouseY : 0.0f;
            glUniform4f(iMouseLoc, mx, my, 0.0f, 0.0f);

            // Bind the main sky texture to texture unit 0
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, skyTexture.getId());

            // Set the sampler uniform (iChannel0 = 0)
            glUniform1i(iChannel0Loc, 0);

            // Update the view matrix based on camera movement
            // Example: Rotate around Y-axis based on mouse X
            float rotationAngle = (mx / width - 0.5f) * (float) Math.PI * 0.4f; // Adjust rotation speed as needed

            // Create rotated camera position
            float cosAngle = (float) Math.cos(rotationAngle);
            float sinAngle = (float) Math.sin(rotationAngle);
            Vector3f rotatedPosition = new Vector3f(
                    cameraPosition.x * cosAngle - cameraPosition.z * sinAngle,
                    cameraPosition.y,
                    cameraPosition.x * sinAngle + cameraPosition.z * cosAngle
            );

            // Recreate the view matrix with the rotated position
            Matrix4 viewMatrix = Matrix4.lookAt(rotatedPosition, cameraLookAt, cameraUp);

            // Send the updated view matrix to the shader
            float[] viewMatrixArray = viewMatrix.getValuesAsArray();
            glUniformMatrix4fv(uViewMatrixLoc, false, viewMatrixArray);

            // Render fullscreen quad for 3D scene
            glBindVertexArray(vaoID);
            glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
            glBindVertexArray(0);

            // Unbind the main shader program after 3D rendering
            glUseProgram(0);

            glViewport(0, 0, width, height);
           // glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            renderFonts();
            glfwSwapBuffers(window);
        }
    }

    private void updateViewMatrix() {
        // Recompute the view matrix with the updated camera position
        Matrix4 viewMatrix = Matrix4.lookAt(cameraPosition, cameraLookAt, cameraUpDirection);

        // Send the updated view matrix to the shader
        glUseProgram(programID);
        float[] viewMatrixArray = viewMatrix.getValuesAsArray();
        glUniformMatrix4fv(uViewMatrixLoc, false, viewMatrixArray);
        glUseProgram(0);
    }




    private void handleKeyboardInput() {
        // Forward (W)
        if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) {
            cameraPosition = cameraPosition.add(cameraFront.multiply(cameraSpeed * deltaTime));
        }
        // Backward (S)
        if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) {
            cameraPosition = cameraPosition.subtract(cameraFront.multiply(cameraSpeed * deltaTime));
        }
        // Left (A)
        if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS) {
            cameraPosition = cameraPosition.subtract(cameraRight.multiply(cameraSpeed * deltaTime));
        }
        // Right (D)
        if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) {
            cameraPosition = cameraPosition.add(cameraRight.multiply(cameraSpeed * deltaTime));
        }
    }


    private void setupKeyCallbacks() {
        glfwSetKeyCallback(window, (win, key, scancode, action, mods) -> {
            if (action == GLFW_PRESS) {
                switch (key) {
                    case GLFW_KEY_M -> {
                        currentShape = (currentShape + 1) % maxShapes; // Cycle through modes
                        System.out.println("Switched to mode: " + currentShape);
                    }
                    case GLFW_KEY_N -> {
                        currentShape = (currentShape - 1 + maxShapes) % maxShapes; // Cycle backward
                        System.out.println("Switched to mode: " + currentShape);
                    }
                    case GLFW_KEY_O -> {



                        currentMethod = (currentMethod + 1) % maxMethods; // Cycle through modes
                        System.out.println("Switched to method: " + currentMethod);

                        if(currentMethod == 0){
                            setUpFonts("Beer-Lambert");
                        }else if(currentMethod == 1){
                            setUpFonts("Multiple Octave Scattering");
                        }

                    }
                   /* case GLFW_KEY_L -> {
                        setUpFonts("Beer-Lambert");
                        currentMethod = (currentMethod - 1 + maxMethods) % maxMethods; // Cycle backward
                        System.out.println("Switched to method: " + currentMethod);

                    } */
                }
            }
        });
    }

    private static FloatBuffer reserveData(int size){
        FloatBuffer data = BufferUtils.createFloatBuffer(size);

                return data;
    }



    private void cleanup() {
        if (skyTexture != null) {
            skyTexture.delete();
        }

        glDeleteTextures(fontTextureID);
        glDeleteProgram(programID);
        glDeleteProgram(textProgramID);
        glDeleteVertexArrays(vaoID);
        glDeleteVertexArrays(textVaoID);
        glDeleteBuffers(vboID);
        glDeleteBuffers(textVboID);
        glfwFreeCallbacks(window);
        glfwDestroyWindow(window);
        glfwTerminate();
        glfwSetErrorCallback(null).free();
    }




    /**
     * Load, compile, and link the vertex + fragment shaders from files.
     */
    private void createShaders() {
        // Read the shader sources from disk
        String vertexCode   = loadFileAsString(VERTEX_SHADER_PATH);
        String fragmentCode = loadFileAsString(FRAGMENT_SHADER_PATH);

        // Compile each shader
        int vertexShaderID   = compileShader(vertexCode, GL_VERTEX_SHADER);
        int fragmentShaderID = compileShader(fragmentCode, GL_FRAGMENT_SHADER);

        // Link into a single program
        programID = glCreateProgram();
        glAttachShader(programID, vertexShaderID);
        glAttachShader(programID, fragmentShaderID);
        glLinkProgram(programID);

        // Check for linking errors
        int success = glGetProgrami(programID, GL_LINK_STATUS);
        if (success == GL_FALSE) {
            String infoLog = glGetProgramInfoLog(programID);
            throw new RuntimeException("Failed to link shader program:\n" + infoLog);
        }

        // We can detach & delete once linked
        glDetachShader(programID, vertexShaderID);
        glDetachShader(programID, fragmentShaderID);
        glDeleteShader(vertexShaderID);
        glDeleteShader(fragmentShaderID);
    }

    /**
     * Compiles a shader from source.
     */
    private int compileShader(String source, int type) {
        int shaderID = glCreateShader(type);
        glShaderSource(shaderID, source);
        glCompileShader(shaderID);

        int success = glGetShaderi(shaderID, GL_COMPILE_STATUS);
        if (success == GL_FALSE) {
            String infoLog = glGetShaderInfoLog(shaderID);
            throw new RuntimeException("Shader compilation failed:\n" + infoLog);
        }

        return shaderID;
    }

    /**
     * Reads a text file's entire content into a single String.
     */
    private String loadFileAsString(String filepath) {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new FileReader(filepath))) {
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line).append("\n");
            }
        } catch (IOException e) {
            throw new RuntimeException("Failed to load shader file: " + filepath, e);
        }
        return sb.toString();
    }

    /**
     * Create a simple full-screen quad (two triangles).
     */
    private void createQuad() {
        // Full-screen quad coordinates
        float[] vertices = {
                -1.0f, -1.0f, 0.0f,
                1.0f, -1.0f, 0.0f,
                1.0f,  1.0f, 0.0f,
                -1.0f,  1.0f, 0.0f
        };

        int[] indices = {
                0, 1, 2,
                2, 3, 0
        };

        vaoID = glGenVertexArrays();
        glBindVertexArray(vaoID);

        // VBO
        int vboID = glGenBuffers();
        glBindBuffer(GL_ARRAY_BUFFER, vboID);
        ByteBuffer vbb = org.lwjgl.BufferUtils.createByteBuffer(vertices.length * 4);
        vbb.asFloatBuffer().put(vertices).flip();
        glBufferData(GL_ARRAY_BUFFER, vbb, GL_STATIC_DRAW);

        // EBO
        int eboID = glGenBuffers();
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eboID);
        IntBuffer ib = org.lwjgl.BufferUtils.createIntBuffer(indices.length);
        ib.put(indices).flip();
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, ib, GL_STATIC_DRAW);

        // Position attribute
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(
                0, 3, GL_FLOAT, false,
                3 * 4, 0L
        );

        glBindVertexArray(0);
    }
}
