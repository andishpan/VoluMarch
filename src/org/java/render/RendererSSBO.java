package org.java.render;

import static org.lwjgl.opengl.ARBClearBufferObject.glClearBufferData;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL30.*;
import static org.lwjgl.opengl.GL42.*;
import static org.lwjgl.opengl.GL43.glClearBufferSubData;
import static org.lwjgl.opengl.GL43C.GL_SHADER_STORAGE_BARRIER_BIT;
import static org.lwjgl.opengl.GL43C.GL_SHADER_STORAGE_BUFFER;

import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;


import org.lwjgl.BufferUtils;
import org.java.utility.*;

public class RendererSSBO {
    private final SettingsUBO settingsUBO = new SettingsUBO();
    private final int[] atomicBuffers = new int[2];
    Vector3f cloudCenter = new Vector3f(0.0f, 20.0f, -25.0f);
    private int vaoID;
    private int vboID;
    private int eboID;
    private int fboID = 0;
    private int colorTexID = 0;
    private int stepsTexID = 0;
    private int distanceTexID = 0;
    private int[] ssboBuffers = new int[2];
    private int frameIndex = 0;
    private int lastVolume, lastShadow, lastSdf, lastPixels;
    private int lastEntryCount;
    private float distanceToCloud = 0f;
    private float lastDistance = 0f;
    private ShaderProgram shader;
    private int currentFboW = -1, currentFboH = -1;
    private FloatBuffer distanceBuffer;
    public RendererSSBO(ShaderProgram shader) {
        this.shader = shader;
        createQuad();

        createSsboBuffers();
    }

    public float getLastDistance() {
        return lastDistance;
    }

    public void setShader(ShaderProgram shader) {
        this.shader = shader;
    }


    private void createQuad() {
        float[] vertices = {-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0};
        int[] indices = {0, 1, 2, 2, 3, 0};

        vaoID = glGenVertexArrays();
        glBindVertexArray(vaoID);

        vboID = glGenBuffers();
        glBindBuffer(GL_ARRAY_BUFFER, vboID);
        ByteBuffer vBuffer = BufferUtils.createByteBuffer(vertices.length * 4);
        vBuffer.asFloatBuffer().put(vertices).flip();
        glBufferData(GL_ARRAY_BUFFER, vBuffer, GL_STATIC_DRAW);

        eboID = glGenBuffers();
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eboID);
        IntBuffer iBuffer = BufferUtils.createIntBuffer(indices.length);
        iBuffer.put(indices).flip();
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, iBuffer, GL_STATIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, false, 3 * 4, 0L);
        glBindVertexArray(0);
    }


    private void createSsboBuffers() {
        final int BYTES = 4 * Integer.BYTES;
        for (int k = 0; k < 2; ++k) {
            ssboBuffers[k] = glGenBuffers();
            glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboBuffers[k]);
            glBufferData(GL_SHADER_STORAGE_BUFFER, BYTES, GL_DYNAMIC_DRAW);
        }
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
    }

    private void zeroSsboBuffer(int id) {
        IntBuffer zero = BufferUtils.createIntBuffer(4);
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, id);
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, id);
        glClearBufferData(
                GL_SHADER_STORAGE_BUFFER,
                GL_R32UI,           // still the element format
                GL_RED_INTEGER,
                GL_UNSIGNED_INT,
                (ByteBuffer) null
        );
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

    }


    private void ensureFbo(int w, int h) {

        if (fboID != 0 && (w != currentFboW || h != currentFboH)) {

            glDeleteFramebuffers(fboID);
            glDeleteTextures(colorTexID);
            glDeleteTextures(distanceTexID);
            fboID = colorTexID = distanceTexID = 0;
        }
        if (fboID != 0) return;
        currentFboW = w;
        currentFboH = h;


        colorTexID = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, colorTexID);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, (ByteBuffer) null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);


        distanceTexID = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, distanceTexID);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, w, h, 0, GL_RED, GL_FLOAT, (ByteBuffer) null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);


        fboID = glGenFramebuffers();
        glBindFramebuffer(GL_FRAMEBUFFER, fboID);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorTexID, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, distanceTexID, 0);


        glDrawBuffers(new int[]{GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1});

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            throw new IllegalStateException("FBO not complete!");

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }


    public float getDistanceToCloud() {
        return distanceToCloud;
    }


    public void render(
            float elapsedTime, float width, float height, RenderSettings settings

    ) {


        zeroSsboBuffer(ssboBuffers[frameIndex]);

        glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssboBuffers[frameIndex]);

        shader.bind();

        settingsUBO.update(settings, elapsedTime);


        distanceToCloud = settings.cameraPos.subtract(cloudCenter).length();



        shader.setUniform1i("uBlueNoise", 0);

        shader.setUniform1i("uPrecomputedNoise", 2);

        shader.setUniform1i("uEnvironmentMap", 3);




//        glActiveTexture(GL_TEXTURE0 + 3);
//        glBindTexture(GL_TEXTURE_CUBE_MAP, environmentMapTexID);


        Matrix4 viewMatrix = Matrix4.lookAt(settings.cameraPos, settings.cameraLookAt, settings.cameraUp);
        shader.setUniformMatrix4fv("uViewMatrix", viewMatrix.getValuesAsArray());

        ensureFbo((int) width, (int) height);
        glBindFramebuffer(GL_FRAMEBUFFER, fboID);
        glViewport(0, 0, (int) width, (int) height);

        glBindVertexArray(vaoID);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);

        glBindFramebuffer(GL_FRAMEBUFFER, 0);

        glBindFramebuffer(GL_READ_FRAMEBUFFER, fboID);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
        glBlitFramebuffer(0, 0, (int) width, (int) height, 0, 0, (int) width, (int) height,
                GL_COLOR_BUFFER_BIT, GL_NEAREST);

//        shader.unbind();
//        glBindTexture(GL_TEXTURE_2D, 0);


        glMemoryBarrier(GL_SHADER_STORAGE_BARRIER_BIT);


        int prev = frameIndex ^ 1;
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, ssboBuffers[prev]);


        IntBuffer counters = BufferUtils.createIntBuffer(4);
        glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, counters);

        lastVolume = counters.get(0);
        lastShadow = counters.get(1);
        lastSdf = counters.get(2);
        lastEntryCount = counters.get(3);
        lastPixels = (int) (width * height);


        zeroSsboBuffer(ssboBuffers[prev]);
        glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);


        frameIndex ^= 1;

         distanceBuffer = BufferUtils.createFloatBuffer((int) (width * height));
        glBindTexture(GL_TEXTURE_2D, distanceTexID);
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RED, GL_FLOAT, distanceBuffer);


        double totalDistance = 0;
        int count = 0;
        while (distanceBuffer.hasRemaining()) {
            float d = distanceBuffer.get();
            if (Float.isFinite(d)) {
                totalDistance += d;
                ++count;
            }
        }
        float avgDistanceCPU = (count > 0) ? (float) (totalDistance / count) : 0f;


        this.lastDistance = avgDistanceCPU;


    }


    public LoopStats fetchLoopStats(int w, int h) {
        int totalPx = Math.max(lastPixels, 1);
        int cloudPx = Math.max(lastEntryCount, 1);

        float volumePerPixel = lastVolume / (float) totalPx;
        float shadowPerPixel = lastShadow / (float) totalPx;
        float sdfPerPixel = lastSdf / (float) totalPx;
        float spp = (volumePerPixel + shadowPerPixel + sdfPerPixel);

        float volumePerHit = lastVolume / (float) cloudPx;
        float shadowPerHit = lastShadow / (float) cloudPx;
        float sdfPerHit = lastSdf / (float) cloudPx;
        float sph = volumePerHit + shadowPerHit + sdfPerHit;


        float hitRatio = (float) lastEntryCount / totalPx;

        return new LoopStats(
                volumePerHit,
                shadowPerHit,
                sdfPerHit,
                cloudPx,
                totalPx,
                spp,
                sph,
                hitRatio);
    }

    public void cleanup() {

        for (int id : ssboBuffers) if (id != 0) glDeleteBuffers(id);

        if (colorTexID != 0) glDeleteTextures(colorTexID);
        if (fboID != 0) glDeleteFramebuffers(fboID);

        glDeleteVertexArrays(vaoID);
        glDeleteBuffers(vboID);
        glDeleteBuffers(eboID);
    }

    public record LoopStats(float volume, float shadow, float sdf, float entryCount, float pixels,
                            float spp, float sph, float hitRatio) {
    }
}