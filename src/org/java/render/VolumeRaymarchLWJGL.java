package org.java.render;

import imgui.ImGui;
import org.java.performance.FrameBench;
import org.java.performance.GpuTimer;
import org.java.performance.SystemInfoLogger;
import org.lwjgl.BufferUtils;
import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import org.lwjgl.stb.STBImageWrite;
import org.java.utility.*;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

import static org.lwjgl.glfw.Callbacks.glfwFreeCallbacks;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL30.*;
import static org.lwjgl.opengl.GL30C.GL_RGBA32UI;
import static org.lwjgl.opengl.GL30C.GL_RGBA_INTEGER;
import static org.lwjgl.system.MemoryUtil.*;



public class VolumeRaymarchLWJGL {

    private long window;
    private static final int width = 1280;
    private static final int height = 720;

    ShaderProgram shader;
    private ShaderProgram methodsShader;
    Renderer renderer;

    private int maskTexture;
    private long startTime;
    private double lastFrameTime;
    private float deltaTime;

    private int lastNoiseIndex = -1;
    private int lastMethodIndex = -1;
    private ShaderProgram[] noiseShaders;
    private ShaderProgram[] methodShaders;
    private boolean testing = true;
    private boolean debugMode = false;

   private FrameBench bench = new FrameBench();
    private GpuTimer gpuTimer;


    ShaderProgram[][] combinedShaders;
    String[] methodVariants;



    Material[] materials;
    Texture blueNoise;
    Texture3D noiseTexture3D;

    private ByteBuffer rgbBuffer;
    private Path frameDir;
    private Path maskDir;
    RenderSettings settings = new RenderSettings();
    private GuiController guiController;

    private int fbo;
    private int colorTexture;
    private int stepsTexture;
    private IntBuffer stepBuffer;


    private boolean saveColorPngs = false;
    private boolean saveMaskPngs  = false;

    private final int[] pbo = new int[2];
    private int pboIdx = 0;



    public static void main(String[] args) throws IOException {
        new VolumeRaymarchLWJGL().run();
    }

    public void run() throws IOException {
        init();
        loop();
        cleanup();
    }

    void init() throws IOException {
        GLFWErrorCallback.createPrint(System.err).set();
        if (!glfwInit()) {
            throw new IllegalStateException("Unable to initialize GLFW");
        }

        if(settings.isReferenceMode()){
            setHighQuality();
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

        glfwSwapInterval(0);
        GL.createCapabilities();
        initPbos();
        createMeasurementFbo();
        gpuTimer = new GpuTimer();

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

        String vertexShaderPath   = "vertex.glsl";
        String fragmentShaderPath = "fragment_c.glsl";
       // shader = new Rendering.ShaderProgram(vertexShaderPath, fragmentShaderPath);

        rgbBuffer = BufferUtils.createByteBuffer(width * height * 3);

        settings.setReferenceMode(false);
        String ts = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss")
                .format(LocalDateTime.now());
        if (settings.isReferenceMode()) {
            frameDir = Paths.get("results", "reference");
        } else {
            frameDir = Paths.get("results", "frames");
        }

        if (settings.isReferenceMode()) {
            maskDir = Paths.get("results", "referenceMask");
        } else {
            maskDir = Paths.get("results", "framesMask");
        }

       // frameDir  = Paths.get("results", "frames_" + ts);
        Files.createDirectories(frameDir);
//gui
        guiController = new GuiController(window, settings);


        initShaders();


        int m = settings.getCurrentMethod();
        int n = settings.getCurrentNoise();
        shader = combinedShaders[m][n];



        renderer = new Renderer(shader);

        // inputHandler = new java.util.InputHandler(window);

        //  textRenderer = new java.org.java.render.TextRenderer(width, height);
        // textRenderer.createTextShaders("C:\\RT\\VoluMarch\\src\\res\\shaders\\text_vertex.glsl",
        //    "C:\\RT\\VoluMarch\\src\\res\\shaders\\text_fragment.glsl");
        //  textRenderer.initFontQuad();
        // textRenderer.setUpFonts("Volumetric Rendering Example");

        blueNoise = new Texture("BayerDithering.png");
        noiseTexture3D = new Texture3D("C:\\RT\\VoluMarch\\src\\res\\shaders\\textures\\noise\\ridged.bin", 256, 256, 256);

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



        String vramLine = GpuMemoryInfo.query();
        System.out.println(vramLine);
        SystemInfoLogger.logLine("results/system_info.txt", vramLine);

        /*glUseProgram(shader.getID());
        noiseTexture3D.bind(1);
        glUseProgram(0); */

        startTime = System.currentTimeMillis();
        lastFrameTime = glfwGetTime();

        // setupKeyCallbacks();
    }

    private void initShaders() {
        String[] noiseVariants = {
                "noise/noise_perlin.glsl",
               "noise/noise_inigo.glsl",
                "noise/noise_perlin_worley.glsl",
                "noise/noise_worley.glsl",
                "noise/noise_precomputed.glsl",
                "noise/noise_fbm3D.glsl"
        };

 methodVariants = new String[]{
         "test/backward_test.glsl",
//                "models/beer_lambert.glsl",
//              "models/beer_lambert_pure.glsl",
//               "models/powder.glsl",
//                "models/MOS.glsl",
//                "models/MOS_8.glsl",
//               "models/forward.glsl",
//                "models/backward.glsl",
//                "models/in_out_scatteringx3.glsl",
                //"models/fire.glsl"
 };


        combinedShaders = new ShaderProgram[methodVariants.length][noiseVariants.length];

        for (int m = 0; m < methodVariants.length; ++m) {
            for (int n = 0; n < noiseVariants.length; ++n) {
                combinedShaders[m][n] = new ShaderProgram(
                        "main/vertex.glsl",
                        "main/fragment_test.glsl",
//                        "main/fragment_base.glsl",
                        noiseVariants[n],
                        methodVariants[m]
                );
            }
        }


        int m0 = settings.getCurrentMethod();
        int n0 = settings.getCurrentNoise();
        shader = combinedShaders[m0][n0];
    }



    private void loop() throws IOException {
        int frameIndex = 0;
        final long start = System.nanoTime();
        while (!glfwWindowShouldClose(window)) {
            if (testing) {
                if (System.nanoTime() - start > 60_000_000_000L) {
                    System.out.println("Timed run complete – closing.");
                    SystemInfoLogger.log("results\\system_info.txt");
                    glfwSetWindowShouldClose(window, true);
                }
                gpuTimer.nextFrame();
                gpuTimer.begin();
                glBindFramebuffer(GL_FRAMEBUFFER, fbo);
                glViewport(0, 0, width, height);
                glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            }

            double currentFrameTime = glfwGetTime();
            deltaTime = (float) (currentFrameTime - lastFrameTime);
            lastFrameTime = currentFrameTime;
            glfwPollEvents();

            if (debugMode) {
                guiController.newFrame();
                guiController.render(deltaTime);
            }

            float elapsedTime = (System.currentTimeMillis() - startTime) * 0.001f;

            int m = settings.getCurrentMethod();
            int n = settings.getCurrentNoise();
            ShaderProgram want = combinedShaders[m][n];
            if (want != shader) {
                shader = want;
                renderer.setShader(shader);
            }

            glViewport(0, 0, width, height);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            renderer.render(elapsedTime, width, height, settings, materials, blueNoise, noiseTexture3D);

            if (testing) {
                gpuTimer.end();


                glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
                glReadBuffer(GL_COLOR_ATTACHMENT1);
                glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo[pboIdx]);
                glReadPixels(0, 0, width, height, GL_RGBA_INTEGER, GL_UNSIGNED_INT, 0);
                glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);

                glBindFramebuffer(GL_FRAMEBUFFER, fbo);
                glReadBuffer(GL_COLOR_ATTACHMENT2);
                FloatBuffer maskBuffer = BufferUtils.createFloatBuffer(width * height);
                glReadPixels(0, 0, width, height, GL_RED, GL_FLOAT, maskBuffer);

                int prev = pboIdx ^ 1;
                glBindBuffer(GL_PIXEL_PACK_BUFFER, pbo[prev]);
                IntBuffer data = glMapBuffer(GL_PIXEL_PACK_BUFFER, GL_READ_ONLY).asIntBuffer();
                long primary = 0, shadow = 0, sdf = 0, bounce = 0;
                int pixelsCov = 0;
                if (data != null) {
                    stepBuffer.clear();
                    stepBuffer.put(data);
                    stepBuffer.flip();
                    glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
                    for (int i = 0; i < width * height; ++i) {
                        int pPrim = stepBuffer.get(i * 4);
                        int pShad = stepBuffer.get(i * 4 + 1);
                        int pSdf = stepBuffer.get(i * 4 + 2);
//                        int pBnc = stepBuffer.get(i * 4 + 3);
                        primary += pPrim;
                        shadow += pShad;
                        sdf += pSdf;
//                        bounce += pBnc;
//                        if (pPrim + pShad + pSdf + pBnc > 0) ++pixelsCov;
//                        if (pPrim + pShad + pSdf  > 0) ++pixelsCov;
                        if (pPrim > 0) ++pixelsCov;

                    }
                }
                glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
                pboIdx = prev;

                Double gpuMs = gpuTimer.poll();
//                if (gpuMs != null) bench.tick(gpuMs, (int) primary, (int) shadow, (int) sdf, (int) bounce, pixelsCov);
                if (gpuMs != null) bench.tick(gpuMs, (int) primary, (int) shadow, (int) sdf, pixelsCov);

                glReadBuffer(GL_COLOR_ATTACHMENT0);
                glBindFramebuffer(GL_READ_FRAMEBUFFER, fbo);
                glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
                glBlitFramebuffer(0, 0, width, height, 0, 0, width, height, GL_COLOR_BUFFER_BIT, GL_NEAREST);
                glBindFramebuffer(GL_FRAMEBUFFER, 0);

                if (saveColorPngs) {
                    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
                    glReadBuffer(GL_COLOR_ATTACHMENT0);
                    rgbBuffer.clear();
                    glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, rgbBuffer);
                    STBImageWrite.stbi_flip_vertically_on_write(true);
                    String pngName = String.format("f%04d.png", frameIndex);
                    Path dst = frameDir.resolve(pngName);
                    STBImageWrite.stbi_write_png(dst.toString(), width, height, 3, rgbBuffer, width * 3);
                }

                if (saveMaskPngs) {
//                    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
//                    glReadBuffer(GL_COLOR_ATTACHMENT2);
//                    FloatBuffer maskBuffer = BufferUtils.createFloatBuffer(width * height);
//                    glReadPixels(0, 0, width, height, GL_RED, GL_FLOAT, maskBuffer);
                    ByteBuffer maskByteBuffer = BufferUtils.createByteBuffer(width * height);
                    for (int i = 0; i < width * height; ++i) {
                        float f = maskBuffer.get(i);
                        int gray = (int) (Math.max(0.0f, Math.min(1.0f, f)) * 255.0f);
                        maskByteBuffer.put((byte) gray);
                    }
                    maskByteBuffer.flip();
                    STBImageWrite.stbi_flip_vertically_on_write(true);
                    String maskName = String.format("mask%04d.png", frameIndex);
                    Path maskDst = maskDir.resolve(maskName);
                    STBImageWrite.stbi_write_png(maskDst.toString(), width, height, 1, maskByteBuffer, width);
                }
            }

            if (debugMode) {
                ImGui.render();
                guiController.renderDrawData();
            }

            glfwSwapBuffers(window);
            frameIndex++;
        }
    }



    private void initPbos() {
        glGenBuffers(pbo);
        long bytes = (long) width * height * 16L;
        for (int id : pbo) {
            glBindBuffer(GL_PIXEL_PACK_BUFFER, id);
            glBufferData(GL_PIXEL_PACK_BUFFER, bytes, GL_STREAM_READ);
        }
        glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
    }




    private String extractModelName(String methodPath) {
        String filename = methodPath.substring(methodPath.lastIndexOf('/') + 1);
        return filename.replace(".glsl", "");
    }


   /* private void handleKeyboardInput() {
        float camSpeed = 20.0f * deltaTime;
        if (inputHandler.isKeyPressed(GLFW_KEY_W)) {
            cameraPosition = cameraPosition.add(new java.util.Vector3f(0, 0, -camSpeed));
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_S)) {
            cameraPosition = cameraPosition.add(new java.util.Vector3f(0, 0, camSpeed));
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_A)) {
            cameraPosition = cameraPosition.add(new java.util.Vector3f(-camSpeed, 0, 0));
        }
        if (inputHandler.isKeyPressed(GLFW_KEY_D)) {
            cameraPosition = cameraPosition.add(new java.util.Vector3f(camSpeed, 0, 0));
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



    private void createMeasurementFbo() {
        fbo = glGenFramebuffers();
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);

        colorTexture = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, colorTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorTexture, 0);

        stepsTexture = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, stepsTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32UI, width, height, 0, GL_RGBA_INTEGER, GL_UNSIGNED_INT, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, stepsTexture, 0);

        maskTexture = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, maskTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, width, height, 0, GL_RED, GL_FLOAT, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D, maskTexture, 0);

        int rbo = glGenRenderbuffers();
        glBindRenderbuffer(GL_RENDERBUFFER, rbo);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, rbo);

        IntBuffer draw = BufferUtils.createIntBuffer(3).put(GL_COLOR_ATTACHMENT0).put(GL_COLOR_ATTACHMENT1).put(GL_COLOR_ATTACHMENT2);
        draw.flip();
        glDrawBuffers(draw);

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) throw new IllegalStateException("FBO incomplete");

        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        stepBuffer = BufferUtils.createIntBuffer(width * height * 4);
    }





    void cleanup() throws IOException {
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


        if(testing){

            int methodIndex = settings.getCurrentMethod();
            String methodPath = methodVariants[methodIndex];
            String modelName = extractModelName(methodPath);

            String csvFilename = modelName + ".csv";
            //String csvPath = "C:\\RT\\VoluMarch\\testResults\\" + csvFilename;

            //bench.saveCsv(csvFilename);
            String csvPath = "C:\\RT\\VoluMarch\\results\\" + csvFilename;

            bench.saveCsv(csvFilename);
            //waitForFile(csvPath, 10_000); // max 10 seconds wait

            plotData(modelName,csvPath);
        }




        // glfwSetErrorCallback(null).free();
    }


    private void plotData(String modelName, String csvFullPath) {
        try {
            ProcessBuilder pb = new ProcessBuilder("python", "C:\\RT\\VoluMarch\\scripts\\plot_data.py", modelName, csvFullPath,frameDir.toString());
            pb.inheritIO();
            pb.environment().put("PYTHONIOENCODING", "utf-8");
            Process process = pb.start();
            int exitCode = process.waitFor();
            System.out.println("Python script exited with code: " + exitCode);
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }


    private void waitForFile(String path, int timeoutMillis) {
        File file = new File(path);
        int waited = 0;
        int sleepStep = 200;

        while ((!file.exists() || file.length() == 0) && waited < timeoutMillis) {
            try {
                Thread.sleep(sleepStep);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
            waited += sleepStep;
        }

        if (!file.exists() || file.length() == 0) {
            System.err.println(" CSV file not detected or empty after wait: " + path);
        }
    }

    public void setHighQuality(){
        settings.setReferenceMode(true);
        settings.maxSteps = 256;
        settings.maxVolumeSteps = 512;
        settings.maxShadowMarchSteps = 64;
        settings.maxLightMarchSteps = 64;

        settings.noiseScale = 5.0f;
        settings.noiseHeight = 32.0f;
        settings.currentNoise = 0;
        settings.currentMethod = 0;

        settings.volumetricAbsorption = 0.05f;
        settings.volumetricScattering = 0.5f;
        settings.phaseG = 0.2f;

        settings.forwardScattering = 0.6f;
        settings.backwardScattering = -0.4f;

        settings.sunIntensity = 1.2f;
        settings.sunDirection = new float[] { -0.8f, 0.2f, -1.0f };
        settings.useBlueNoise = false;

        settings.ambientLight = 0.1f;
        settings.shapeTransition = 1.0f;

    }


}
