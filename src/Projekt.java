

import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL20.*;


import static org.lwjgl.opengl.GL30.glBindVertexArray;
import static org.lwjgl.opengl.GL30.glGenVertexArrays;

public class Projekt extends AbstractOpenGLBase {
    private ShaderProgram gouraudShader;
    private ShaderProgram phongShader;

    private myObject pyramid1;
    private myObject cube;

    private float[] vertices;
    private float[] verticesCube;
    private float[] uvCoordinatesCube;
    private float[] colors;
    private float[] colorsCube;
    private float[] normals;
    private float[] normalsCube;
    private float[] uvCoordinatesPyramid;

    public static void main(String[] args) {
        new Projekt().start("CG Projekt", 700, 700);
    }

    @Override
    protected void init() {
        gouraudShader = new ShaderProgram("gouraud");
        phongShader = new ShaderProgram("phong");
        glUseProgram(phongShader.getId());

        // Koordinaten, VAO, VBO, ... hier anlegen und im Grafikspeicher ablegen

        vertices = new float[]{

                0.0f, 1.0f, 0.0f,
                -1.0f, -1.0f, 1.0f,
                1.0f, -1.0f, 1.0f,

                0.0f, 1.0f, 0.0f,
                -1.0f, -1.0f, 1.0f,
                0.0f, -1.0f, -1.0f,

                0.0f, 1.0f, 0.0f,
                0.0f, -1.0f, -1.0f,
                1.0f, -1.0f, 1.0f,

                -1.0f, -1.0f, 1.0f,
                0.0f, -1.0f, -1.0f,
                1.0f, -1.0f, 1.0f

        };

        colors = new float[]{

                0.0f, 0.0f, 1.0f ,
                0.0f, 0.0f, 1.0f ,
                0.0f, 0.0f, 1.0f ,

                0.0f, 0.0f, 1.0f,
                0.0f, 0.0f, 1.0f ,
                0.0f, 0.0f, 1.0f ,

                0.0f, 0.0f, 1.0f ,
                0.0f, 0.0f, 1.0f ,
                0.0f, 0.0f, 1.0f ,

                0.0f, 0.0f, 1.0f ,
                0.0f, 0.0f, 1.0f ,
                0.0f, 0.0f, 1.0f
        };

        normals = new float[] {

                0.0f,1.0f,1.0f,
                0.0f,1.0f,1.0f,
                0.0f,1.0f,1.0f,

                1.0f,-1.0f,1.0f,
                1.0f,-1.0f,1.0f,
                1.0f,-1.0f,1.0f,

                -1.0f,-1.0f,1.0f,
                -1.0f,-1.0f,1.0f,
                -1.0f,-1.0f,1.0f,

                0.0f, -1.0f, 0.0f,
                0.0f, -1.0f, 0.0f,
                0.0f, -1.0f, 0.0f


        };

        uvCoordinatesPyramid = new float[] {

                0.5f,1.0f,

                0.0f,0.0f,
                1.0f,0.0f,

                0.5f,1.0f,
                0.0f,0.0f,
                0.0f,1.0f,

                0.5f,1.0f,
                0.0f,1.0f,
                1.0f,0.0f,

                0.5f,1.0f,
                1.0f,0.0f,
                1.0f,1.0f
        };


        verticesCube = new float[] {
                // front
                -1.0f, -1.0f,  1.0f,
                1.0f, -1.0f,  1.0f,
                1.0f,  1.0f,  1.0f,

                -1.0f, -1.0f,  1.0f,
                1.0f,  1.0f,  1.0f,
                -1.0f,  1.0f,  1.0f,

                // right
                1.0f, -1.0f,  1.0f,
                1.0f, -1.0f, -1.0f,
                1.0f,  1.0f, -1.0f,

                1.0f, -1.0f,  1.0f,
                1.0f,  1.0f, -1.0f,
                1.0f,  1.0f,  1.0f,

                // back
                1.0f, -1.0f, -1.0f,
                -1.0f, -1.0f, -1.0f,
                -1.0f,  1.0f, -1.0f,

                1.0f, -1.0f, -1.0f,
                -1.0f,  1.0f, -1.0f,
                1.0f,  1.0f, -1.0f,

                // left
                -1.0f, -1.0f, -1.0f,
                -1.0f, -1.0f,  1.0f,
                -1.0f,  1.0f,  1.0f,

                -1.0f, -1.0f, -1.0f,
                -1.0f,  1.0f,  1.0f,
                -1.0f,  1.0f, -1.0f,

                // top
                -1.0f,  1.0f,  1.0f,
                1.0f,  1.0f,  1.0f,
                1.0f,  1.0f, -1.0f,

                -1.0f,  1.0f,  1.0f,
                1.0f,  1.0f, -1.0f,
                -1.0f,  1.0f, -1.0f,

                // bottom
                -1.0f, -1.0f, -1.0f,
                1.0f, -1.0f, -1.0f,
                1.0f, -1.0f,  1.0f,

                -1.0f, -1.0f, -1.0f,
                1.0f, -1.0f,  1.0f,
                -1.0f, -1.0f,  1.0f


        };

        colorsCube = new float[] {
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,

                1.0f, 0.0f, 1.0f,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,

                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,

                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f,

                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f,

                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f,

                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f,

                1.0f, 0.0f, 1.0f,
                1.0f, 0.0f, 1.0f,
                1.0f, 0.0f, 1.0f,

                1.0f, 0.0f, 1.0f,
                1.0f, 0.0f, 1.0f,
                1.0f, 0.0f, 1.0f,


                1.0f, 0.0f, 1.0f,
                1.0f, 0.0f, 1.0f,
                1.0f, 0.0f, 1.0f,


                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f,

                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f ,
                1.0f, 0.0f, 1.0f
        };


        normalsCube = new float[] {
                //front
                0.0f, 0.0f, 1.0f,
                0.0f, 0.0f, 1.0f,
                0.0f, 0.0f, 1.0f,

                0.0f, 0.0f, 1.0f,
                0.0f, 0.0f, 1.0f,
                0.0f, 0.0f, 1.0f,

                //right
                1.0f, 0.0f, 0.0f,
                1.0f, 0.0f, 0.0f,
                1.0f, 0.0f, 0.0f,

                1.0f, 0.0f, 0.0f,
                1.0f, 0.0f, 0.0f,
                1.0f, 0.0f, 0.0f,

                //back
                0.0f, 0.0f, -1.0f,
                0.0f, 0.0f, -1.0f,
                0.0f, 0.0f, -1.0f,

                0.0f, 0.0f, -1.0f,
                0.0f, 0.0f, -1.0f,
                0.0f, 0.0f, -1.0f,

                //left
                -1.0f, 0.0f, 0.0f,
                -1.0f, 0.0f, 0.0f,
                -1.0f, 0.0f, 0.0f,

                -1.0f, 0.0f, 0.0f,
                -1.0f, 0.0f, 0.0f,
                -1.0f, 0.0f, 0.0f,

                //top
                0.0f, 1.0f, 0.0f,
                0.0f, 1.0f, 0.0f,
                0.0f, 1.0f, 0.0f,

                0.0f, 1.0f, 0.0f,
                0.0f, 1.0f, 0.0f,
                0.0f, 1.0f, 0.0f,

                //bottom
                0.0f, -1.0f, 0,0f,
                0.0f, -1.0f, 0.0f,
                0.0f, -1.0f, 0.0f,

                0.0f, -1.0f, 0.0f,
                0.0f, -1.0f, 0.0f,
                0.0f, -1.0f, 0.0f,


        };


        uvCoordinatesCube = new float[] {
                // front
                0.0f, 0.0f,
                1.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 1.0f,

                // right
                0.0f, 0.0f,
                1.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 1.0f,

                // back
                0.0f, 0.0f,
                1.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 1.0f,

                // left
                0.0f, 0.0f,
                1.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 1.0f,

                // top
                0.0f, 0.0f,
                1.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 1.0f,

                // bottom
                0.0f, 0.0f,
                1.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 0.0f,
                1.0f, 1.0f,
                0.0f, 1.0f
        };

        cube = new myObject( verticesCube, colorsCube,normalsCube,uvCoordinatesCube,"blue.png",9,gouraudShader);

        cube.getTexture().setNearestNeighborFiltering();

        pyramid1 = new myObject( vertices,colors,normals, uvCoordinatesPyramid,"swirl.png",12,phongShader);

    }


    @Override
    public void update() {

        float pyramidScale = 0.5f;
        float cubeScale = 0.4f;

        pyramid1.update(new Matrix4(), new Vector3f(0.0f, 0.0f, 0.0f), 0.02f, pyramidScale);

        cube.update(pyramid1.getModelMatrix(), new Vector3f(2.0f, 0.0f, 0.0f), 0.02f, cubeScale);

    }


    @Override
    protected void render() {

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);


        renderObject(phongShader,pyramid1,vertices.length,pyramid1.getVaoId());
        renderObject(gouraudShader, cube,verticesCube.length, cube.getVaoId());

    }

    public void renderObject(ShaderProgram shaderProgram, myObject object, int verticesCount, int vao){

        glUseProgram(shaderProgram.getId());
        glBindVertexArray(vao);
        glBindTexture(GL_TEXTURE_2D, object.getTexture().getId());


        glDrawArrays(GL_TRIANGLES, 0, verticesCount);
        glBindVertexArray(0);
        glUseProgram(0);
    }


}
