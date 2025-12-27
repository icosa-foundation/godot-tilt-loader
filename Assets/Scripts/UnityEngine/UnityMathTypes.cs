// Unity-to-Godot compatibility layer with proper wrapper structs
// These structs mimic Unity's API while using Godot types internally
using System;
using System.Runtime.CompilerServices;

namespace UnityEngine
{
    // Vector2 wrapper - matches Unity API with lowercase properties
    public struct Vector2 : IEquatable<Vector2>
    {
        private Godot.Vector2 _value;

        public float x { get => _value.X; set => _value.X = value; }
        public float y { get => _value.Y; set => _value.Y = value; }

        public Vector2(float x, float y)
        {
            _value = new Godot.Vector2(x, y);
        }

        // Unity static properties
        public static Vector2 zero => new Vector2(0, 0);
        public static Vector2 one => new Vector2(1, 1);
        public static Vector2 up => new Vector2(0, 1);
        public static Vector2 down => new Vector2(0, -1);
        public static Vector2 left => new Vector2(-1, 0);
        public static Vector2 right => new Vector2(1, 0);

        // Unity instance properties
        public float magnitude => _value.Length();
        public float sqrMagnitude => _value.LengthSquared();
        public Vector2 normalized => _value.Normalized();

        // Unity methods
        public void Set(float newX, float newY) { x = newX; y = newY; }
        public void Normalize() { _value = _value.Normalized(); }

        // Unity static methods
        public static float Dot(Vector2 lhs, Vector2 rhs) => lhs._value.Dot(rhs._value);
        public static float Distance(Vector2 a, Vector2 b) => a._value.DistanceTo(b._value);
        public static Vector2 Lerp(Vector2 a, Vector2 b, float t) => a._value.Lerp(b._value, t);
        public static Vector2 Scale(Vector2 a, Vector2 b) => new Vector2(a.x * b.x, a.y * b.y);

        // Operators
        public static Vector2 operator +(Vector2 a, Vector2 b) => a._value + b._value;
        public static Vector2 operator -(Vector2 a, Vector2 b) => a._value - b._value;
        public static Vector2 operator -(Vector2 a) => -a._value;
        public static Vector2 operator *(Vector2 a, float d) => a._value * d;
        public static Vector2 operator *(float d, Vector2 a) => a._value * d;
        public static Vector2 operator /(Vector2 a, float d) => a._value / d;
        public static bool operator ==(Vector2 a, Vector2 b) => a._value == b._value;
        public static bool operator !=(Vector2 a, Vector2 b) => a._value != b._value;

        // Conversions
        public static implicit operator Vector2(Godot.Vector2 v) => new Vector2 { _value = v };
        public static implicit operator Godot.Vector2(Vector2 v) => v._value;

        public override bool Equals(object obj) => obj is Vector2 v && _value == v._value;
        public bool Equals(Vector2 other) => _value == other._value;
        public override int GetHashCode() => _value.GetHashCode();
        public override string ToString() => $"({x}, {y})";
    }

    // Vector3 wrapper - matches Unity API with lowercase properties
    public struct Vector3 : IEquatable<Vector3>
    {
        private Godot.Vector3 _value;

        public float x { get => _value.X; set => _value.X = value; }
        public float y { get => _value.Y; set => _value.Y = value; }
        public float z { get => _value.Z; set => _value.Z = value; }

        public Vector3(float x, float y, float z)
        {
            _value = new Godot.Vector3(x, y, z);
        }

        public Vector3(float x, float y)
        {
            _value = new Godot.Vector3(x, y, 0);
        }

        // Indexer for Unity compatibility
        public float this[int index]
        {
            get => index switch { 0 => x, 1 => y, 2 => z, _ => throw new IndexOutOfRangeException() };
            set
            {
                switch (index)
                {
                    case 0: x = value; break;
                    case 1: y = value; break;
                    case 2: z = value; break;
                    default: throw new IndexOutOfRangeException();
                }
            }
        }

        // Unity static properties
        public static Vector3 zero => new Vector3(0, 0, 0);
        public static Vector3 one => new Vector3(1, 1, 1);
        public static Vector3 forward => new Vector3(0, 0, 1);
        public static Vector3 back => new Vector3(0, 0, -1);
        public static Vector3 up => new Vector3(0, 1, 0);
        public static Vector3 down => new Vector3(0, -1, 0);
        public static Vector3 left => new Vector3(-1, 0, 0);
        public static Vector3 right => new Vector3(1, 0, 0);

        // Unity instance properties
        public float magnitude => _value.Length();
        public float sqrMagnitude => _value.LengthSquared();
        public Vector3 normalized => _value.Normalized();

        // Unity methods
        public void Set(float newX, float newY, float newZ) { x = newX; y = newY; z = newZ; }
        public void Normalize() { _value = _value.Normalized(); }

        // Unity static methods
        public static float Dot(Vector3 lhs, Vector3 rhs) => lhs._value.Dot(rhs._value);
        public static Vector3 Cross(Vector3 lhs, Vector3 rhs) => lhs._value.Cross(rhs._value);
        public static float Distance(Vector3 a, Vector3 b) => a._value.DistanceTo(b._value);
        public static Vector3 Lerp(Vector3 a, Vector3 b, float t) => a._value.Lerp(b._value, t);
        public static Vector3 LerpUnclamped(Vector3 a, Vector3 b, float t) => new Vector3(
            a.x + (b.x - a.x) * t,
            a.y + (b.y - a.y) * t,
            a.z + (b.z - a.z) * t);
        public static Vector3 Scale(Vector3 a, Vector3 b) => new Vector3(a.x * b.x, a.y * b.y, a.z * b.z);
        public static Vector3 Project(Vector3 vector, Vector3 onNormal) => onNormal * (Dot(vector, onNormal) / Dot(onNormal, onNormal));
        public static Vector3 ProjectOnPlane(Vector3 vector, Vector3 planeNormal) => vector - Project(vector, planeNormal);
        public static float Angle(Vector3 from, Vector3 to) => from._value.AngleTo(to._value) * (180f / Mathf.PI);
        public static Vector3 Slerp(Vector3 a, Vector3 b, float t) => a._value.Slerp(b._value, t);
        public static Vector3 Min(Vector3 lhs, Vector3 rhs) => new Vector3(Mathf.Min(lhs.x, rhs.x), Mathf.Min(lhs.y, rhs.y), Mathf.Min(lhs.z, rhs.z));
        public static Vector3 Max(Vector3 lhs, Vector3 rhs) => new Vector3(Mathf.Max(lhs.x, rhs.x), Mathf.Max(lhs.y, rhs.y), Mathf.Max(lhs.z, rhs.z));

        // Operators
        public static Vector3 operator +(Vector3 a, Vector3 b) => a._value + b._value;
        public static Vector3 operator -(Vector3 a, Vector3 b) => a._value - b._value;
        public static Vector3 operator -(Vector3 a) => -a._value;
        public static Vector3 operator *(Vector3 a, float d) => a._value * d;
        public static Vector3 operator *(float d, Vector3 a) => a._value * d;
        public static Vector3 operator /(Vector3 a, float d) => a._value / d;
        public static bool operator ==(Vector3 a, Vector3 b) => a._value == b._value;
        public static bool operator !=(Vector3 a, Vector3 b) => a._value != b._value;

        // Conversions
        public static implicit operator Vector3(Godot.Vector3 v) => new Vector3 { _value = v };
        public static implicit operator Godot.Vector3(Vector3 v) => v._value;
        public static explicit operator Vector2(Vector3 v) => new Vector2(v.x, v.y);

        public override bool Equals(object obj) => obj is Vector3 v && _value == v._value;
        public bool Equals(Vector3 other) => _value == other._value;
        public override int GetHashCode() => _value.GetHashCode();
        public override string ToString() => $"({x}, {y}, {z})";
    }

    // Vector4 wrapper - matches Unity API with lowercase properties
    public struct Vector4 : IEquatable<Vector4>
    {
        private Godot.Vector4 _value;

        public float x { get => _value.X; set => _value.X = value; }
        public float y { get => _value.Y; set => _value.Y = value; }
        public float z { get => _value.Z; set => _value.Z = value; }
        public float w { get => _value.W; set => _value.W = value; }

        public Vector4(float x, float y, float z, float w)
        {
            _value = new Godot.Vector4(x, y, z, w);
        }

        public Vector4(float x, float y, float z)
        {
            _value = new Godot.Vector4(x, y, z, 0);
        }

        public Vector4(float x, float y)
        {
            _value = new Godot.Vector4(x, y, 0, 0);
        }

        // Unity static properties
        public static Vector4 zero => new Vector4(0, 0, 0, 0);
        public static Vector4 one => new Vector4(1, 1, 1, 1);

        // Unity instance properties
        public float magnitude => _value.Length();
        public float sqrMagnitude => _value.LengthSquared();
        public Vector4 normalized => _value.Normalized();

        // Unity methods
        public void Set(float newX, float newY, float newZ, float newW) { x = newX; y = newY; z = newZ; w = newW; }
        public void Normalize() { _value = _value.Normalized(); }

        // Unity static methods
        public static float Dot(Vector4 a, Vector4 b) => a._value.Dot(b._value);
        public static float Distance(Vector4 a, Vector4 b) => a._value.DistanceTo(b._value);
        public static Vector4 Lerp(Vector4 a, Vector4 b, float t) => a._value.Lerp(b._value, t);
        public static Vector4 Scale(Vector4 a, Vector4 b) => new Vector4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w);

        // Operators
        public static Vector4 operator +(Vector4 a, Vector4 b) => a._value + b._value;
        public static Vector4 operator -(Vector4 a, Vector4 b) => a._value - b._value;
        public static Vector4 operator -(Vector4 a) => -a._value;
        public static Vector4 operator *(Vector4 a, float d) => a._value * d;
        public static Vector4 operator *(float d, Vector4 a) => a._value * d;
        public static Vector4 operator /(Vector4 a, float d) => a._value / d;
        public static bool operator ==(Vector4 a, Vector4 b) => a._value == b._value;
        public static bool operator !=(Vector4 a, Vector4 b) => a._value != b._value;

        // Conversions
        public static implicit operator Vector4(Godot.Vector4 v) => new Vector4 { _value = v };
        public static implicit operator Godot.Vector4(Vector4 v) => v._value;

        // Conversion from Vector3
        public static implicit operator Vector4(Vector3 v) => new Vector4(v.x, v.y, v.z, 0);
        public static explicit operator Vector3(Vector4 v) => new Vector3(v.x, v.y, v.z);

        public override bool Equals(object obj) => obj is Vector4 v && _value == v._value;
        public bool Equals(Vector4 other) => _value == other._value;
        public override int GetHashCode() => _value.GetHashCode();
        public override string ToString() => $"({x}, {y}, {z}, {w})";
    }

    // Quaternion wrapper - matches Unity API with lowercase properties
    public struct Quaternion : IEquatable<Quaternion>
    {
        private Godot.Quaternion _value;

        public float x { get => _value.X; set => _value.X = value; }
        public float y { get => _value.Y; set => _value.Y = value; }
        public float z { get => _value.Z; set => _value.Z = value; }
        public float w { get => _value.W; set => _value.W = value; }

        public Quaternion(float x, float y, float z, float w)
        {
            _value = new Godot.Quaternion(x, y, z, w);
        }

        // Unity static properties
        public static Quaternion identity => new Quaternion(0, 0, 0, 1);

        // Unity instance properties
        public Vector3 eulerAngles
        {
            get => _value.GetEuler() * (180f / Mathf.PI);
            set => _value = Godot.Quaternion.FromEuler(value * (Mathf.PI / 180f));
        }

        // Unity methods
        public void Set(float newX, float newY, float newZ, float newW) { x = newX; y = newY; z = newZ; w = newW; }

        // Unity static methods
        public static Quaternion Euler(float x, float y, float z) => Godot.Quaternion.FromEuler(new Godot.Vector3(x, y, z) * (Mathf.PI / 180f));
        public static Quaternion Euler(Vector3 euler) => Euler(euler.x, euler.y, euler.z);
        public static float Dot(Quaternion a, Quaternion b) => a._value.Dot(b._value);
        public static float Angle(Quaternion a, Quaternion b) => a._value.AngleTo(b._value) * (180f / Mathf.PI);
        public static Quaternion AngleAxis(float angle, Vector3 axis) => new Godot.Basis(axis, angle * (Mathf.PI / 180f)).GetRotationQuaternion();
        public static Quaternion LookRotation(Vector3 forward) => LookRotation(forward, Vector3.up);
        public static Quaternion LookRotation(Vector3 forward, Vector3 upwards)
        {
            // Godot's Basis.LookingAt looks in the NEGATIVE direction of the given vector
            // Unity's LookRotation looks in the POSITIVE direction
            // So we need to negate the forward vector
            var basis = Godot.Basis.LookingAt(-forward, upwards);
            return basis.GetRotationQuaternion();
        }
        public static Quaternion FromToRotation(Vector3 fromDirection, Vector3 toDirection)
        {
            var axis = Vector3.Cross(fromDirection.normalized, toDirection.normalized);
            var angle = Vector3.Angle(fromDirection, toDirection);
            return AngleAxis(angle, axis.normalized);
        }
        public static Quaternion Slerp(Quaternion a, Quaternion b, float t) => a._value.Slerp(b._value, t);
        public static Quaternion Lerp(Quaternion a, Quaternion b, float t) => a._value.Slerp(b._value, t); // Unity's Lerp is similar to Slerp
        public static Quaternion Inverse(Quaternion rotation) => rotation._value.Inverse();

        // Operators
        public static Quaternion operator *(Quaternion lhs, Quaternion rhs) => lhs._value * rhs._value;
        public static Vector3 operator *(Quaternion rotation, Vector3 point) => rotation._value * point;
        public static bool operator ==(Quaternion lhs, Quaternion rhs) => lhs._value == rhs._value;
        public static bool operator !=(Quaternion lhs, Quaternion rhs) => lhs._value != rhs._value;

        // Conversions
        public static implicit operator Quaternion(Godot.Quaternion q) => new Quaternion { _value = q };
        public static implicit operator Godot.Quaternion(Quaternion q) => q._value;

        public override bool Equals(object obj) => obj is Quaternion q && _value == q._value;
        public bool Equals(Quaternion other) => _value == other._value;
        public override int GetHashCode() => _value.GetHashCode();
        public override string ToString() => $"({x}, {y}, {z}, {w})";
    }

    // Color wrapper - matches Unity API with lowercase properties
    public struct Color : IEquatable<Color>
    {
        private Godot.Color _value;

        public float r { get => _value.R; set => _value.R = value; }
        public float g { get => _value.G; set => _value.G = value; }
        public float b { get => _value.B; set => _value.B = value; }
        public float a { get => _value.A; set => _value.A = value; }

        public Color(float r, float g, float b, float a = 1f)
        {
            _value = new Godot.Color(r, g, b, a);
        }

        // Unity static colors
        public static Color red => new Color(1, 0, 0, 1);
        public static Color green => new Color(0, 1, 0, 1);
        public static Color blue => new Color(0, 0, 1, 1);
        public static Color white => new Color(1, 1, 1, 1);
        public static Color black => new Color(0, 0, 0, 1);
        public static Color yellow => new Color(1, 0.92f, 0.016f, 1);
        public static Color cyan => new Color(0, 1, 1, 1);
        public static Color magenta => new Color(1, 0, 1, 1);
        public static Color gray => new Color(0.5f, 0.5f, 0.5f, 1);
        public static Color grey => gray;
        public static Color clear => new Color(0, 0, 0, 0);

        // Unity methods
        public static Color Lerp(Color a, Color b, float t) => a._value.Lerp(b._value, t);

        // Operators
        public static Color operator +(Color a, Color b) => new Color(a.r + b.r, a.g + b.g, a.b + b.b, a.a + b.a);
        public static Color operator -(Color a, Color b) => new Color(a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a);
        public static Color operator *(Color a, Color b) => new Color(a.r * b.r, a.g * b.g, a.b * b.b, a.a * b.a);
        public static Color operator *(Color a, float b) => new Color(a.r * b, a.g * b, a.b * b, a.a * b);
        public static Color operator *(float b, Color a) => new Color(a.r * b, a.g * b, a.b * b, a.a * b);
        public static Color operator /(Color a, float b) => new Color(a.r / b, a.g / b, a.b / b, a.a / b);
        public static bool operator ==(Color lhs, Color rhs) => lhs._value == rhs._value;
        public static bool operator !=(Color lhs, Color rhs) => lhs._value != rhs._value;

        // Conversions
        public static implicit operator Color(Godot.Color c) => new Color { _value = c };
        public static implicit operator Godot.Color(Color c) => c._value;

        public override bool Equals(object obj) => obj is Color c && _value == c._value;
        public bool Equals(Color other) => _value == other._value;
        public override int GetHashCode() => _value.GetHashCode();
        public override string ToString() => $"RGBA({r}, {g}, {b}, {a})";
    }

    // Color32 - Unity's byte-based color
    public struct Color32
    {
        public byte r, g, b, a;

        public Color32(byte r, byte g, byte b, byte a)
        {
            this.r = r; this.g = g; this.b = b; this.a = a;
        }

        public static implicit operator Color(Color32 c) => new Color(c.r / 255f, c.g / 255f, c.b / 255f, c.a / 255f);
        public static implicit operator Color32(Color c) => new Color32(
            (byte)(c.r * 255), (byte)(c.g * 255), (byte)(c.b * 255), (byte)(c.a * 255)
        );
    }

    // Plane wrapper - matches Unity API
    public struct Plane : IEquatable<Plane>
    {
        private Godot.Plane _value;

        public Vector3 normal { get => _value.Normal; set => _value.Normal = value; }
        public float distance { get => _value.D; set => _value.D = value; }

        public Plane(Vector3 inNormal, float d)
        {
            _value = new Godot.Plane(inNormal, d);
        }

        public Plane(Vector3 a, Vector3 b, Vector3 c)
        {
            _value = new Godot.Plane(a, b, c);
        }

        // Conversions
        public static implicit operator Plane(Godot.Plane p) => new Plane { _value = p };
        public static implicit operator Godot.Plane(Plane p) => p._value;

        public override bool Equals(object obj) => obj is Plane p && _value == p._value;
        public bool Equals(Plane other) => _value == other._value;
        public override int GetHashCode() => _value.GetHashCode();
    }

    // Matrix4x4 - thin wrapper around Godot's Transform3D
    public struct Matrix4x4
    {
        private Godot.Transform3D _transform;

        public Matrix4x4(Godot.Transform3D transform)
        {
            _transform = transform;
        }

        public static Matrix4x4 identity => new Matrix4x4(Godot.Transform3D.Identity);

        public static Matrix4x4 TRS(Vector3 pos, Quaternion q, Vector3 s)
        {
            var transform = new Godot.Transform3D(Godot.Basis.FromScale(s) * new Godot.Basis(q), pos);
            return new Matrix4x4(transform);
        }

        public Vector4 GetColumn(int index)
        {
            return index switch
            {
                0 => new Vector4(m00, m10, m20, m30),
                1 => new Vector4(m01, m11, m21, m31),
                2 => new Vector4(m02, m12, m22, m32),
                3 => new Vector4(m03, m13, m23, m33),
                _ => throw new ArgumentOutOfRangeException(nameof(index))
            };
        }

        public Quaternion rotation => _transform.Basis.GetRotationQuaternion();
        public Vector3 lossyScale => _transform.Basis.Scale;

        public float m00 { get => _transform.Basis.X.X; set { var b = _transform.Basis; b.X = new Godot.Vector3(value, b.X.Y, b.X.Z); _transform.Basis = b; } }
        public float m01 { get => _transform.Basis.X.Y; set { var b = _transform.Basis; b.X = new Godot.Vector3(b.X.X, value, b.X.Z); _transform.Basis = b; } }
        public float m02 { get => _transform.Basis.X.Z; set { var b = _transform.Basis; b.X = new Godot.Vector3(b.X.X, b.X.Y, value); _transform.Basis = b; } }
        public float m03 { get => _transform.Origin.X; set { _transform.Origin = new Godot.Vector3(value, _transform.Origin.Y, _transform.Origin.Z); } }

        public float m10 { get => _transform.Basis.Y.X; set { var b = _transform.Basis; b.Y = new Godot.Vector3(value, b.Y.Y, b.Y.Z); _transform.Basis = b; } }
        public float m11 { get => _transform.Basis.Y.Y; set { var b = _transform.Basis; b.Y = new Godot.Vector3(b.Y.X, value, b.Y.Z); _transform.Basis = b; } }
        public float m12 { get => _transform.Basis.Y.Z; set { var b = _transform.Basis; b.Y = new Godot.Vector3(b.Y.X, b.Y.Y, value); _transform.Basis = b; } }
        public float m13 { get => _transform.Origin.Y; set { _transform.Origin = new Godot.Vector3(_transform.Origin.X, value, _transform.Origin.Z); } }

        public float m20 { get => _transform.Basis.Z.X; set { var b = _transform.Basis; b.Z = new Godot.Vector3(value, b.Z.Y, b.Z.Z); _transform.Basis = b; } }
        public float m21 { get => _transform.Basis.Z.Y; set { var b = _transform.Basis; b.Z = new Godot.Vector3(b.Z.X, value, b.Z.Z); _transform.Basis = b; } }
        public float m22 { get => _transform.Basis.Z.Z; set { var b = _transform.Basis; b.Z = new Godot.Vector3(b.Z.X, b.Z.Y, value); _transform.Basis = b; } }
        public float m23 { get => _transform.Origin.Z; set { _transform.Origin = new Godot.Vector3(_transform.Origin.X, _transform.Origin.Y, value); } }

        public float m30 { get => 0; set { } }
        public float m31 { get => 0; set { } }
        public float m32 { get => 0; set { } }
        public float m33 { get => 1; set { } }

        public Vector3 MultiplyPoint3x4(Vector3 point) => _transform * point;
        public Vector3 MultiplyPoint(Vector3 point) => _transform * point;
        public Vector3 MultiplyVector(Vector3 vector) => _transform.Basis * vector;

        public static implicit operator Godot.Transform3D(Matrix4x4 m) => m._transform;
        public static implicit operator Matrix4x4(Godot.Transform3D t) => new Matrix4x4(t);
    }
}
