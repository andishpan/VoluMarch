package org.java.utility;

import org.lwjgl.opengl.GL;

import static org.lwjgl.opengl.GL11.*;
import static org.java.performance.GLExtra.*;

public final class GpuMemoryInfo {

    public static String query() {
        if (GL.getCapabilities().GL_NVX_gpu_memory_info) {
            int totalKB = glGetInteger(GL_GPU_MEMORY_INFO_TOTAL_AVAILABLE_MEMORY_NV);
            int availKB = glGetInteger(GL_GPU_MEMORY_INFO_CURRENT_AVAILABLE_VIDMEM_NV);
            return String.format("VRAM total %d MB, free %d MB, used %d MB",
                    totalKB / 1024, availKB / 1024, (totalKB - availKB) / 1024);
        }
        if (GL.getCapabilities().GL_ATI_meminfo) {
            int freeTexKB = glGetInteger(GL_TEXTURE_FREE_MEMORY_ATI);
            return String.format("VRAM free (ATI) %d MB (textures pool)", freeTexKB / 1024);
        }
        return "VRAM query not supported (no NVX_gpu_memory_info / ATI_meminfo)";
    }
}
