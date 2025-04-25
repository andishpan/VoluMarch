package render;

import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL30.*;

import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import util.*;


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

    public void setShader(ShaderProgram shader) {
        this.shader = shader;
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
            float elapsedTime, float width, float height, RenderSettings settings, Material[] materials, Texture blueNoise, Texture3D noiseTexture3D

    ) {
        shader.bind();

        shader.setUniform("uCameraPosition",settings.cameraPos.x, settings.cameraPos.y, settings.cameraPos.z);
        shader.setUniform("uCameraLookAt",settings.cameraLookAt.x, settings.cameraLookAt.y, settings.cameraLookAt.z);
        shader.setUniform("uCameraUp",settings.cameraUp.x, settings.cameraUp.y, settings.cameraUp.z);






        shader.setUniform("uObjectShape", settings.currentShape);
        shader.setUniform("uCurrentMethod", settings.currentMethod);
        shader.setUniform("uCurrentNoise", settings.currentNoise);


        shader.setUniform("uPrevShape", settings.previousShape);
        shader.setUniform("uShapeTransition", settings.shapeTransition);

        //noise
        shader.setUniform("uNoiseScale", settings.noiseScale);
        shader.setUniform("uNoiseHeight", settings.noiseHeight);

       //TODO:
       // shader.setUniform("uUseBlueNoise", settings.useBlueNoise);

        //scattering
        shader.setUniform("uForwardScattering", settings.forwardScattering);
        shader.setUniform("uBackwardScattering", settings.backwardScattering);



        shader.setUniform("uAmbientLight", settings.ambientLight);

        Vector3f volumetricAlbedo = new Vector3f(settings.volumetricAlbedo[0], settings.volumetricAlbedo[1], settings.volumetricAlbedo[2]);
        shader.setUniform("uVolumetricAlbedo", volumetricAlbedo.x, volumetricAlbedo.y, volumetricAlbedo.z);




        //steps
        shader.setUniform("uMaxSteps", settings.maxSteps);
        shader.setUniform("uMaxVolumeSteps", settings.maxVolumeSteps);
        shader.setUniform("uMaxShadowMarchSteps", settings.maxShadowMarchSteps);
        shader.setUniform("uMaxLightMarchSteps",settings.maxLightMarchSteps);

        noiseTexture3D.bind(2);
        shader.setUniform("uPrecomputedNoise", 2);


        Material.uploadMaterialUniforms(shader.getID(), materials);


        shader.setUniform("uTime", elapsedTime);
        shader.setUniform("uResolution", width, height, 1.0f);

        // float mx = mouseDown ? mouseX : 0.0f;
        // float my = mouseDown ? mouseY : 0.0f;
        //shader.setUniform("uMouse", 0.0f, 0.0f, 0.0f, 0.0f);


        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, blueNoise.getId());
        shader.setUniform("iChannel0", 0);



        Vector3f sunDir = new Vector3f(settings.sunDirection[0], settings.sunDirection[1], settings.sunDirection[2]).normalize();
        shader.setUniform("uSunDirection", sunDir.x, sunDir.y, sunDir.z);
        shader.setUniform("uSunIntensity", settings.sunIntensity);


        shader.setUniform("uVolumetricAbsorption", settings.volumetricAbsorption);


        Matrix4 viewMatrix = Matrix4.lookAt(settings.cameraPos, settings.cameraLookAt, settings.cameraUp);
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
