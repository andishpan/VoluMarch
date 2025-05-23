package org.java.performance;

import static org.lwjgl.opengl.GL11.*;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class SystemInfoLogger {

    public static void log(String filePath) {
        StringBuilder sb = new StringBuilder();


        LocalDateTime now = LocalDateTime.now();
        sb.append("Benchmark Timestamp: ").append(now.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))).append("\n\n");


        sb.append("GPU Vendor:   ").append(glGetString(GL_VENDOR)).append("\n");
        sb.append("GPU Rendering.Renderer: ").append(glGetString(GL_RENDERER)).append("\n");
        sb.append("GL Version:   ").append(glGetString(GL_VERSION)).append("\n\n");


        sb.append("OS:           ").append(System.getProperty("os.name")).append(" ").append(System.getProperty("os.version")).append("\n");
        sb.append("Java Version: ").append(System.getProperty("java.version")).append("\n");
        sb.append("CPU Cores:    ").append(Runtime.getRuntime().availableProcessors()).append("\n");

        long maxMem = Runtime.getRuntime().maxMemory();
        sb.append("Max JVM Memory: ").append(maxMem / (1024 * 1024)).append(" MB").append("\n");

        try {
            Path path = Paths.get(filePath);
            Files.createDirectories(path.getParent());

            try (BufferedWriter writer = Files.newBufferedWriter(path)) {
                writer.write(sb.toString());
            }

            System.out.println("System info saved to: " + path.toAbsolutePath());

        } catch (IOException e) {
            System.err.println("Failed to write system info:");
            e.printStackTrace();
        }
    }

    public static void logLine(String file, String text) {
        try (BufferedWriter w = Files.newBufferedWriter(Paths.get(file),
                StandardCharsets.UTF_8,
                Files.exists(Paths.get(file)) ?
                        StandardOpenOption.APPEND : StandardOpenOption.CREATE)) {
            w.write(text); w.newLine();
        } catch (IOException e) { e.printStackTrace(); }
    }

}
