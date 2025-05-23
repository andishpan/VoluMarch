package org.java.utility;


import org.lwjgl.opengl.GL45;
import org.lwjgl.stb.STBImage;
import org.lwjgl.system.MemoryStack;
import org.lwjgl.system.MemoryUtil;

import java.io.IOException;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

import static org.lwjgl.opengl.GL11.glBindTexture;
import static org.lwjgl.opengl.GL12.GL_TEXTURE_3D;
import static org.lwjgl.opengl.GL13.GL_TEXTURE0;
import static org.lwjgl.opengl.GL13.glActiveTexture;


public final class NoiseTexture3D {

    private final int id;


    public final int width, height, depth;

    private NoiseTexture3D(int id, int width, int height, int depth) {
        this.id = id;
        this.width = width;
        this.height = height;
        this.depth = depth;
    }


    public static NoiseTexture3D load(Path directory, String baseName, int depth, boolean useRGB) throws IOException {
        if (!Files.isDirectory(directory))
            throw new IOException("Directory not found: " + directory);

        int firstSliceIdx = 0;
        Path firstPath = directory.resolve(String.format(Locale.US, "%s_%03d.exr", baseName, firstSliceIdx));
        if (!Files.isRegularFile(firstPath))
            throw new IOException("Missing first slice: " + firstPath);

        int width, height, channels;
        FloatBuffer firstData;
        try (MemoryStack stack = MemoryStack.stackPush()) {
            IntBuffer w = stack.mallocInt(1);
            IntBuffer h = stack.mallocInt(1);
            IntBuffer c = stack.mallocInt(1);
            STBImage.stbi_set_flip_vertically_on_load(false);
            firstData = STBImage.stbi_loadf(firstPath.toString(), w, h, c, 0);
            if (firstData == null)
                throw new IOException("stbi_loadf: " + STBImage.stbi_failure_reason());
            width = w.get(0);
            height = h.get(0);
            channels = c.get(0);
        }

        if (useRGB) {
            if (channels < 3)
                throw new IOException("Slice has fewer than 3 channels but RGB requested");
        } else {

            channels = 1;
        }


        int texelCount = width * height * depth;
        int components = useRGB ? 3 : 1;
        FloatBuffer volume = MemoryUtil.memAllocFloat(texelCount * components);


        copySlice(firstData, volume, 0, width * height, components, useRGB);
        STBImage.stbi_image_free(firstData);


        for (int z = 1; z < depth; z++) {
            Path slicePath = directory.resolve(String.format(Locale.US, "%s_%03d.exr", baseName, z));
            if (!Files.isRegularFile(slicePath))
                throw new IOException("Missing slice: " + slicePath);
            try (MemoryStack stack = MemoryStack.stackPush()) {
                IntBuffer w = stack.mallocInt(1);
                IntBuffer h = stack.mallocInt(1);
                IntBuffer c = stack.mallocInt(1);
                FloatBuffer data = STBImage.stbi_loadf(slicePath.toString(), w, h, c, 0);
                if (data == null)
                    throw new IOException("stbi_loadf: " + STBImage.stbi_failure_reason());
                if (w.get(0) != width || h.get(0) != height)
                    throw new IOException("Slice dimensions mismatch in " + slicePath);
                copySlice(data, volume, z, width * height, components, useRGB);
                STBImage.stbi_image_free(data);
            }
        }
        volume.flip();


        int tex = GL45.glCreateTextures(GL45.GL_TEXTURE_3D);
        int internalFormat = useRGB ? GL45.GL_RGB32F : GL45.GL_R32F;
        int format = useRGB ? GL45.GL_RGB : GL45.GL_RED;
        GL45.glTextureStorage3D(tex, 1, internalFormat, width, height, depth);
        GL45.glTextureSubImage3D(tex, 0, 0, 0, 0, width, height, depth, format, GL45.GL_FLOAT, volume);
        GL45.glTextureParameteri(tex, GL45.GL_TEXTURE_MIN_FILTER, GL45.GL_LINEAR);
        GL45.glTextureParameteri(tex, GL45.GL_TEXTURE_MAG_FILTER, GL45.GL_LINEAR);
        GL45.glTextureParameteri(tex, GL45.GL_TEXTURE_WRAP_S, GL45.GL_REPEAT);
        GL45.glTextureParameteri(tex, GL45.GL_TEXTURE_WRAP_T, GL45.GL_REPEAT);
        GL45.glTextureParameteri(tex, GL45.GL_TEXTURE_WRAP_R, GL45.GL_REPEAT);

        MemoryUtil.memFree(volume);
        return new NoiseTexture3D(tex, width, height, depth);
    }


    private static void copySlice(FloatBuffer src, FloatBuffer dst, int sliceIndex, int sliceSize, int components, boolean useRGB) {
        int dstPos = sliceIndex * sliceSize * components;
        if (useRGB) {
            for (int i = 0; i < sliceSize; i++) {
                dst.put(dstPos + i * 3, src.get(i * 3));
                dst.put(dstPos + i * 3 + 1, src.get(i * 3 + 1));
                dst.put(dstPos + i * 3 + 2, src.get(i * 3 + 2));
            }
        } else {
            for (int i = 0; i < sliceSize; i++) {

                float r = src.get(i * 3);
                float g = (src.capacity() / sliceSize >= 2) ? src.get(i * 3 + 1) : r;
                float b = (src.capacity() / sliceSize >= 3) ? src.get(i * 3 + 2) : r;
                dst.put(dstPos + i, (r + g + b) / 3.0f);
            }
        }
    }


    public int getId() {
        return id;
    }


    public void delete() {
        GL45.glDeleteTextures(id);
    }

    public void bind(int unit) {
        glActiveTexture(GL_TEXTURE0 + unit);
        glBindTexture(GL_TEXTURE_3D, id);
    }

}


