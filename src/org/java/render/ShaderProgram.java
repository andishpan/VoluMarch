package org.java.render;

import org.lwjgl.BufferUtils;
import org.lwjgl.stb.STBImage;

import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.opengl.GL32.*;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.IntBuffer;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.ConcurrentHashMap;

//Base for this class from Computer graphics course Project at HTW Berlin by Prof. Dr. Tobias Lenz
public class ShaderProgram {

    private final List<Integer> shaderIds = new ArrayList<>();
    private final ConcurrentMap<String, Integer> locCache = new ConcurrentHashMap<>();
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

    public ShaderProgram(String vertexPath, String... fragmentPaths) {
        id = glCreateProgram();
        if (id == 0) throw new IllegalStateException("glCreateProgram failed");

        compileAndAttach(vertexPath, GL_VERTEX_SHADER);

        StringBuilder combinedFragment = new StringBuilder();
        for (String path : fragmentPaths) {
            String fragmentSource = loadResource("/res/shaders/" + path);
            combinedFragment.append(fragmentSource).append("\n");
        }

        String fullFragment = preprocess(combinedFragment.toString());

        compileAndAttach("combined_fragment", GL_FRAGMENT_SHADER, fullFragment);

        glLinkProgram(id);
        if (glGetProgrami(id, GL_LINK_STATUS) == GL_FALSE) {
            throw new RuntimeException("Program link failed:\n"
                    + glGetProgramInfoLog(id));
        }
        for (int sid : shaderIds) {
            glDetachShader(id, sid);
            glDeleteShader(sid);
        }
        shaderIds.clear();

    }

    public ShaderProgram(String vertexShaderSource, String fragmentResourceName) {
        id = glCreateProgram();

        compileAndAttach("'vertex shader'", GL_VERTEX_SHADER, vertexShaderSource);
        loadSourceAndCompileAndAttach(fragmentResourceName, GL_FRAGMENT_SHADER);
        glLinkProgram(id);
        if (glGetProgrami(id, GL_LINK_STATUS) == GL_FALSE) {
            throw new RuntimeException(glGetProgramInfoLog(id, glGetProgrami(id, GL_INFO_LOG_LENGTH)));
        }
    }

    private static String loadResource(String path) {
        InputStream in = ShaderProgram.class.getResourceAsStream(path);
        if (in == null) throw new RuntimeException("Shader file not found: " + path);
        try (Scanner s = new Scanner(in, StandardCharsets.UTF_8)) {
            return s.useDelimiter("\\A").next();
        }
    }

    private static String preprocess(String src) {
        StringBuilder out = new StringBuilder();
        Scanner sc = new Scanner(src);
        while (sc.hasNextLine()) {
            String line = sc.nextLine();
            if (line.trim().startsWith("#include")) {
                String inc = line.split("\"")[1];
                out.append(preprocess(loadResource("/res/shaders/" + inc)));
            } else {
                out.append(line).append('\n');
            }
        }
        return out.toString();
    }

    int loc(String name) {
        return locCache.computeIfAbsent(name,
                n -> glGetUniformLocation(id, n));
    }

    public void setUniform1f(String name, float v) {
        glUniform1f(loc(name), v);
    }

    public void setUniform3f(String name, float x, float y, float z) {
        glUniform3f(loc(name), x, y, z);
    }

    public void setUniform1i(String name, int v) {
        glUniform1i(loc(name), v);
    }

    public void setUniformMatrix4fv(String name, float[] m) {
        glUniformMatrix4fv(loc(name), false, m);
    }

    public void setUniform(String name, boolean value) {
        int location = glGetUniformLocation(id, name);
        glUniform1i(location, value ? 1 : 0);
    }

    private void compileAndAttach(String fileName, int type) {
        int sid = glCreateShader(type);
        if (sid == 0) throw new IllegalStateException("glCreateShader failed");

        String source = loadResource("/res/shaders/" + fileName);
        glShaderSource(sid, preprocess(source));
        glCompileShader(sid);

        if (glGetShaderi(sid, GL_COMPILE_STATUS) == GL_FALSE) {
            String what = (type == GL_VERTEX_SHADER ? "VERTEX" : "FRAGMENT");
            throw new RuntimeException(what + " shader '" + fileName +
                    "' failed to compile:\n" + glGetShaderInfoLog(sid));
        }

        glAttachShader(id, sid);
        shaderIds.add(sid);
    }

    public int getId() {
        return id;
    }

    private InputStream getInputStreamFromResourceName(String resourceName) {
        return getClass().getResourceAsStream("/res/shaders/" + resourceName);
    }

    private void loadSourceAndCompileAndAttach(String resourceName, int type) {
        InputStream in = getInputStreamFromResourceName(resourceName);
        if (in == null) {
            if (type != GL_GEOMETRY_SHADER) {
                throw new RuntimeException("Shader source file " + resourceName + " not found!");
            }
            return;
        }
        String source;
        try (Scanner s = new Scanner(in, StandardCharsets.UTF_8)) {
            source = s.useDelimiter("\\A").next();
        }
        compileAndAttach(resourceName, type, source);
    }

    private void compileAndAttach(String resourceName, int type, String source) {
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

    private String preprocessShader(String source) {
        return preprocessShaderRecursive(source, new HashSet<>());
    }

    private String preprocessShaderRecursive(String source, Set<String> includedFiles) {
        StringBuilder processed = new StringBuilder();
        Scanner scanner = new Scanner(source);

        while (scanner.hasNextLine()) {
            String line = scanner.nextLine();

            if (line.trim().startsWith("#include")) {
                String includePath = line.split("\"")[1];
                if (includedFiles.contains(includePath)) continue;

                includedFiles.add(includePath);

                InputStream in = getInputStreamFromResourceName(includePath);
                if (in == null) {
                    throw new RuntimeException("Failed to find include: " + includePath);
                }

                String includeContent = new Scanner(in).useDelimiter("\\A").next();
                processed.append(preprocessShaderRecursive(includeContent, includedFiles)).append("\n");
            } else {
                processed.append(line).append("\n");
            }
        }

        return processed.toString();
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

    public int loadCubemap(String dir) {
        String[] faces = {
                "px.png",  // +X right
                "nx.png",  // –X left
                "py.png",  // +Y top
                "ny.png",  // –Y bottom
                "pz.png",  // +Z back
                "nz.png"   // –Z front
        };

        int id = glGenTextures();
        glBindTexture(GL_TEXTURE_CUBE_MAP, id);
        for (int i = 0; i < 6; i++) {
            IntBuffer w = BufferUtils.createIntBuffer(1),
                    h = BufferUtils.createIntBuffer(1),
                    comp = BufferUtils.createIntBuffer(1);
            ByteBuffer data = STBImage.stbi_load(dir + "/" + faces[i], w, h, comp, 3);
            if (data == null)
                throw new RuntimeException("Could not load sky face: " + faces[i]);
            glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i,
                    0, GL_RGB, w.get(0), h.get(0),
                    0, GL_RGB, GL_UNSIGNED_BYTE, data);
            STBImage.stbi_image_free(data);
        }
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S,   GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T,   GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R,   GL_CLAMP_TO_EDGE);
        return id;
    }

    public void cleanup() {
        glDeleteProgram(id);
    }
}
