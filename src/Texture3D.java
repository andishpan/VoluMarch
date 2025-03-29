import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL12.*;
import static org.lwjgl.opengl.GL30.*;

import java.nio.FloatBuffer;
import java.util.Random;

import org.lwjgl.BufferUtils;

public class Texture3D {
    private int id;
    private int width;
    private int height;
    private int depth;
    private Random random;

    public Texture3D(String resourceName, int width, int height, int depth) {
        this.width = width;
        this.height = height;
        this.depth = depth;
        this.random = new Random();
        create3DTextureDefault(resourceName);
    }

    private float hash(float n) {
        return (float) (Math.sin(n) * 43758.5453123);
    }

    private float lerp(float t, float a, float b) {
        return a + t * (b - a);
    }

    private float fade(float t) {
        return t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f);
    }

    private float grad(int hash, float x) {
        return (hash & 1) == 0 ? x : -x;
    }

    private float grad(int hash, float x, float y) {
        int h = hash & 7;
        float u = h < 4 ? x : y;
        float v = h < 4 ? y : x;
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? 2.0f * v : -2.0f * v);
    }

    private float grad(int hash, float x, float y, float z) {
        int h = hash & 15;
        float u = h < 8 ? x : y;
        float v = h < 4 ? y : h == 12 || h == 14 ? x : z;
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
    }

    private float perlinNoise(float x, float y, float z) {
        int X = (int) Math.floor(x) & 255;
        int Y = (int) Math.floor(y) & 255;
        int Z = (int) Math.floor(z) & 255;

        x -= Math.floor(x);
        y -= Math.floor(y);
        z -= Math.floor(z);

        float u = fade(x);
        float v = fade(y);
        float w = fade(z);

        int A = random.nextInt(256) & 255;
        int B = random.nextInt(256) & 255;
        int AA = random.nextInt(256) & 255;
        int AB = random.nextInt(256) & 255;
        int BA = random.nextInt(256) & 255;
        int BB = random.nextInt(256) & 255;
        int AAA = random.nextInt(256) & 255;
        int AAB = random.nextInt(256) & 255;
        int ABA = random.nextInt(256) & 255;
        int ABB = random.nextInt(256) & 255;
        int BAA = random.nextInt(256) & 255;
        int BAB = random.nextInt(256) & 255;
        int BBA = random.nextInt(256) & 255;
        int BBB = random.nextInt(256) & 255;

        float result = lerp(w, lerp(v, lerp(u, grad(AAA, x, y, z), grad(BAA, x-1, y, z)),
                                     lerp(u, grad(ABA, x, y-1, z), grad(BBA, x-1, y-1, z))),
                             lerp(v, lerp(u, grad(AAB, x, y, z-1), grad(BAB, x-1, y, z-1)),
                                     lerp(u, grad(ABB, x, y-1, z-1), grad(BBB, x-1, y-1, z-1))));

        return result * 0.5f + 0.5f;
    }

    private float worleyNoise(float x, float y, float z) {
        float minDist = Float.MAX_VALUE;
        float secondMinDist = Float.MAX_VALUE;

        int X = (int) Math.floor(x);
        int Y = (int) Math.floor(y);
        int Z = (int) Math.floor(z);

        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
                for (int k = -1; k <= 1; k++) {
                    float px = X + i + random.nextFloat();
                    float py = Y + j + random.nextFloat();
                    float pz = Z + k + random.nextFloat();

                    float dx = x - px;
                    float dy = y - py;
                    float dz = z - pz;

                    float dist = dx * dx + dy * dy + dz * dz;

                    if (dist < minDist) {
                        secondMinDist = minDist;
                        minDist = dist;
                    } else if (dist < secondMinDist) {
                        secondMinDist = dist;
                    }
                }
            }
        }

        return (float) Math.sqrt(minDist) - (float) Math.sqrt(secondMinDist);
    }

    private float perlinWorleyNoise(float x, float y, float z) {
        float perlin = perlinNoise(x, y, z);
        float worley = worleyNoise(x, y, z);
        return lerp(0.5f, perlin, worley);
    }

    private void create3DTexture(String resourceName) {
        id = glGenTextures();
        glBindTexture(GL_TEXTURE_3D, id);

        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_REPEAT);

        FloatBuffer buffer = BufferUtils.createFloatBuffer(width * height * depth);

        try {
            for (int z = 0; z < depth; z++) {
                for (int y = 0; y < height; y++) {
                    for (int x = 0; x < width; x++) {
                        float nx = (float) x / width;
                        float ny = (float) y / height;
                        float nz = (float) z / depth;

                        // pelin-worley
                        float noise = 0.0f;
                        float scale = 1.0f;
                        float weight = 0.5f;
                        float totalWeight = 0.0f;

                        for (int i = 0; i < 8; i++) {
                            noise += perlinWorleyNoise(nx * scale, ny * scale, nz * scale) * weight;
                            totalWeight += weight;
                            scale *= 2.0f;
                            weight *= 0.5f;
                        }

                        noise /= totalWeight;
                        buffer.put(noise);
                    }
                }
            }
            buffer.flip();

            glTexImage3D(GL_TEXTURE_3D, 0, GL_R32F, width, height, depth, 0, GL_RED, GL_FLOAT, buffer);
        } catch (Exception e) {
            System.err.println("Warning: Failed to load 3D texture: " + resourceName);
            System.err.println("Using procedural noise instead.");
            throw new RuntimeException("Failed to create 3D texture", e);
        }
    }

    private void create3DTextureDefault(String resourceName) {

        id = glGenTextures();
        glBindTexture(GL_TEXTURE_3D, id);


        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_REPEAT);


        FloatBuffer buffer = BufferUtils.createFloatBuffer(width * height * depth);

        try {

            for (int z = 0; z < depth; z++) {
                for (int y = 0; y < height; y++) {
                    for (int x = 0; x < width; x++) {

                        float nx = (float) x / width;
                        float ny = (float) y / height;
                        float nz = (float) z / depth;
                        float noise = (float) (
                                Math.sin(nx * 10.0f) *
                                        Math.cos(ny * 10.0f) *
                                        Math.sin(nz * 10.0f) +
                                        Math.sin(nx * 20.0f + ny * 15.0f) *
                                                Math.cos(ny * 20.0f + nz * 15.0f) *
                                                Math.sin(nz * 20.0f + nx * 15.0f)
                        ) * 0.5f;
                        buffer.put(noise);
                    }
                }
            }
            buffer.flip();


            glTexImage3D(GL_TEXTURE_3D, 0, GL_R32F, width, height, depth, 0, GL_RED, GL_FLOAT, buffer);
        } catch (Exception e) {
            System.err.println("Warning: Failed to load 3D texture: " + resourceName);
            System.err.println("Using procedural noise instead.");
            throw new RuntimeException("Failed to create 3D texture", e);
        }
    }


    public void delete() {
        glDeleteTextures(id);
    }

    public int getId() {
        return id;
    }

    public void bind(int textureUnit) {
        glActiveTexture(GL_TEXTURE0 + textureUnit);
        glBindTexture(GL_TEXTURE_3D, id);
    }
} 