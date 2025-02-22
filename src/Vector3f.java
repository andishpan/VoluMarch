public class Vector3f {
    public float x, y, z;

    public Vector3f(float x, float y, float z) {
        this.x = x;
        this.y = y;
        this.z = z;
    }


    public Vector3f abs() {
        return new Vector3f(Math.abs(this.x), Math.abs(this.y), Math.abs(this.z));
    }

    public Vector3f(Vector3f start) {
        this.x = start.x;
        this.y = start.y;
        this.z = start.z;
    }


    public float get(int index) {
        switch (index) {
            case 0:
                return x;
            case 1:
                return y;
            case 2:
                return z;
            default:
                throw new IllegalArgumentException("Index must be 0, 1, or 2");
        }
    }

    public void set(int index, float value) {
        switch (index) {
            case 0:
                x = value;
                break;
            case 1:
                y = value;
                break;
            case 2:
                z = value;
                break;
            default:
                throw new IllegalArgumentException("Index must be 0, 1, or 2");
        }
    }


    public void set(Vector3f other) {
        this.x = other.x;
        this.y = other.y;
        this.z = other.z;
    }


    public static Vector3f intToVector3f(int color) {
        float r = ((color >> 16) & 0xFF) / 255.0f;
        float g = ((color >> 8) & 0xFF) / 255.0f;
        float b = (color & 0xFF) / 255.0f;
        return new Vector3f(r, g, b);
    }


    public Vector3f copy() {
        return new Vector3f(this.x, this.y, this.z);
    }

    public static int vector3fToInt(Vector3f color) {
        int r = Math.min(255, (int) (color.x * 255));
        int g = Math.min(255, (int) (color.y * 255));
        int b = Math.min(255, (int) (color.z * 255));
        return (r << 16) | (g << 8) | b;
    }

    public static Vector3f lerp(Vector3f start, Vector3f end, float t) {
        return new Vector3f(
                start.x + (end.x - start.x) * t,
                start.y + (end.y - start.y) * t,
                start.z + (end.z - start.z) * t
        );
    }


    @Override
    public Vector3f clone() {
        return new Vector3f(this.x, this.y, this.z);
    }
    public Vector3f divide(Vector3f v) {
        return new Vector3f(this.x / v.x, this.y / v.y, this.z / v.z);
    }

    public Vector3f add(Vector3f other) {
        return new Vector3f(this.x + other.x, this.y + other.y, this.z + other.z);
    }

    public Vector3f subtract(Vector3f other) {
        return new Vector3f(this.x - other.x, this.y - other.y, this.z - other.z);
    }

    public Vector3f scale(float scalar) {
        return new Vector3f(this.x * scalar, this.y * scalar, this.z * scalar);
    }

    public Vector3f multiply(Vector3f other) {
        return new Vector3f(this.x * other.x, this.y * other.y, this.z * other.z);
    }

    public Vector3f negate() {
        return new Vector3f(-this.x, -this.y, -this.z);
    }

    public Vector3f reflect(Vector3f normal) {
        return this.subtract(normal.scale(2 * this.dot(normal))).normalize();
    }


    public Vector3f multiply(float scalar) {
        return new Vector3f(this.x * scalar, this.y * scalar, this.z * scalar);
    }

    public float dot(Vector3f other) {
        return this.x * other.x + this.y * other.y + this.z * other.z;
    }

    public Vector3f cross(Vector3f other) {
        return new Vector3f(
                this.y * other.z - this.z * other.y,
                this.z * other.x - this.x * other.z,
                this.x * other.y - this.y * other.x
        );
    }

    public Vector3f normalize() {
        float length = (float) Math.sqrt(x * x + y * y + z * z);
        if (length != 0) {
            return new Vector3f(this.x / length, this.y / length, this.z / length);
        }
        return new Vector3f(0, 0, 0);
    }

    public float length() {
        return (float) Math.sqrt(x * x + y * y + z * z);
    }

    public float lengthSquared() {
        return x * x + y * y + z * z;
    }

    @Override
    public String toString() {
        return "Vector3f{" +
                "x=" + x +
                ", y=" + y +
                ", z=" + z +
                '}';
    }
}
