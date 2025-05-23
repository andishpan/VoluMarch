package org.java.render;

import static org.lwjgl.glfw.Callbacks.*;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.system.MemoryUtil.*;

import org.lwjgl.Version;
import org.lwjgl.glfw.GLFWErrorCallback;
import org.lwjgl.glfw.GLFWVidMode;
import org.lwjgl.opengl.GL;

public abstract class AbstractOpenGLBase {
    static {
        System.setProperty("java.awt.headless", "true");
    }

    protected abstract void init();

    protected abstract void update();

    protected abstract void render();

    public void start(String title, int width, int height) {
        System.out.println("LWJGL " + Version.getVersion());

        long window = openWindow(title, width, height);
        GL.createCapabilities(); 
        System.out.println("OpenGL " + glGetString(GL_VERSION));

        init(); 

        while (!glfwWindowShouldClose(window)) {
            update(); 
            render(); 

            glfwSwapBuffers(window); 

            glfwPollEvents(); 
        }

        glfwFreeCallbacks(window);
        glfwDestroyWindow(window);
        glfwTerminate();
        glfwSetErrorCallback(null).free();
    }

    private long openWindow(String title, int width, int height) {
        GLFWErrorCallback.createPrint(System.err).set(); 
        if (!glfwInit())
            throw new IllegalStateException("Unable to initialize GLFW");

        glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE); 
        glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE); 

        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3); 
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
        glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);

        long window = glfwCreateWindow(width, height, title, NULL, NULL);
        if (window == NULL)
            throw new RuntimeException("Failed to create the GLFW window");

        GLFWVidMode vidmode = glfwGetVideoMode(glfwGetPrimaryMonitor()); 
        glfwSetWindowPos(window, (vidmode.width() - width) / 2, (vidmode.height() - height) / 2); 

        glfwMakeContextCurrent(window);

        glfwSwapInterval(1); 

        glfwShowWindow(window);
        return window;
    }
}
