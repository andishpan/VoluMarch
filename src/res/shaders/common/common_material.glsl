#ifndef COMMON_MATERIAL_GLSL
#define COMMON_MATERIAL_GLSL

#ifndef NUM_MATERIALS
#define NUM_MATERIALS 3
#endif


layout (std140) uniform MaterialBlock
{
    vec3 uAlbedo   [NUM_MATERIALS];
    vec3 uEmissive [NUM_MATERIALS];
    int  uFlags    [NUM_MATERIALS];
};


vec3  GetMaterialAlbedo  (int id) { return uAlbedo  [id]; }
vec3  GetMaterialEmissive(int id) { return uEmissive[id]; }
int   GetMaterialFlags   (int id) { return uFlags   [id]; }


vec3  ambientColor;

#endif
