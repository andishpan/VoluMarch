package org.java.performance;

import org.java.render.RenderSettings;
import org.java.render.VolumeRaymarchLWJGL;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class BatchBenchmark {

   public static boolean batchTest = false;

   public static void main(String[] args) throws IOException {
      if (args.length < 3) {
         System.err.println("""
            Usage: BatchBenchmark [<quality1> <quality2> ...] <noise> <resolution> <model1> [model2] ...
              quality    : one or more of (LOW | MID | HIGH | ULTRA)
              noise      : e.g. gradient_noise
              resolution : e.g. 1600x900
              modelX     : e.g. beer_lambert
        """);
         System.exit(1);
      }

      int argIndex = 0;
      List<RenderSettings.Quality> requestedQualities = new ArrayList<>();


      while (argIndex < args.length) {
         try {
            RenderSettings.Quality quality = RenderSettings.Quality.valueOf(args[argIndex].toUpperCase());
            requestedQualities.add(quality);
            argIndex++;
         } catch (IllegalArgumentException e) {
            break;
         }
      }


      if (requestedQualities.isEmpty()) {
         requestedQualities.addAll(Arrays.asList(RenderSettings.Quality.values()));
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



      float currentDistance = 0.0f;

      for (String methodName : modelNames) {
         for (RenderSettings.Quality qualityPreset : requestedQualities) {
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

             currentDistance = app.getRenderer().getDistanceToCloud();
         }

      }

      System.out.println("[batch] All runs finished – individual CSVs are in /results");

      System.out.println("[batch] All runs finished – generating plots...");


      Path plotOutDir = Paths.get("results\\plots");
      try {
         List<String> cmd = new ArrayList<>();
         cmd.add("python");
         cmd.add("scripts/auto_plot_data.py");
         cmd.add("-b");
         cmd.add("results/average");
         cmd.add("-d");

         int roundedDistance = Math.round(currentDistance);
         cmd.add(String.valueOf(roundedDistance));



         System.out.println("[debug] Running Python command:");
         System.out.println("         " + String.join(" ", cmd));

         ProcessBuilder pb = new ProcessBuilder(cmd);

         pb.directory(new File(".").getAbsoluteFile());
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
