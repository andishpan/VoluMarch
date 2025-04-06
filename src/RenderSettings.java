

public class RenderSettings {

    //camera
    public Vector3f cameraPos = new Vector3f(0.0f, 50.0f, 20.0f);
    public Vector3f cameraLookAt   = new Vector3f(0.0f, -0.5f, -1.0f);
    public Vector3f cameraUp       = new Vector3f(0.0f, 1.0f, 0.0f);

    //cloud
    public float[] sunDirection = { -0.8f, 0.2f, -1.0f };
    public float   sunIntensity = 1.2f;
    public float   volumetricAbsorption = 0.1f;

    // noise
    public float noiseScale = 10.0f;
    public float noiseHeight = 16.0f;
    public int currentNoise = 0;


    // shape
    public int currentShape = 0;
    public int previousShape = 0;
    public float shapeTransition = 1.0f;
    public final float transitionSpeed = 1.5f;

    // methods
    public int currentMethod = 0;

    // steps
    public int maxSteps = 44;
    public int maxVolumeSteps = 44;
    public int maxShadowMarchSteps = 12;
    public int maxLightMarchSteps = 20;

}
