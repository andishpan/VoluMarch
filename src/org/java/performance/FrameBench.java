package org.java.performance;

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class FrameBench {
    private final List<Double> frameTimesMs = new ArrayList<>();
    private final List<Double> gpuTimesMs = new ArrayList<>();

    private final List<Integer> pixelsCovered = new ArrayList<>();


    private final List<Integer> primarySteps = new ArrayList<>();
    private final List<Integer> shadowSteps  = new ArrayList<>();
    private final List<Integer> sdfSteps     = new ArrayList<>();
    List<Integer> bounceSteps = new ArrayList<>();



    private final int warmupFrames = 50;
    private final int recordFrames = 600;
    private int frameCount = 0;


    private Runnable onExitRequest = null;

    private long      prev;


//    public void tick(double gpuMs,
//                     int primary, int shadow, int sdf,int bounce, int pixCovered)
//    {
//        long now = System.nanoTime();
//        if (frameCount > 0) {
//            double cpuMs = (now - prev) / 1_000_000.0;
//            if (frameCount > warmupFrames) {
//                frameTimesMs.add(cpuMs);
//                gpuTimesMs.add(gpuMs);
//
//
//                primarySteps.add(primary);
//                shadowSteps.add(shadow);
//                sdfSteps.add(sdf);
//                bounceSteps.add(bounce);
//                pixelsCovered.add(pixCovered);
//            }
//        }
//        prev = now;
//        frameCount++;
//
//        if (frameTimesMs.size() >= recordFrames)
//            requestExit();
//    }

    public void tick(double gpuMs,
                     int primary, int shadow, int sdf, int pixCovered)
    {
        long now = System.nanoTime();
        if (frameCount > 0) {
            double cpuMs = (now - prev) / 1_000_000.0;
            if (frameCount > warmupFrames) {
                frameTimesMs.add(cpuMs);
                gpuTimesMs.add(gpuMs);


                primarySteps.add(primary);
                shadowSteps.add(shadow);
                sdfSteps.add(sdf);
                pixelsCovered.add(pixCovered);
            }
        }
        prev = now;
        frameCount++;

        if (frameTimesMs.size() >= recordFrames)
            requestExit();
    }




//    public void saveCsv(String file) throws IOException {
//        Files.createDirectories(Paths.get("results"));
//        try (BufferedWriter w = Files.newBufferedWriter(
//                Paths.get("results", file))) {
//
//
//            w.write("frame,cpu_ms,gpu_ms,primary,shadow,sdf,bounce,pixels\n");
//
//            for (int i = 0; i < frameTimesMs.size(); i++) {
//                w.write(i + "," +
//                        frameTimesMs.get(i) + "," +
//                        gpuTimesMs.get(i)   + "," +
//                        primarySteps.get(i) + "," +
//                        shadowSteps.get(i)  + "," +
//                        sdfSteps.get(i)     + "," +
//                        bounceSteps.get(i)  + "," +
//                        pixelsCovered.get(i)+ "\n");
//            }
//        }
//    }

    public void saveCsv(String file) throws IOException {
        Files.createDirectories(Paths.get("results"));
        try (BufferedWriter w = Files.newBufferedWriter(
                Paths.get("results", file))) {


            w.write("frame,cpu_ms,gpu_ms,primary,shadow,sdf,pixels\n");

            for (int i = 0; i < frameTimesMs.size(); i++) {
                w.write(i + "," +
                        frameTimesMs.get(i) + "," +
                        gpuTimesMs.get(i)   + "," +
                        primarySteps.get(i) + "," +
                        shadowSteps.get(i)  + "," +
                        sdfSteps.get(i)     + "," +
                        pixelsCovered.get(i)+ "\n");
            }
        }
    }


    public double getAvgPixels() { return getAverage(pixelsCovered.stream()
            .mapToDouble(v->v).boxed().toList()); }

    public void saveSummary(String summaryFile, String label) throws IOException {
        Files.createDirectories(Paths.get("results"));

        try (BufferedWriter w = Files.newBufferedWriter(Paths.get("results", summaryFile), StandardOpenOption.CREATE, StandardOpenOption.APPEND)) {
            if (Files.size(Paths.get("results", summaryFile)) == 0) {
                w.write("label,cpu_avg,cpu_stddev,cpu_min,cpu_max,gpu_avg,gpu_stddev,gpu_min,gpu_max\n");
            }

            w.write(String.format(Locale.US,
                    "%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n",
                    label,
                    getAverage(frameTimesMs), getStdDev(frameTimesMs), getMin(frameTimesMs), getMax(frameTimesMs),
                    getAverage(gpuTimesMs), getStdDev(gpuTimesMs), getMin(gpuTimesMs), getMax(gpuTimesMs)
            ));
        }
    }

    public String getBottleneck() {
        double cpuAvg = getAverage(frameTimesMs);
        double gpuAvg = getAverage(gpuTimesMs);
        if (cpuAvg > gpuAvg * 1.2) return "CPU-bound";
        if (gpuAvg > cpuAvg * 1.2) return "GPU-bound";
        return "Balanced";
    }

    public String getMarkdownSummary(String label) {
        return String.format("""
    ### %s
    
    | Metric        | CPU (ms) | GPU (ms) |
    |---------------|----------|----------|
    | Avg           | %.2f     | %.2f     |
    | Min           | %.2f     | %.2f     |
    | Max           | %.2f     | %.2f     |
    | Std Dev       | %.2f     | %.2f     |
    
    **Bottleneck**: %s
    
    """, label,
                getAverage(frameTimesMs), getAverage(gpuTimesMs),
                getMin(frameTimesMs), getMin(gpuTimesMs),
                getMax(frameTimesMs), getMax(gpuTimesMs),
                getStdDev(frameTimesMs), getStdDev(gpuTimesMs),
                getBottleneck());
    }




    public void setOnExitRequest(Runnable r) {
        this.onExitRequest = r;
    }

    private void requestExit() {
        if (onExitRequest != null) {
            onExitRequest.run();
        }


    }

    public double getAverage(List<Double> values) {
        return values.stream().mapToDouble(v -> v).average().orElse(0.0);
    }

    public double getStdDev(List<Double> values) {
        double mean = getAverage(values);
        double variance = values.stream()
                .mapToDouble(v -> (v - mean) * (v - mean))
                .average().orElse(0.0);
        return Math.sqrt(variance);
    }

    public double getMin(List<Double> values) {
        return values.stream().mapToDouble(v -> v).min().orElse(0.0);
    }

    public double getMax(List<Double> values) {
        return values.stream().mapToDouble(v -> v).max().orElse(0.0);
    }

    public void printStats() {
        System.out.printf("CPU: Avg = %.3f ms | Min = %.3f ms | Max = %.3f ms | StdDev = %.3f ms\n",
                getAverage(frameTimesMs), getMin(frameTimesMs), getMax(frameTimesMs), getStdDev(frameTimesMs));

        System.out.printf("GPU: Avg = %.3f ms | Min = %.3f ms | Max = %.3f ms | StdDev = %.3f ms\n",
                getAverage(gpuTimesMs), getMin(gpuTimesMs), getMax(gpuTimesMs), getStdDev(gpuTimesMs));
    }


}
