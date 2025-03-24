import static org.lwjgl.glfw.GLFW.*;

public class InputHandler {
    private long window;
    private float mouseX, mouseY;
    private boolean mouseDown;

    public InputHandler(long window) {
        this.window = window;
        setupCallbacks();
    }

    private void setupCallbacks() {
        glfwSetCursorPosCallback(window, (win, xpos, ypos) -> {
            mouseX = (float) xpos;
            mouseY = (float) ypos;
        });

        glfwSetMouseButtonCallback(window, (win, button, action, mods) -> {
            if (button == GLFW_MOUSE_BUTTON_LEFT) {
                mouseDown = (action == GLFW_PRESS);
            }
        });
    }

    public float getMouseX() {
        return mouseX;
    }

    public float getMouseY() {
        return mouseY;
    }

    public boolean isMouseDown() {
        return mouseDown;
    }

    public boolean isKeyPressed(int key) {
        return glfwGetKey(window, key) == GLFW_PRESS;
    }
}
