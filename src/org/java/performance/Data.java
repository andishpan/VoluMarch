package org.java.performance;

import org.java.render.RenderSettings;

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class Data {
    public static final List<Float> samplesPerPixel = new ArrayList<>();
    public static final List<Float> samplesPerHit = new ArrayList<>();
    private final List<Double> frameTimesMs = new ArrayList<>();
    private final List<Double> gpuTimesMs = new ArrayList<>();
    private final List<Integer> pixelsCovered = new ArrayList<>();
    private final List<Float> volumeSteps = new ArrayList<>();
    private final List<Float> shadowSteps = new ArrayList<>();
    private final List<Float> sdfSteps = new ArrayList<>();
    private final List<Float> distanceTraveled = new ArrayList<>();
    private final List<Float> rayHitRatio = new ArrayList<>();
    private final int warmupFrames = 50;
    private final int recordFrames = 600;
    List<Integer> bounceSteps = new ArrayList<>();
    String runQuality = "";
    private long benchmarkStartTime;
    private long benchmarkEndTime;
    private int totalPixels = 0;
    private int frameCount = 0;


    private Runnable onExitRequest = null;

    private long prev;

    public void setTotalPixels(int x, int y) {
        totalPixels = x * y;
    }

    public void markStart() {
        benchmarkStartTime = System.nanoTime();
    }

    public void markEnd() {
        benchmarkEndTime = System.nanoTime();
    }

    public double getElapsedSeconds() {
        return (benchmarkEndTime - benchmarkStartTime) / 1_000_000_000.0;
    }

    public void tick(double gpuMs,
                     float volume, float shadow, float sdf, int pixels,
                     float traveled, float spp, float sph, float hitRatio) {
        long now = System.nanoTime();
        if (frameCount > 0) {


            double cpuMs = (now - prev) / 1_000_000.0;
            if (frameCount > warmupFrames) {
                frameTimesMs.add(cpuMs);
                gpuTimesMs.add(gpuMs);

                volumeSteps.add(volume);
                shadowSteps.add(shadow);
                sdfSteps.add(sdf);
                pixelsCovered.add(pixels);
                distanceTraveled.add(traveled);

                samplesPerHit.add(sph);
                samplesPerPixel.add(spp);
                rayHitRatio.add(hitRatio);
            }
        }
        prev = now;
        frameCount++;
        if (frameTimesMs.size() >= recordFrames) requestExit();
    }

    public void setRunLabel(String label) {
        this.runQuality = label;
    }


    public void saveCsv(String file) throws IOException {
        Path p = Paths.get(file).isAbsolute() ? Paths.get(file)
                : Paths.get("results", file);
        Files.createDirectories(p.getParent());

        try (BufferedWriter w = Files.newBufferedWriter(p)) {
            if (runQuality != null && !runQuality.isEmpty())
                w.write("# RunType: " + runQuality + "\n");

            w.write("frame,cpu_ms,gpu_ms,volume,shadow,sdf,pixels,distance,spp,sph,hit_ratio\n");

            for (int i = 0; i < frameTimesMs.size(); ++i) {
                w.write(i + "," + frameTimesMs.get(i) + "," + gpuTimesMs.get(i) + ","
                        + volumeSteps.get(i) + "," + shadowSteps.get(i) + ","
                        + sdfSteps.get(i) + ","
                        + pixelsCovered.get(i) + "," + distanceTraveled.get(i) + ","
                        + samplesPerPixel.get(i) + "," + samplesPerHit.get(i) + "," + rayHitRatio.get(i) + "\n");
            }
        }
    }

    public double getMedian(List<Double> values) {
        if (values.isEmpty()) return 0.0;
        List<Double> sorted = new ArrayList<>(values);
        Collections.sort(sorted);
        int mid = sorted.size() / 2;
        return (sorted.size() % 2 == 0)
                ? (sorted.get(mid - 1) + sorted.get(mid)) / 2.0
                : sorted.get(mid);
    }


    private String getRTF(String methodPath) {
        if (methodPath.contains("BEER_LAMBERT")) {
            return "Beer-Lambert Light Attenuation";
        } else if (methodPath.contains("HENYEY_GREENSTEIN")) {
            return "Beer-Lambert Light Attenuation * Henyey-Greenstein Phase Function";
        } else if (methodPath.contains("MOS")) {
            return "Beer-Lambert Light Attenuation *  Henyey-Greenstein (Multi-Octave)";
        } else if (methodPath.contains("MULTI_SCATTERING")) {
            return "Beer-Lambert Light Attenuation * Henyey-Greenstein Phase Function(Multi-Order)";
        } else if (methodPath.contains("POWDER")) {
            return "Powder Function * Beer-Lambert Light Attenuation * Henyey-Greenstein Phase Function";
        } else {
            return "Unknown";
        }
    }


    public void saveCsvAveragesOnly(String file, String methodName, String shape,
                                    String noiseType, int resolutionX, int resolutionY,
                                    RenderSettings settings, float distanceToCloud) throws IOException {

        Path p = Paths.get(file).isAbsolute() ? Paths.get(file)
                : Paths.get("results", file);
        Files.createDirectories(p.getParent());

        try (BufferedWriter w = Files.newBufferedWriter(p)) {

            w.write("# Method: " + methodName + "\n");
            w.write("# Volume Form : " + shape + "\n");
            w.write("#Noise Type: " + noiseType + "\n");
            w.write("#Radiative Transfer Model: " + getRTF(methodName) + "\n");
            w.write("# Resolution: " + resolutionX + "x" + resolutionY + "\n");
            w.write(String.format(Locale.US, "# Distance To Cloud: %.3f\n", distanceToCloud));
            w.write("# Max SDF Steps: " + settings.maxSteps + "\n");
            w.write("# Max Volume Steps: " + settings.maxVolumeSteps + "\n");
            w.write("#Max Shadow Steps: " + settings.maxShadowSteps + "\n");
            w.write("# Step Size: " + settings.stepSize + "\n");
            w.write("# SDF Blend Radius: " + settings.sdfBlendRadius + "\n");
            w.write("# Shadow Step Size: " + settings.shadowStepSize + "\n");
            w.write("#Number of Noise Octaves: " + settings.noiseOctaves + "\n");
            w.write(String.format(Locale.US, "# volumetric Absorption coefficient: %.6f\n",
                    settings.volumetricAbsorption));
            w.write(String.format(Locale.US, "# volumetric Scattering coefficient: %.6f\n",
                    settings.volumetricScattering));
            if (!methodName.contains("BEER_LAMBERT"))
                w.write(String.format(Locale.US, "# phaseG: %.3f\n", settings.phaseG));
            if (methodName.contains("POWDER"))
                w.write(String.format(Locale.US, "# Powder Strength: %.3f\n", settings.powderStrength));
            w.write(String.format(Locale.US, "# sunIntensity: %.3f\n", settings.sunIntensity));
            w.write("#Total Rendering Time : " + getElapsedSeconds() + "\n\n");

            w.write("""
                    metric,mean,std,min,50%%,max
                    """);

            record Stats(String name, double mean, double std, double min,
                         double med, double max) {
                @Override
                public String toString() {
                    return String.format(Locale.US,
                            "%s,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                            name, mean, std, min, med, max);
                }
            }

            List<Stats> all = new ArrayList<>();

            all.add(new Stats("cpu_ms",
                    getAverage(frameTimesMs),
                    getStdDev(frameTimesMs),
                    getMin(frameTimesMs),
                    getMedian(frameTimesMs),
                    getMax(frameTimesMs)));

            all.add(new Stats("gpu_ms",
                    getAverage(gpuTimesMs),
                    getStdDev(gpuTimesMs),
                    getMin(gpuTimesMs),
                    getMedian(gpuTimesMs),
                    getMax(gpuTimesMs)));

            var volumeD = volumeSteps.stream().mapToDouble(f -> f).boxed().toList();
            var shadowD = shadowSteps.stream().mapToDouble(f -> f).boxed().toList();
            var sdfD = sdfSteps.stream().mapToDouble(f -> f).boxed().toList();
            var pixelsD = pixelsCovered.stream().mapToDouble(i -> i).boxed().toList();
            var distanceD = distanceTraveled.stream().mapToDouble(f -> f).boxed().toList();
            var sppD = samplesPerPixel.stream().mapToDouble(f -> f).boxed().toList();
            var sphD = samplesPerHit.stream().mapToDouble(f -> f).boxed().toList();
            var hitD = rayHitRatio.stream().mapToDouble(f -> f).boxed().toList();

            all.add(new Stats("volume", getAverage(volumeD), getStdDev(volumeD),
                    getMin(volumeD), getMedian(volumeD), getMax(volumeD)));
            all.add(new Stats("shadow", getAverage(shadowD), getStdDev(shadowD),
                    getMin(shadowD), getMedian(shadowD), getMax(shadowD)));
            all.add(new Stats("sdf", getAverage(sdfD), getStdDev(sdfD),
                    getMin(sdfD), getMedian(sdfD), getMax(sdfD)));
            all.add(new Stats("pixels", getAverage(pixelsD), getStdDev(pixelsD),
                    getMin(pixelsD), getMedian(pixelsD), getMax(pixelsD)));
            all.add(new Stats("distance", getAverage(distanceD), getStdDev(distanceD),
                    getMin(distanceD), getMedian(distanceD), getMax(distanceD)));
            all.add(new Stats("spp", getAverage(sppD), getStdDev(sppD),
                    getMin(sppD), getMedian(sppD), getMax(sppD)));
            all.add(new Stats("sph", getAverage(sphD), getStdDev(sphD),
                    getMin(sphD), getMedian(sphD), getMax(sphD)));
            all.add(new Stats("hit_ratio", getAverage(hitD), getStdDev(hitD),
                    getMin(hitD), getMedian(hitD), getMax(hitD)));

            for (Stats s : all) w.write(s.toString());

            w.write("\n# Bottleneck: " + getBottleneck() + "\n");
        }
    }


    public double getAvgPixels() {
        return getAverage(pixelsCovered.stream()
                .mapToDouble(v -> v).boxed().toList());
    }

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
                        
                        | Metric   | CPU (ms) | GPU (ms) |
                        |---------------|----------|----------|
                        | Avg      | %.2f     | %.2f     |
                        | Min      | %.2f     | %.2f     |
                        | Max      | %.2f     | %.2f     |
                        | Std Dev  | %.2f     | %.2f     |
                        
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

    public double getAverageFloats(List<Float> values) {
        return values.stream()
                .mapToDouble(Float::doubleValue)
                .average()
                .orElse(0.0);
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
