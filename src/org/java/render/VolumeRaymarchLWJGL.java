package org.java.render;

import imgui.ImGui;
import org.java.performance.BatchBenchmark;
import org.java.performance.Data;
import org.java.performance.GpuTimer;
import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import org.java.utility.*;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.lwjgl.glfw.Callbacks.glfwFreeCallbacks;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL13.*;
import static org.lwjgl.system.MemoryUtil.*;


public class VolumeRaymarchLWJGL {

    private final int[] acBuf = new int[2];
    public RenderSettings settings = new RenderSettings();
    ShaderProgram shader;
    RendererSSBO renderer;
    ShaderProgram[][] combinedShaders;
    String[] methodVariants;
    String[] noiseVariants;
    Material[] materials;
    Texture3DFromSlices blueNoise;
    Texture3D noiseTexture3D;
    private long window;
    private int width;
    private int height;
    private ShaderProgram methodsShader;
    private long startTime;
    private double lastFrameTime;
    private float deltaTime;
    private ShaderProgram[] noiseShaders;
    private ShaderProgram[] methodShaders;
    private Data bench = new Data();
    private GpuTimer gpuTimer;
    private GuiController guiController;
    private boolean testing;
    private boolean debugMode;
    private String requestedMethod = null;
    private String requestedNoise = null;
    private int frameIndex = 0;
    private Process pythonProcess;
    private int environmentMapTexID;
    private int noiseID;

    public static void main(String[] args) throws IOException {
        VolumeRaymarchLWJGL app = new VolumeRaymarchLWJGL();

        app.settings.resolutionX = 1280;
        app.settings.resolutionY = 720;

        for (int i = 0; i < args.length; ++i) {
            switch (args[i]) {
                case "--test", "--testing" -> app.setTesting(true);
                case "--debug" -> app.setDebugMode(true);
                case "--no-debug" -> app.setDebugMode(false);
                default -> {
                    if (args[i].startsWith("--width=")) {
                        app.settings.resolutionX = Integer.parseInt(args[i].substring("--width=".length()));
                    } else if (args[i].startsWith("--height=")) {
                        app.settings.resolutionY = Integer.parseInt(args[i].substring("--height=".length()));
                    } else if (args[i].startsWith("--scene=")) {
                        String sceneName = args[i].substring("--scene=".length()).toUpperCase();
                        try {
                            RenderSettings.Scene scene = RenderSettings.Scene.valueOf(sceneName);
                            app.settings.setCurrentScene(scene);
                            System.out.println("Applied scene preset: " + scene);
                        } catch (IllegalArgumentException e) {
                            System.err.println("Invalid scene: " + sceneName);
                        }
                    }
                }
            }
        }


        if (args.length == 0) {
            RenderSettings.Quality quality = RenderSettings.Quality.valueOf("BEER_LAMBERT");
            RenderSettings.applyMethodPreset(app.settings, quality);
            System.out.println("Applied quality preset: " + quality);
        }


        if (args.length > 0) {
            try {
                RenderSettings.Quality quality = RenderSettings.Quality.valueOf(args[0].toUpperCase());
                RenderSettings.applyMethodPreset(app.settings, quality);
                System.out.println("Applied quality preset: " + quality);
            } catch (IllegalArgumentException e) {
                System.err.println("Invalid quality preset: " + args[0]);
            }
        }

        if (args.length > 1) {
            String methodName = args[1];
            app.setRequestedMethod(methodName);
            app.settings.setCustomMethodName(methodName);
        }

        if (args.length > 2) {
            try {
                app.setRequestedNoise(args[2]);
            } catch (NumberFormatException e) {
                System.err.println("Invalid noise index: " + args[2]);
            }
        }


        app.run();
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public void setRequestedMethod(String method) {
        this.requestedMethod = method;
    }

    public void setRequestedNoise(String noise) {
        this.requestedNoise = noise;
    }

    public void setTesting(boolean value) {
        this.testing = value;
    }

    public void setDebugMode(boolean value) {
        this.debugMode = value;
    }

    public void run() throws IOException {

        init();
        loop();
        cleanup();
    }


    void init() {
        System.out.println("Main settings object: " + System.identityHashCode(settings));

        width = settings.resolutionX;
        height = settings.resolutionY;

        bench.setTotalPixels(width, height);

        GLFWErrorCallback.createPrint(System.err).set();
        if (!glfwInit()) {
            throw new IllegalStateException("Unable to initialize GLFW");
        }


        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 4);
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


        gpuTimer = new GpuTimer();

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

        String vertexShaderPath = "vertex.glsl";
        String fragmentShaderPath = "fragment_c.glsl";


        settings.setReferenceMode(false);
        if (testing) {
            settings.requestScreenshot();
        }


        initShaders();


        int m = settings.getCurrentMethod();
        int n = settings.getCurrentNoise();
        shader = combinedShaders[m][n];

        if (debugMode) {
            Thread pythonWatcher = new Thread(() -> {
                System.out.println("Watcher sees settings: " + System.identityHashCode(settings));

                Pattern predPat = Pattern.compile("Prediction for .*?: (\\w+) \\(p_cloud=(\\d+\\.\\d+)\\)");

                try {
                    ProcessBuilder pb = new ProcessBuilder(
                            "python", "C:\\cloudClassifier\\Cloud-Classification\\comp.py"
                    );
                    pb.redirectErrorStream(true);
                    pythonProcess = pb.start();

                    try (BufferedReader reader = new BufferedReader(
                            new InputStreamReader(pythonProcess.getInputStream()))) {
                        String line;
                        while ((line = reader.readLine()) != null) {
                            System.out.println("[PYTHON] " + line);

                            // parse the p_cloud= value out of the line
                            Matcher matcher = predPat.matcher(line);
                            if (matcher.find()) {
                                // float score = Float.parseFloat(matcher.group(1));
                                //settings.setLastCloudScore(score);
                                String lbl = matcher.group(1);
                                float score = Float.parseFloat(matcher.group(2));
                                settings.setLastCloudLabel(lbl);
                                settings.setLastCloudScore(score);
                                settings.markPredictionDone();
                                System.out.printf("Matched prediction: label=%s, p_cloud=%f\n", lbl, score);

                            }
                        }
                    }
                } catch (IOException e) {
                    System.err.println("Failed to start Python watcher:");
                    e.printStackTrace();
                }
            });
            pythonWatcher.setDaemon(true);
            pythonWatcher.start();
        }


        renderer = new RendererSSBO(shader);
        guiController = new GuiController(window, settings, renderer);

        guiController.setNoiseVariantPaths(noiseVariants);

        //https://momentsingraphics.de/3DBlueNoise.html
        blueNoise = new Texture3DFromSlices("C:\\RT\\VoluMarch\\assets\\3DTextures\\64_64_64", "HDR_L_", 64, 64, 64);
        GL45.glBindTextureUnit(0, blueNoise.getId());

        //python generated bin file
        noiseTexture3D = new Texture3D("C:\\RT\\VoluMarch\\src\\res\\shaders\\textures\\noise\\simplex_noise_64x64x64.bin", 64, 64, 64);
        GL45.glBindTextureUnit(2, noiseTexture3D.getId());
        //cubemap
        environmentMapTexID = shader.loadCubemap("C:\\RT\\VoluMarch\\assets\\Cubemap");
        GL45.glBindTextureUnit(3, environmentMapTexID);
//        glActiveTexture(GL_TEXTURE0 + 3);
//        glBindTexture(GL_TEXTURE_CUBE_MAP, environmentMapTexID);


//        glActiveTexture(GL_TEXTURE0);
//        glBindTexture(GL_TEXTURE_2D, blueNoise.getId());


        String vramLine = GpuMemoryInfo.query();


        startTime = System.currentTimeMillis();
        lastFrameTime = glfwGetTime();


    }

    private void initShaders() {
        String[] allNoiseVariants = {
                "noise/gradient_noise.glsl",
                "noise/noise.glsl",
                "noise/noise_precomputed.glsl"

        };

        if (testing) {
            if (requestedMethod == null || requestedNoise == null) {
                throw new IllegalStateException("Both method and noise must be specified for testing mode.");
            }


            String matchedNoisePath = null;
            for (String path : allNoiseVariants) {
                if (path.contains(requestedNoise)) {
                    matchedNoisePath = path;
                    break;
                }
            }

            if (matchedNoisePath == null) {
                throw new IllegalArgumentException("Unknown noise variant: " + requestedNoise);
            }

            String methodPath = "models/" + requestedMethod + ".glsl";


            methodVariants = new String[]{methodPath};
            noiseVariants = new String[]{matchedNoisePath};

            combinedShaders = new ShaderProgram[1][1];
            combinedShaders[0][0] = new ShaderProgram(
                    "main/vertex.glsl",
                    "main/fragment_base.glsl",
                    matchedNoisePath,
                    methodPath
            );

            settings.setCurrentMethod(0);
            settings.setCurrentNoise(0);
            shader = combinedShaders[0][0];

            System.out.printf("Testing: Using model '%s' with noise '%s'\n", requestedMethod, requestedNoise);
        } else {

            methodVariants = new String[]{
                    "models/beer_lambert.glsl",
                    "models/single_scattering.glsl",
                    "models/MOS.glsl",
                    "models/powder.glsl",
//                    "models/beer_lambert_aabb.glsl",
//                    "models/hg_aabb.glsl",
//                    "models/mos_aabb.glsl",
//                    "models/powder_aabb.glsl",
            };

            this.noiseVariants = allNoiseVariants;
            System.out.println("[Debug] Available noise variants:");
            for (int i = 0; i < noiseVariants.length; i++) {
                System.out.printf("  [%d] %s%n", i, allNoiseVariants[i]);
            }

            combinedShaders = new ShaderProgram[methodVariants.length][noiseVariants.length];
            for (int m = 0; m < methodVariants.length; ++m) {
                for (int n = 0; n < noiseVariants.length; ++n) {
                    combinedShaders[m][n] = new ShaderProgram(
                            "main/vertex.glsl",
                            "main/fragment_base.glsl",
                            noiseVariants[n],
                            methodVariants[m]
                    );
                }
            }

            int m0 = settings.getCurrentMethod();
            int n0 = settings.getCurrentNoise();
            shader = combinedShaders[m0][n0];
        }
    }


    private void loop() throws IOException {


        if (testing) {
            bench.markStart();
            bench.setOnExitRequest(() -> glfwSetWindowShouldClose(window, true));

        }


        while (!glfwWindowShouldClose(window)) {
            double start = System.nanoTime();

            if (testing) {
                gpuTimer.begin();
            }

            double currentFrameTime = glfwGetTime();
            deltaTime = (float) (currentFrameTime - lastFrameTime);
            lastFrameTime = currentFrameTime;
            glfwPollEvents();


            if (debugMode) {
                guiController.newFrame();
                guiController.render(deltaTime);

                guiController.updateMouseLook(deltaTime);
                guiController.updateCameraFromKeyboard(deltaTime);


            }

            float elapsedTime = (System.currentTimeMillis() - startTime) * 0.0001f;
            glViewport(0, 0, width, height);
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            int m = settings.getCurrentMethod();
            int n = settings.getCurrentNoise();

            ShaderProgram want = combinedShaders[m][n];
            if (want != shader) {
                shader = want;
                renderer.setShader(shader);
            }


            renderer.render(elapsedTime, width, height, settings);


            if (settings.isPredictionRequested()) {
                System.out.println("Taking screenshot");
                String noiseTag = requestedNoise != null ? requestedNoise : "noise";

                String tag = extractModelName(methodVariants[settings.getCurrentMethod()])
                        + "_" + noiseTag
                        + "_" + settings.getCurrentQuality()
                        + "_" + guiController.getCurrentShapeLabel()
                        + "_" + Screenshot.nowTag();


                Path out = Paths.get("results", "predictions").resolve(tag + ".png");
                try {
                    Files.createDirectories(out.getParent());
                    Screenshot.saveRGBA(width, height, out);
                    System.out.println("Saved to: " + out);
                } catch (IOException e) {
                    e.printStackTrace();
                }

                settings.clearPredictionFlag();
            }


            if (settings.isScreenshotRequested()) {
                System.out.println("Taking screenshot");
                String noiseTag = requestedNoise != null ? requestedNoise : "noise";

                String tag = extractModelName(methodVariants[settings.getCurrentMethod()])
                        + "_" + noiseTag
                        + "_" + settings.getCurrentQuality()
                        + "_" + guiController.getCurrentShapeLabel()
                        + "_" + Screenshot.nowTag();


                Path out = Paths.get("results", "screenshots").resolve(tag + ".png");
                try {
                    Files.createDirectories(out.getParent());
                    Screenshot.saveRGBA(width, height, out);
                    System.out.println("Saved to: " + out);
                } catch (IOException e) {
                    e.printStackTrace();
                }

                settings.clearScreenshotFlag();
            }


            if (testing) {


                gpuTimer.end();
            }


            if (debugMode) {
                ImGui.render();
                guiController.renderDrawData();
                ImGui.updatePlatformWindows();
                ImGui.renderPlatformWindowsDefault();
                glfwMakeContextCurrent(window);
            }
            glfwSwapBuffers(window);
            if (testing) {
                double gpuMs = gpuTimer.getElapsedTimeMs();


                RendererSSBO.LoopStats ls = renderer.fetchLoopStats(width, height);
                float avgDist = renderer.getLastDistance();
                bench.tick(
                        gpuMs,
                        ls.volume(), ls.shadow(), ls.sdf(),
                        (int) ls.pixels(),
                        avgDist, ls.spp(), ls.sph(), ls.hitRatio()
                );


            }
            frameIndex++;
        }
        if (testing) {
            bench.markEnd();
        }


    }


    private String extractModelName(String methodPath) {
        String filename = methodPath.substring(methodPath.lastIndexOf('/') + 1);
        return filename.replace(".glsl", "");
    }


    void cleanup() throws IOException {
        shader.cleanup();
        renderer.cleanup();

        if (blueNoise != null) {
            blueNoise.delete();
        }
        if (noiseTexture3D != null) {
            noiseTexture3D.delete();
        }
        glfwFreeCallbacks(window);
        glfwDestroyWindow(window);
        glfwTerminate();

        if (debugMode) {
            if (pythonProcess != null && pythonProcess.isAlive()) {
                System.out.println("Shutting down Python process...");
                pythonProcess.destroy();
            }
        }

        if (!testing) return;

        // Metadata
        String shape = guiController.getShapeName(settings.currentShape);
        String noise = guiController.getNoiseName(settings.currentNoise);
        String resolutionTag = settings.resolutionX + "x" + settings.resolutionY;
        String timeTag = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmm"));
        int methodIndex = settings.getCurrentMethod();
        String methodPath = methodVariants[methodIndex];
        String modelName = extractModelName(methodPath);
        String noiseTag = requestedNoise != null ? requestedNoise : "noise";

        String qualTag = settings.getCurrentQuality() != null
                ? settings.getCurrentQuality().name()
                : (settings.isReferenceMode() ? "REF" : "CUSTOM");


        float distanceToCloud = renderer.getDistanceToCloud();
        String distanceFolder = "distance=" + (int) distanceToCloud;
        Path fullDir = Paths.get("C:\\RT\\VoluMarch\\results\\fullruns", distanceFolder, modelName);
        Files.createDirectories(fullDir);

        String fullCsvFilename = "full_" + modelName + "_" + qualTag + resolutionTag + "_" + noiseTag + "_" + timeTag + ".csv";
        Path fullCsvPath = fullDir.resolve(fullCsvFilename);
        bench.saveCsv(fullCsvPath.toString());


        Path avgDir = Paths.get("C:\\RT\\VoluMarch\\results\\average", distanceFolder, modelName);
        Files.createDirectories(avgDir);
        String avgCsvFilename = "avg_" + modelName + "_" + qualTag + resolutionTag + "_" + noiseTag + "_" + timeTag + ".csv";
        Path avgCsvPath = avgDir.resolve(avgCsvFilename);
        bench.saveCsvAveragesOnly(avgCsvPath.toString(), modelName, shape, noise, settings.resolutionX, settings.resolutionY, settings, distanceToCloud);


    }


}
