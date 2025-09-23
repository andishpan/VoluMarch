package org.java.render;


import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL30.*;
import static org.lwjgl.opengl.GL42.*;
import static org.lwjgl.opengl.GL43.glClearBufferSubData;

import java.nio.ByteBuffer;


import org.lwjgl.BufferUtils;
import org.java.utility.*;

class SettingsUBO {
    private static final int BINDING = 1;
    private final int ubo;
    private final ByteBuffer buf;

    SettingsUBO() {
        ubo = glGenBuffers();
        buf = BufferUtils.createByteBuffer(216);
        glBindBuffer(GL_UNIFORM_BUFFER, ubo);
        glBufferData(GL_UNIFORM_BUFFER, buf.capacity(), GL_DYNAMIC_DRAW);
        glBindBufferBase(GL_UNIFORM_BUFFER, BINDING, ubo);

    }

    void update(RenderSettings rs, float time) {
        buf.clear();

        putVec3(rs.cameraPos);
        buf.putFloat(0);
        putVec3(rs.cameraLookAt);
        buf.putFloat(0);
        putVec3(rs.cameraUp);
        buf.putFloat(0);

        buf.putFloat(rs.resolutionX)
                .putFloat(rs.resolutionY)
                .putFloat(1.0f)
                .putFloat(time);

        putVec3(rs.sunDirection);
        buf.putFloat(rs.sunIntensity);


        putVec3(rs.sunColour);
        buf.putFloat(rs.ambientLight);

        buf.putInt(rs.currentMethod)
                .putFloat(rs.volumetricAbsorption)
                .putFloat(rs.volumetricScattering)
                .putFloat(rs.phaseG);


        buf.putInt(rs.currentShape)
                .putInt(rs.previousShape)
                .putFloat(rs.shapeTransition);


        buf.putInt(rs.currentNoise)
                .putFloat(rs.noiseScale)
                .putFloat(rs.noiseHeight)
                .putInt(rs.tilePeriod);

        buf.putInt(rs.noiseOctaves)
                .putInt(rs.numMosOctaves)
                .putFloat(0.0f)
                .putInt(rs.maxSteps)
                .putInt(rs.maxVolumeSteps)
                .putInt(rs.maxShadowSteps);

        buf.putFloat(rs.stepSize)
                .putFloat(rs.shadowStepSize)
                .putFloat(rs.forwardScattering)
                .putFloat(rs.backwardScattering);

        buf.putFloat(rs.powderStrength)
                .putFloat(rs.sdfBlendRadius)
                .putInt(rs.useBlueNoise ? 1 : 0)
        .putInt(rs.useCubeMap ? 1 : 0);
        buf.putFloat(0.0f);

        buf.putFloat(rs.transmittanceThreshold);
        buf.putFloat(rs.sdfHitThreshold);
        buf.putFloat(rs.noiseJitter);
        buf.putFloat(rs.maxRayDistance);


        buf.flip();
        glBindBuffer(GL_UNIFORM_BUFFER, ubo);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, buf);


    }


    private void putVec3(Vector3f v) {
        buf.putFloat(v.x).putFloat(v.y).putFloat(v.z);
    }
}

