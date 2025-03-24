import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL32.*;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.util.Scanner;

public class ShaderProgram {
    private int id;


    public ShaderProgram(String resourceNameWithoutExtension) {
        id = glCreateProgram();
        loadSourceAndCompileAndAttach(resourceNameWithoutExtension + "_v.glsl", GL_VERTEX_SHADER);
        loadSourceAndCompileAndAttach(resourceNameWithoutExtension + "_f.glsl", GL_FRAGMENT_SHADER);

        glLinkProgram(id);
        if (glGetProgrami(id, GL_LINK_STATUS) == GL_FALSE) {
            throw new RuntimeException(glGetProgramInfoLog(id, glGetProgrami(id, GL_INFO_LOG_LENGTH)));
        }
    }


    public ShaderProgram(String vertexShaderSource, String fragmentResourceName) { // for assignment 1
        id = glCreateProgram();

        compileAndAttach("'vertex shader'", GL_VERTEX_SHADER, vertexShaderSource);
        loadSourceAndCompileAndAttach(fragmentResourceName, GL_FRAGMENT_SHADER);
        glLinkProgram(id);
        if (glGetProgrami(id, GL_LINK_STATUS) == GL_FALSE) {
            throw new RuntimeException(glGetProgramInfoLog(id, glGetProgrami(id, GL_INFO_LOG_LENGTH)));
        }
    }

    public int getId() {
        return id;
    }

    private InputStream getInputStreamFromResourceName(String resourceName) {
        return getClass().getResourceAsStream("/res/shaders/" + resourceName);
    }

    private void loadSourceAndCompileAndAttach(String resourceName, int type) {
        InputStream inputStreamFromResourceName = getInputStreamFromResourceName(resourceName);
        if (inputStreamFromResourceName == null) {
            if (type != GL_GEOMETRY_SHADER) {
                throw new RuntimeException("Shader source file " + resourceName + " not found!");
            }
            return;
        }
        String source;
        try (Scanner in = new Scanner(inputStreamFromResourceName)) {
            source = in.useDelimiter("\\A").next();
        }
        compileAndAttach(resourceName, type, source);
    }

    /**
     * If the provided source does not contain a newline, assume it’s only a shader name.
     * In that case, load the actual source from the resource folder.
     */
    private void compileAndAttach(String resourceName, int type, String source) {
        // Check: if source contains no newline, assume it’s just a file name.
        if (!source.contains("\n")) {
            InputStream in = getInputStreamFromResourceName(source);
            if (in == null) {
                throw new RuntimeException("Shader file " + source + " not found!");
            }
            try (Scanner scanner = new Scanner(in)) {
                source = scanner.useDelimiter("\\A").next();
            }
        }
        int shaderId = glCreateShader(type);
        glShaderSource(shaderId, source);
        glCompileShader(shaderId);

        String compileLog = glGetShaderInfoLog(shaderId, glGetShaderi(shaderId, GL_INFO_LOG_LENGTH));
        if (glGetShaderi(shaderId, GL_COMPILE_STATUS) == GL_FALSE) {
            throw new RuntimeException("Shader " + resourceName + " not compiled: " + compileLog);
        }
        if (!compileLog.isEmpty()) {
            System.err.println(resourceName + ": " + compileLog);
        }

        glAttachShader(id, shaderId);
    }


    private int compileShader(String source, int type) {
        int shaderID = glCreateShader(type);
        glShaderSource(shaderID, source);
        glCompileShader(shaderID);

        if (glGetShaderi(shaderID, GL_COMPILE_STATUS) == GL_FALSE) {
            throw new RuntimeException("Shader compilation failed: " + glGetShaderInfoLog(shaderID));
        }
        return shaderID;
    }

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

    public void bind() {
        glUseProgram(id);
    }

    public void unbind() {
        glUseProgram(0);
    }

    public int getID() {
        return id;
    }


    public void setUniform(String name, int value) {
        int location = glGetUniformLocation(id, name);
        glUniform1i(location, value);
    }

    public void setUniform(String name, float value) {
        int location = glGetUniformLocation(id, name);
        glUniform1f(location, value);
    }

    public void setUniform(String name, float x, float y, float z) {
        int location = glGetUniformLocation(id, name);
        glUniform3f(location, x, y, z);
    }

    public void setUniform(String name, float x, float y, float z, float w) {
        int location = glGetUniformLocation(id, name);
        glUniform4f(location, x, y, z, w);
    }

    public void setUniformMatrix4fv(String name, float[] matrix) {
        int location = glGetUniformLocation(id, name);
        glUniformMatrix4fv(location, false, matrix);
    }

    public void cleanup() {
        glDeleteProgram(id);
    }
}
