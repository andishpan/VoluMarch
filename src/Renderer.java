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
     * @param blueNoise    The Texture object for the sky.
     */
    public void render(
            float elapsedTime, float width, float height,
            float mouseX, float mouseY, boolean mouseDown,
            Vector3f cameraPos, Vector3f cameraLookAt, Vector3f cameraUp,
            int currentShape, int currentMethod, Material[] materials, Texture blueNoise) {

        shader.bind();

        // Set your existing uniforms
        shader.setUniform("uObjectShape", currentShape);
        shader.setUniform("uCurrentMethod", currentMethod);
        Material.uploadMaterialUniforms(shader.getID(), materials);

        shader.setUniform("iTime", elapsedTime);
        shader.setUniform("iResolution", width, height, 1.0f);

        float mx = mouseDown ? mouseX : 0.0f;
        float my = mouseDown ? mouseY : 0.0f;
        shader.setUniform("iMouse", mx, my, 0.0f, 0.0f);

        // Bind the sky texture to texture unit 0 and set its uniform
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, blueNoise.getId());
        shader.setUniform("iChannel0", 0);

        // ---------------------------------------------------------
        // NEW SUN UNIFORMS SETUP
        // ---------------------------------------------------------
        // Sun direction (coming from above and slightly behind the camera)
        //Vector3f sunDirection = new Vector3f(0.0f, 0.7f, -0.7f); // Sun coming from above and slightly behind
       // Vector3f sunDirection = new Vector3f(0.0f, 0.2f, -1.0f); // near horizon
        //sunDirection.normalize();
        Vector3f sunDirection = new Vector3f(-0.8f, 0.2f, -1.0f);
        sunDirection.normalize();


      //  sunDirection.normalize(); // Ensure the direction is normalized
        float sunIntensity = 1.2f; // Increase for a brighter sun

        // Pass the sun uniforms to the shader.
        shader.setUniform("uSunDirection", sunDirection.x, sunDirection.y, sunDirection.z);
        shader.setUniform("uSunIntensity", sunIntensity);
        // ---------------------------------------------------------

        // Compute a simple rotation for the camera based on the mouse X position.
      /*  float rotationAngle = (mx / width - 0.5f) * (float)Math.PI * 0.4f;
        float cosAngle = (float)Math.cos(rotationAngle);
        float sinAngle = (float)Math.sin(rotationAngle);
        Vector3f rotatedPos = new Vector3f(
                cameraPos.x * cosAngle - cameraPos.z * sinAngle,
                cameraPos.y,
                cameraPos.x * sinAngle + cameraPos.z * cosAngle); */

        Matrix4 viewMatrix = Matrix4.lookAt(new Vector3f(0.0f,0.0f,0.0f), cameraLookAt, cameraUp);
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
