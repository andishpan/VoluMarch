import org.lwjgl.BufferUtils;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL30.*;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;

public class TextRenderer {
    private int fontTextureID;
    private int textProgramID;
    private int textVaoID;
    private int textVboID;
    private Matrix4 orthoProjection;
    private FloatBuffer orthoBuffer;

    // You can pass the window dimensions to setup the projection.
    public TextRenderer(int windowWidth, int windowHeight) {
        setupOrthographicProjection(windowWidth, windowHeight);
    }

    void setupOrthographicProjection(int width, int height) {
        // Define the orthographic projection boundaries based on window size
        float left = 0.0f;
        float right = (float) width;
        float bottom = (float) height; // Set bottom to window height
        float top = 0.0f;              // Set top to 0

        // Create the orthographic projection matrix with flipped Y-axis
        orthoProjection = Matrix4.ortho2D(left, right, bottom, top);

        // Allocate the FloatBuffer
        orthoBuffer = BufferUtils.createFloatBuffer(16);

        // Populate the buffer with the matrix data
        orthoProjection.get(orthoBuffer);
    }

    public void createTextShaders(String vertexShaderPath, String fragmentShaderPath) {
        String vertexCode = loadFileAsString(vertexShaderPath);
        String fragmentCode = loadFileAsString(fragmentShaderPath);

        int vertexShader = compileShader(vertexCode, GL_VERTEX_SHADER);
        int fragmentShader = compileShader(fragmentCode, GL_FRAGMENT_SHADER);

        textProgramID = glCreateProgram();
        glAttachShader(textProgramID, vertexShader);
        glAttachShader(textProgramID, fragmentShader);
        glLinkProgram(textProgramID);

        int success = glGetProgrami(textProgramID, GL_LINK_STATUS);
        if (success == GL_FALSE) {
            String infoLog = glGetProgramInfoLog(textProgramID);
            throw new RuntimeException("Failed to link text shader program:\n" + infoLog);
        }

        glDetachShader(textProgramID, vertexShader);
        glDetachShader(textProgramID, fragmentShader);
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
    }

    public void initFontQuad() {
        // Quad vertices: positions (x,y) and texture coordinates (s,t)
        float[] vertices = {
                10.0f,  10.0f,  0.0f, 0.0f,   // Bottom-left
                266.0f, 10.0f,  1.0f, 0.0f,   // Bottom-right
                266.0f, 266.0f, 1.0f, 1.0f,   // Top-right
                10.0f,  266.0f, 0.0f, 1.0f    // Top-left
        };

        textVaoID = glGenVertexArrays();
        textVboID = glGenBuffers();
        glBindVertexArray(textVaoID);

        glBindBuffer(GL_ARRAY_BUFFER, textVboID);
        glBufferData(GL_ARRAY_BUFFER, vertices, GL_STATIC_DRAW);

        // Position attribute (location 0): two floats, stride of 4 floats, offset 0
        glVertexAttribPointer(0, 2, GL_FLOAT, false, 4 * Float.BYTES, 0);
        glEnableVertexAttribArray(0);
        // Texture coordinate attribute (location 1): two floats, stride of 4 floats, offset 2 floats
        glVertexAttribPointer(1, 2, GL_FLOAT, false, 4 * Float.BYTES, 2 * Float.BYTES);
        glEnableVertexAttribArray(1);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }

    /**
     * Generates a font texture from the provided text using AWT.
     */
    public void setUpFonts(String text) {
        Font font = new Font("Times New Roman", Font.BOLD, 24);
        BufferedImage fontImage = new BufferedImage(256, 256, BufferedImage.TYPE_INT_ARGB);
        Graphics2D graphics = fontImage.createGraphics();
        graphics.setFont(font);
        graphics.drawString(text, 10, 50);
        graphics.dispose();

        int[] pixels = fontImage.getRGB(0, 0, fontImage.getWidth(), fontImage.getHeight(), null, 0, fontImage.getWidth());
        ByteBuffer buffer = BufferUtils.createByteBuffer(fontImage.getWidth() * fontImage.getHeight() * 4);

        for (int y = 0; y < fontImage.getHeight(); y++) {
            for (int x = 0; x < fontImage.getWidth(); x++) {
                int pixel = pixels[y * fontImage.getWidth() + x];
                buffer.put((byte) ((pixel >> 16) & 0xFF)); // Red
                buffer.put((byte) ((pixel >> 8) & 0xFF));  // Green
                buffer.put((byte) (pixel & 0xFF));         // Blue
                buffer.put((byte) ((pixel >> 24) & 0xFF));   // Alpha
            }
        }
        buffer.flip();

        fontTextureID = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, fontTextureID);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, fontImage.getWidth(), fontImage.getHeight(),
                0, GL_RGBA, GL_UNSIGNED_BYTE, buffer);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        glBindTexture(GL_TEXTURE_2D, 0);
    }

    /**
     * Renders the font quad using the text shader program.
     */
    public void renderFonts() {
        glUseProgram(textProgramID);

        // Update the orthographic projection uniform
        orthoProjection.get(orthoBuffer);
        int projectionLoc = glGetUniformLocation(textProgramID, "projection");
        glUniformMatrix4fv(projectionLoc, false, orthoBuffer);

        // Set text color (blue in this example)
        int textColorLoc = glGetUniformLocation(textProgramID, "textColor");
        glUniform3f(textColorLoc, 0.0f, 0.0f, 1.0f);

        // Bind font texture
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, fontTextureID);
        int samplerLoc = glGetUniformLocation(textProgramID, "textTexture");
        glUniform1i(samplerLoc, 0);

        // Draw the font quad
        glBindVertexArray(textVaoID);
        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
        glBindVertexArray(0);

        glBindTexture(GL_TEXTURE_2D, 0);
        glUseProgram(0);
    }

    public void cleanup() {
        glDeleteTextures(fontTextureID);
        glDeleteProgram(textProgramID);
        glDeleteVertexArrays(textVaoID);
        glDeleteBuffers(textVboID);
    }

    // --- Utility methods for shader loading/compilation ---

    private String loadFileAsString(String filepath) {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new FileReader(filepath))) {
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line).append("\n");
            }
        } catch (IOException e) {
            throw new RuntimeException("Failed to load shader file: " + filepath, e);
        }
        return sb.toString();
    }

    private int compileShader(String source, int type) {
        int shaderID = glCreateShader(type);
        glShaderSource(shaderID, source);
        glCompileShader(shaderID);

        int success = glGetShaderi(shaderID, GL_COMPILE_STATUS);
        if (success == GL_FALSE) {
            String infoLog = glGetShaderInfoLog(shaderID);
            throw new RuntimeException("Shader compilation failed:\n" + infoLog);
        }
        return shaderID;
    }
}
