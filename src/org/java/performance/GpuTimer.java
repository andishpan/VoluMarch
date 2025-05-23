package org.java.performance;

import static org.lwjgl.opengl.GL15.*;
import static org.lwjgl.opengl.GL33.*;

public class GpuTimer {
    private static final int N = 3;
    private final int[] q = new int[N];
    private int cur = 0;

    public GpuTimer() {
        for (int i = 0; i < N; ++i) q[i] = glGenQueries();
    }

    public void nextFrame() {
        cur = (cur + 1) % N;
    }

    public void begin() {
        glBeginQuery(GL_TIME_ELAPSED, q[cur]);
    }

    public void end() {
        glEndQuery(GL_TIME_ELAPSED);
    }

    public Double poll() {
        int idx = (cur + N - 1) % N;
        if (glGetQueryObjecti(q[idx], GL_QUERY_RESULT_AVAILABLE) == GL_FALSE) return null;
        long ns = glGetQueryObjectui64(q[idx], GL_QUERY_RESULT);
        return ns / 1_000_000.0;
    }

    public void delete() {
        for (int id : q) glDeleteQueries(id);
    }
}
