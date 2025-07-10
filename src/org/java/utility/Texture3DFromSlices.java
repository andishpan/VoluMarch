package org.java.utility;

import org.lwjgl.BufferUtils;
import org.lwjgl.stb.STBImage;

import java.nio.ByteBuffer;
import java.nio.IntBuffer;

import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL12.GL_TEXTURE_3D;
import static org.lwjgl.opengl.GL12.GL_TEXTURE_WRAP_R;
import static org.lwjgl.opengl.GL13C.GL_TEXTURE0;
import static org.lwjgl.opengl.GL13C.glActiveTexture;
import static org.lwjgl.opengl.GL30.glTexImage3D;

public class Texture3DFromSlices {
    private final int textureID;

    public Texture3DFromSlices(String directory, String filenamePrefix, int width, int height, int depth) {
        textureID = glGenTextures();
        glBindTexture(GL_TEXTURE_3D, textureID);

        ByteBuffer fullVolume = BufferUtils.createByteBuffer(width * height * depth * 4);

        for (int z = 0; z < depth; z++) {
            String path = String.format("%s/%s%d.png", directory, filenamePrefix, z);
            IntBuffer w = BufferUtils.createIntBuffer(1);
            IntBuffer h = BufferUtils.createIntBuffer(1);
            IntBuffer comp = BufferUtils.createIntBuffer(1);

            ByteBuffer slice = STBImage.stbi_load(path, w, h, comp, 4);
            if (slice == null) {
                throw new RuntimeException("Failed to load slice: " + path);
            }

            fullVolume.put(slice);
            slice.rewind();
            STBImage.stbi_image_free(slice);

        }
        fullVolume.flip();

        glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA8, width, height, depth, 0,
                GL_RGBA, GL_UNSIGNED_BYTE, fullVolume);

        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_REPEAT);

        glBindTexture(GL_TEXTURE_3D, 0);
    }

    public void bind(int unit) {
        glActiveTexture(GL_TEXTURE0 + unit);
        glBindTexture(GL_TEXTURE_3D, textureID);
    }

    public void delete() {
        glDeleteTextures(textureID);
    }

    public int getId() {
        return textureID;
    }
}
