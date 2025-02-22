import org.lwjgl.BufferUtils;

import java.nio.FloatBuffer;
import java.nio.IntBuffer;

import static org.lwjgl.opengl.GL20.*;

public class Material {
    public Vector3f albedo;
    public Vector3f emissive;
    public int flags;

    public Material(Vector3f albedo, Vector3f emissive, int flags) {
        this.albedo = albedo;
        this.emissive = emissive;
        this.flags = flags;
    }

    public static void uploadMaterialUniforms(int programID, Material[] materials) {
        // Locate uniform locations
        int albedoLoc = glGetUniformLocation(programID, "uAlbedo");
        int emissiveLoc = glGetUniformLocation(programID, "uEmissive");
        int flagsLoc = glGetUniformLocation(programID, "uFlags");

        // Prepare data buffers
        FloatBuffer albedoBuffer = BufferUtils.createFloatBuffer(materials.length * 3);
        FloatBuffer emissiveBuffer = BufferUtils.createFloatBuffer(materials.length * 3);
        IntBuffer flagsBuffer = BufferUtils.createIntBuffer(materials.length);

        for (Material mat : materials) {
            albedoBuffer.put(new float[]{mat.albedo.x, mat.albedo.y, mat.albedo.z});
            emissiveBuffer.put(new float[]{mat.emissive.x, mat.emissive.y, mat.emissive.z});
            flagsBuffer.put(mat.flags);
        }

        albedoBuffer.flip();
        emissiveBuffer.flip();
        flagsBuffer.flip();
// Example of checking uniform locations




        // Upload to shader
        glUniform3fv(albedoLoc, albedoBuffer);
        glUniform3fv(emissiveLoc, emissiveBuffer);
        glUniform1iv(flagsLoc, flagsBuffer);
    }
}
