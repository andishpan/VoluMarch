package org.java.utility;

import org.lwjgl.BufferUtils;
import org.lwjgl.opengl.GL11;
import org.lwjgl.stb.STBImageWrite;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;


public final class Screenshot {

    private Screenshot() {
    }

    public static void saveRGBA(int w, int h, Path file) throws IOException {
        STBImageWrite.stbi_flip_vertically_on_write(true);
        ByteBuffer pixels = BufferUtils.createByteBuffer(w * h * 4);
        GL11.glReadPixels(0, 0, w, h, GL11.GL_RGBA, GL11.GL_UNSIGNED_BYTE, pixels);

        try {
            Files.createDirectories(file.getParent());

            boolean ok = STBImageWrite.stbi_write_png(
                    file.toString(), w, h, 4, pixels, w * 4);

            if (!ok) throw new IOException("stbi_write_png failed for " + file);

            System.out.println("[screenshot] " + file);
        } finally {
            STBImageWrite.stbi_flip_vertically_on_write(false);
        }
    }


    public static String nowTag() {
        return LocalDateTime.now()
                .format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"));
    }
}
