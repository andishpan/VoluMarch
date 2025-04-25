package performance;

import static org.lwjgl.opengl.GL15.*;
import static org.lwjgl.opengl.GL33.*;

public class GpuTimer {
    private final int queryID;

    public GpuTimer() {
        queryID = glGenQueries();
    }

    public void begin() {
        glBeginQuery(GL_TIME_ELAPSED, queryID);
    }

    public void end() {
        glEndQuery(GL_TIME_ELAPSED);
    }

    public long getElapsedTimeNs() {
        // This waits until the result is available (could block, optional improvement: polling)
        return glGetQueryObjectui64(queryID, GL_QUERY_RESULT);
    }

    public double getElapsedTimeMs() {
        return getElapsedTimeNs() / 1_000_000.0;
    }

    public void delete() {
        glDeleteQueries(queryID);
    }
}
