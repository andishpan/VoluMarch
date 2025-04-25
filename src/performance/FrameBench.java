package performance;

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class FrameBench {
    private final List<Double> frameTimesMs = new ArrayList<>();
    private final List<Double> gpuTimesMs = new ArrayList<>();

    private final int warmupFrames = 50;      // discard these
    private final int recordFrames = 600;     // ~10 s at 60 FPS
    private int frameCount = 0;


    private Runnable onExitRequest = null;


    // call once every frame, immediately after you swap buffers
    public void tick(double gpuTimeMs) {
        long now = System.nanoTime();
        if (frameCount > 0) {
            double cpuMs = (now - prev) / 1_000_000.0;
            if (frameCount > warmupFrames) {
                frameTimesMs.add(cpuMs);
                gpuTimesMs.add(gpuTimeMs);
            }
        }
        prev = now;
        frameCount++;

        if (frameTimesMs.size() >= recordFrames)
            requestExit();
    }


    private long prev;

    public void saveCsv(String file) throws IOException {
        Files.createDirectories(Paths.get("testResults"));
        try (BufferedWriter w = Files.newBufferedWriter(Paths.get("testResults", file))) {
            w.write("frame,cpu_ms,gpu_ms\n");
            for (int i = 0; i < frameTimesMs.size(); i++) {
                w.write(i + "," + frameTimesMs.get(i) + "," + gpuTimesMs.get(i) + "\n");
            }

        }
    }

    public void saveSummary(String summaryFile, String label) throws IOException {
        Files.createDirectories(Paths.get("testResults"));

        try (BufferedWriter w = Files.newBufferedWriter(Paths.get("testResults", summaryFile), StandardOpenOption.CREATE, StandardOpenOption.APPEND)) {
            if (Files.size(Paths.get("testResults", summaryFile)) == 0) {
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
