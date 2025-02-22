

import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.opengl.GL15.GL_ARRAY_BUFFER;
import static org.lwjgl.opengl.GL15.GL_STATIC_DRAW;
import static org.lwjgl.opengl.GL15.glBindBuffer;
import static org.lwjgl.opengl.GL15.glBufferData;
import static org.lwjgl.opengl.GL15.glGenBuffers;
import static org.lwjgl.opengl.GL20.*;


import static org.lwjgl.opengl.GL30.glBindVertexArray;
import static org.lwjgl.opengl.GL30.glGenVertexArrays;


public class myObject {
    private float angle;
    private float[] vertices;
    private float[] colors;
    private float[] normals;
    private float[] uvCoordinates;
    private int vaoId;
    private int vboId;
    private int vboColors;
    private int vboNormals;
    private int vboUVs;
    private String textureName;
    private Texture texture;
    private int mipMap;
    private Matrix4 modelMatrix;
    private ShaderProgram shaderProgram;

    private Matrix4 parentMatrix;
    private Matrix4 projectionMatrix;

    private Matrix4 transformationMatrix;

    private Matrix4 viewMatrix;

    public myObject(float[] vertices, float[] colors, float[] normals , float[] uvCoordinates, String textureName, int mipMap, ShaderProgram shaderProgram) {
        this.vertices = vertices;
        this.colors = colors;
        this.normals = normals;
        this.uvCoordinates = uvCoordinates;
        this.mipMap = mipMap;
        this.textureName = textureName;

        this.shaderProgram = shaderProgram;

        loadTexture(this.textureName,this.mipMap);
        this.modelMatrix = new Matrix4();
        this.transformationMatrix = new Matrix4();
        initializeBuffers();
    }




    int getVaoId() {
        return this.vaoId;
    }


    private void initializeBuffers() {

        glUseProgram(shaderProgram.getId());

        // Koordinaten, VAO, VBO, ... hier anlegen und im Grafikspeicher ablegen

        this.vaoId = glGenVertexArrays();

        glBindVertexArray(this.vaoId);

        vboId = glGenBuffers();
        glBindBuffer(GL_ARRAY_BUFFER, vboId);
        glBufferData(GL_ARRAY_BUFFER, vertices, GL_STATIC_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, false, 0, 0);
        glEnableVertexAttribArray(0);

        vboColors = glGenBuffers();
        glBindBuffer(GL_ARRAY_BUFFER, vboColors);

        glBufferData(GL_ARRAY_BUFFER, colors, GL_STATIC_DRAW);
        glVertexAttribPointer(1,3, GL_FLOAT, false,0,0);
        glEnableVertexAttribArray(1);

        vboNormals = glGenBuffers();
        glBindBuffer(GL_ARRAY_BUFFER, vboNormals);

        glBufferData(GL_ARRAY_BUFFER, normals, GL_STATIC_DRAW);
        glVertexAttribPointer(2,3, GL_FLOAT, false,0,0);
        glEnableVertexAttribArray(2);

        vboUVs = glGenBuffers();
        glBindBuffer(GL_ARRAY_BUFFER, vboUVs);

        glBufferData(GL_ARRAY_BUFFER, uvCoordinates, GL_STATIC_DRAW);
        glVertexAttribPointer(3,2, GL_FLOAT, false,0,0);
        glEnableVertexAttribArray(3);


        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);

        projectionMatrix = new Matrix4(1f,100.0f);

        viewMatrix = new Matrix4().translate(0,0,-2);

        float scaleFactor = 0.5f;

        int uMatrixLocation = glGetUniformLocation(shaderProgram.getId(), "modelMatrix");
        int viewMatrixLocation = glGetUniformLocation(shaderProgram.getId(), "viewMatrix");
        int projectionMatrixLocation = glGetUniformLocation(shaderProgram.getId(), "projectionMatrix");

        modelMatrix.scale(scaleFactor, scaleFactor, scaleFactor);

        glUniformMatrix4fv(uMatrixLocation, false, modelMatrix.getValuesAsArray());
        glUniformMatrix4fv(viewMatrixLocation, false, viewMatrix.getValuesAsArray());


        glUniformMatrix4fv(projectionMatrixLocation, false, projectionMatrix.getValuesAsArray());


        glEnable(GL_DEPTH_TEST); // z-Buffer aktivieren
        //glEnable(GL_CULL_FACE); // backface culling aktivieren

    }

    public void translate(float x, float y, float z) {
        modelMatrix.translate(x, y, z);
    }

    public Matrix4 getModelMatrix() {
        return modelMatrix;
    }
    public Matrix4 getProjectionMatrix() {
        return projectionMatrix;
    }
    public Matrix4 getTransformationMatrix() {
        return modelMatrix;
    }

    public void loadTexture(String file, int mipMap) {
        System.out.println("Loading texture: " + "" + file);
        Texture texture = new Texture(file, mipMap);
        this.texture = texture;
    }

    public Texture getTexture() {
        return texture;
    }


    public void update(Matrix4 parentMatrix, Vector3f localOffset, float rotationSpeed,float scalingFactor) {


        glUseProgram(shaderProgram.getId());

        angle += rotationSpeed;

        this.parentMatrix = parentMatrix;

        modelMatrix = new Matrix4(parentMatrix);

        modelMatrix.translate(localOffset.x, localOffset.y, localOffset.z);
        modelMatrix.rotateY(angle);
        modelMatrix.scale(scalingFactor, scalingFactor, scalingFactor);
        transformationMatrix = modelMatrix;


        int lightColorLoc = glGetUniformLocation(shaderProgram.getId(), "lightColor");
        glUniform3f(lightColorLoc, 1.0f, 1.0f, 1.0f);

        int transLoc = glGetUniformLocation(shaderProgram.getId(), "transformationMatrix");
        glUniformMatrix4fv(transLoc, false, transformationMatrix.getValuesAsArray());


        glUseProgram(0);


    }

}
