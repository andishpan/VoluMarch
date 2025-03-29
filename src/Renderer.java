import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL30.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.system.MemoryUtil.*;

import java.nio.ByteBuffer;
import java.nio.IntBuffer;

import org.lwjgl.BufferUtils;

public class Renderer {
    private int vaoID;
    private int vboID;
    private int eboID;

    private ShaderProgram shader;

    public Renderer(ShaderProgram shader) {
        this.shader = shader;
        createQuad();
    }

    private void createQuad() {
        float[] vertices = {
                -1.0f, -1.0f, 0.0f,
                1.0f, -1.0f, 0.0f,
                1.0f,  1.0f, 0.0f,
                -1.0f,  1.0f, 0.0f
        };
        int[] indices = {
                0, 1, 2,
                2, 3, 0
        };

        vaoID = glGenVertexArrays();
        glBindVertexArray(vaoID);


        vboID = glGenBuffers();
        glBindBuffer(GL_ARRAY_BUFFER, vboID);
        ByteBuffer vertexBuffer = BufferUtils.createByteBuffer(vertices.length * 4);
        vertexBuffer.asFloatBuffer().put(vertices).flip();
        glBufferData(GL_ARRAY_BUFFER, vertexBuffer, GL_STATIC_DRAW);


        eboID = glGenBuffers();
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eboID);
        IntBuffer indexBuffer = BufferUtils.createIntBuffer(indices.length);
        indexBuffer.put(indices).flip();
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexBuffer, GL_STATIC_DRAW);


        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, false, 3 * 4, 0L);

        glBindVertexArray(0);
    }

        public void render(
            float elapsedTime, float width, float height,
            float mouseX, float mouseY, boolean mouseDown,
            Vector3f cameraPos, Vector3f cameraLookAt, Vector3f cameraUp,
            int currentShape, int currentMethod, Material[] materials, Texture blueNoise) {

        shader.bind();


        shader.setUniform("uObjectShape", currentShape);
        shader.setUniform("uCurrentMethod", currentMethod);
        Material.uploadMaterialUniforms(shader.getID(), materials);

        shader.setUniform("iTime", elapsedTime);
        shader.setUniform("iResolution", width, height, 1.0f);

        float mx = mouseDown ? mouseX : 0.0f;
        float my = mouseDown ? mouseY : 0.0f;
        shader.setUniform("iMouse", mx, my, 0.0f, 0.0f);


        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, blueNoise.getId());
        shader.setUniform("iChannel0", 0);








        Vector3f sunDirection = new Vector3f(-0.8f, 0.2f, -1.0f);
        sunDirection.normalize();



        float sunIntensity = 1.2f;


        shader.setUniform("uSunDirection", sunDirection.x, sunDirection.y, sunDirection.z);
        shader.setUniform("uSunIntensity", sunIntensity);




        Matrix4 viewMatrix = Matrix4.lookAt(cameraPos, cameraLookAt, cameraUp);
        shader.setUniformMatrix4fv("uViewMatrix", viewMatrix.getValuesAsArray());



        glBindVertexArray(vaoID);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);

        glBindTexture(GL_TEXTURE_2D, 0);
        shader.unbind();
    }


    public void cleanup() {
        glDeleteVertexArrays(vaoID);
        glDeleteBuffers(vboID);
        glDeleteBuffers(eboID);
    }
}
