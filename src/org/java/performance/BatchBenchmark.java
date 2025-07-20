package org.java.performance;

import org.java.render.RenderSettings;
import org.java.render.VolumeRaymarchLWJGL;

import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class BatchBenchmark {

   public static boolean batchTest = false;

   public static void main(String[] args) throws IOException {
      if (args.length < 3) {
         System.err.println("""
                Usage: BatchBenchmark [<quality>] <noise> <resolution> <model1> [model2] ...
                  quality    : optional (LOW | MID | HIGH | ULTRA)
                  noise      : e.g. gradient_noise
                  resolution : e.g. 1600x900
                  modelX     : e.g. beer_lambert
            """);
         System.exit(1);
      }

      int argIndex = 0;


      RenderSettings.Quality singleQuality = null;
      try {
         singleQuality = RenderSettings.Quality.valueOf(args[argIndex].toUpperCase());
         argIndex++;
      } catch (IllegalArgumentException e) {

      }

      String noiseVariant = args[argIndex++];
      String resolutionVariant = args[argIndex++];

      String[] resolutionParts = resolutionVariant.toLowerCase().split("x");
      if (resolutionParts.length != 2) {
         System.err.println("Invalid resolution format. Expected: <width>x<height>");
         System.exit(1);
      }

      int resX = Integer.parseInt(resolutionParts[0]);
      int resY = Integer.parseInt(resolutionParts[1]);

      if (argIndex >= args.length) {
         System.err.println("At least one model name must be provided.");
         System.exit(1);
      }

      List<String> modelNames = new ArrayList<>();
      for (int i = argIndex; i < args.length; ++i) {
         modelNames.add(args[i]);
      }

      for (String methodName : modelNames) {
         List<RenderSettings.Quality> presetsToRun = new ArrayList<>();
         if (singleQuality != null) {
            presetsToRun.add(singleQuality);
         } else {
            for (RenderSettings.Quality q : RenderSettings.Quality.values()) {
               presetsToRun.add(q);
            }
         }

         for (RenderSettings.Quality qualityPreset : presetsToRun) {
            System.out.println("\n->>");
            System.out.println("Running " + methodName +
                    "  |  quality=" + qualityPreset +
                    "  |  noise=" + noiseVariant +
                    "  |  resolution=" + resolutionVariant);
            System.out.println("->>");

            VolumeRaymarchLWJGL app = new VolumeRaymarchLWJGL();
            app.settings.resolutionX = resX;
            app.settings.resolutionY = resY;

            RenderSettings.applyMethodPreset(app.settings, qualityPreset);
            app.setTesting(true);
            app.setRequestedMethod(methodName);
            app.setRequestedNoise(noiseVariant);
            batchTest = true;

            app.run();
         }
      }

      System.out.println("[batch] All runs finished – individual CSVs are in /results");

      System.out.println("[batch] All runs finished – generating plots...");

      Path plotOutDir = Paths.get("C:\\RT\\VoluMarch\\results\\plots");
      try {
         List<String> cmd = new ArrayList<>();
         cmd.add("python");
         cmd.add("C:\\RT\\VoluMarch\\scripts\\auto_plot_data.py");
         cmd.add("-b");
         cmd.add("C:\\RT\\VoluMarch\\results\\average");

         ProcessBuilder pb = new ProcessBuilder(cmd);
         pb.directory(plotOutDir.toFile());
         pb.redirectOutput(ProcessBuilder.Redirect.INHERIT);
         pb.redirectError(ProcessBuilder.Redirect.INHERIT);
         pb.environment().put("PYTHONIOENCODING", "utf-8");

         Process process = pb.start();
         int exit = process.waitFor();
         if (exit == 0) {
            System.out.println("[batch] Plotting complete: " + plotOutDir);
         } else {
            System.err.println("[batch] Plotting script exited with code: " + exit);
         }
      } catch (IOException | InterruptedException e) {
         System.err.println("[batch] Failed to launch plotting script");
         e.printStackTrace();
      }

   }
}
