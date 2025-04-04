import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL12.*;
import static org.lwjgl.opengl.GL30.*;

import java.io.FileInputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.channels.FileChannel;
import java.util.Random;

import org.lwjgl.BufferUtils;

public class Texture3D {
    private final int textureID;

    public Texture3D(String filePath, int width, int height, int depth) {
        textureID = glGenTextures();
        glBindTexture(GL_TEXTURE_3D, textureID);


        ByteBuffer buffer = BufferUtils.createByteBuffer(width * height * depth * Float.BYTES);
        try (FileChannel channel = new FileInputStream(filePath).getChannel()) {
            channel.read(buffer);
        } catch (IOException e) {
            throw new RuntimeException("Failed to load 3D noise texture", e);
        }
        buffer.flip();


        glTexImage3D(GL_TEXTURE_3D, 0, GL_R32F, width, height, depth, 0,
                GL_RED, GL_FLOAT, buffer);


        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
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
