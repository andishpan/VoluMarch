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

        // Create VBO for vertex data.
        vboID = glGenBuffers();
        glBindBuffer(GL_ARRAY_BUFFER, vboID);
        ByteBuffer vertexBuffer = BufferUtils.createByteBuffer(vertices.length * 4);
        vertexBuffer.asFloatBuffer().put(vertices).flip();
        glBufferData(GL_ARRAY_BUFFER, vertexBuffer, GL_STATIC_DRAW);

        // Create EBO for indices.
        eboID = glGenBuffers();
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eboID);
        IntBuffer indexBuffer = BufferUtils.createIntBuffer(indices.length);
        indexBuffer.put(indices).flip();
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexBuffer, GL_STATIC_DRAW);

        // Set up the vertex attribute pointer (location 0 for positions).
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, false, 3 * 4, 0L);

        glBindVertexArray(0);
    }

    /**
     * Renders the scene using the same uniform setup as your original code.
     *
     * @param elapsedTime   Elapsed time in seconds.
     * @param width         Window width.
     * @param height        Window height.
     * @param mouseX        Current mouse X position.
     * @param mouseY        Current mouse Y position.
     * @param mouseDown     Whether the mouse button is pressed.
     * @param cameraPos     Camera position vector.
     * @param cameraLookAt  Camera look-at vector.
     * @param cameraUp      Camera up vector.
     * @param currentShape  Object shape mode.
     * @param currentMethod Rendering method mode.
     * @param materials     Array of Material objects.
     * @param skyTexture    The Texture object for the sky.
     */
    public void render(
            float elapsedTime, float width, float height,
            float mouseX, float mouseY, boolean mouseDown,
            Vector3f cameraPos, Vector3f cameraLookAt, Vector3f cameraUp,
            int currentShape, int currentMethod, Material[] materials, Texture skyTexture) {

        shader.bind();

        // Set object/method mode uniforms.
        shader.setUniform("uObjectShape", currentShape);
        shader.setUniform("uCurrentMethod", currentMethod);
        Material.uploadMaterialUniforms(shader.getID(), materials);

        // Set time and resolution uniforms.
        shader.setUniform("iTime", elapsedTime);
        shader.setUniform("iResolution", width, height, 1.0f);

        // Set mouse uniform: if mouse is down, use its position; otherwise (0,0).
        float mx = mouseDown ? mouseX : 0.0f;
        float my = mouseDown ? mouseY : 0.0f;
        shader.setUniform("iMouse", mx, my, 0.0f, 0.0f);

        // Bind the sky texture to texture unit 0 and set sampler uniform.
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, skyTexture.getId());
        shader.setUniform("iChannel0", 0);

        // Compute a rotated camera position based on mouse X, as in the original code.
        float rotationAngle = (mx / width - 0.5f) * (float)Math.PI * 0.4f;
        float cosAngle = (float)Math.cos(rotationAngle);
        float sinAngle = (float)Math.sin(rotationAngle);
        Vector3f rotatedPos = new Vector3f(
                cameraPos.x * cosAngle - cameraPos.z * sinAngle,
                cameraPos.y,
                cameraPos.x * sinAngle + cameraPos.z * cosAngle);

        // Create a view matrix from the rotated camera position.
        Matrix4 viewMatrix = Matrix4.lookAt(rotatedPos, cameraLookAt, cameraUp);
        shader.setUniformMatrix4fv("uViewMatrix", viewMatrix.getValuesAsArray());

        // Draw the fullscreen quad.
        glBindVertexArray(vaoID);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);

        // Unbind texture.
        glBindTexture(GL_TEXTURE_2D, 0);
        shader.unbind();
    }

    public void cleanup() {
        glDeleteVertexArrays(vaoID);
        glDeleteBuffers(vboID);
        glDeleteBuffers(eboID);
    }
}
