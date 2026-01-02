// Copyright 2020 The Tilt Brush Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Runtime.InteropServices;
using Godot;
using Newtonsoft.Json;

namespace OpenBrush.TiltFile
{
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    [JsonConverter(typeof(Vector2Converter))]
    public struct Vector2
    {
        public float x;
        public float y;

        public Vector2(float x, float y)
        {
            this.x = x;
            this.y = y;
        }

        public static implicit operator Godot.Vector2(Vector2 v) => new Godot.Vector2(v.x, v.y);
        public static implicit operator Vector2(Godot.Vector2 v) => new Vector2(v.X, v.Y);

        public static Vector2 operator +(Vector2 a, Vector2 b) => new Vector2(a.x + b.x, a.y + b.y);
        public static Vector2 operator -(Vector2 a, Vector2 b) => new Vector2(a.x - b.x, a.y - b.y);
        public static Vector2 operator *(Vector2 v, float s) => new Vector2(v.x * s, v.y * s);
        public static Vector2 operator *(float s, Vector2 v) => new Vector2(v.x * s, v.y * s);
        public static Vector2 operator /(Vector2 v, float s) => new Vector2(v.x / s, v.y / s);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    [JsonConverter(typeof(Vector3Converter))]
    public struct Vector3
    {
        public float x;
        public float y;
        public float z;

        public Vector3(float x, float y, float z)
        {
            this.x = x;
            this.y = y;
            this.z = z;
        }

        public static implicit operator Godot.Vector3(Vector3 v) => new Godot.Vector3(v.x, v.y, v.z);
        public static implicit operator Vector3(Godot.Vector3 v) => new Vector3(v.X, v.Y, v.Z);

        public static Vector3 zero => new Vector3(0f, 0f, 0f);
        public static Vector3 one => new Vector3(1f, 1f, 1f);
        public static Vector3 forward => new Vector3(0f, 0f, 1f);
        public static Vector3 up => new Vector3(0f, 1f, 0f);
        public static Vector3 right => new Vector3(1f, 0f, 0f);

        public float magnitude => ((Godot.Vector3)this).Length();
        public float sqrMagnitude => ((Godot.Vector3)this).LengthSquared();
        public Vector3 normalized => (Vector3)((Godot.Vector3)this).Normalized();

        public static Vector3 Lerp(Vector3 a, Vector3 b, float t)
        {
            return (Vector3)((Godot.Vector3)a).Lerp((Godot.Vector3)b, t);
        }

        public static float Dot(Vector3 a, Vector3 b) => ((Godot.Vector3)a).Dot((Godot.Vector3)b);

        public static Vector3 operator +(Vector3 a, Vector3 b) => new Vector3(a.x + b.x, a.y + b.y, a.z + b.z);
        public static Vector3 operator -(Vector3 a, Vector3 b) => new Vector3(a.x - b.x, a.y - b.y, a.z - b.z);
        public static Vector3 operator -(Vector3 v) => new Vector3(-v.x, -v.y, -v.z);
        public static Vector3 operator *(Vector3 v, float s) => new Vector3(v.x * s, v.y * s, v.z * s);
        public static Vector3 operator *(float s, Vector3 v) => new Vector3(v.x * s, v.y * s, v.z * s);
        public static Vector3 operator /(Vector3 v, float s) => new Vector3(v.x / s, v.y / s, v.z / s);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    [JsonConverter(typeof(Vector4Converter))]
    public struct Vector4
    {
        public float x;
        public float y;
        public float z;
        public float w;

        public Vector4(float x, float y, float z, float w)
        {
            this.x = x;
            this.y = y;
            this.z = z;
            this.w = w;
        }

        public static implicit operator Godot.Vector4(Vector4 v) => new Godot.Vector4(v.x, v.y, v.z, v.w);
        public static implicit operator Vector4(Godot.Vector4 v) => new Vector4(v.X, v.Y, v.Z, v.W);

        public float magnitude => ((Godot.Vector4)this).Length();
        public float sqrMagnitude => ((Godot.Vector4)this).LengthSquared();
        public Vector4 normalized => (Vector4)((Godot.Vector4)this).Normalized();

        public static Vector4 operator *(Vector4 v, float s) => new Vector4(v.x * s, v.y * s, v.z * s, v.w * s);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    [JsonConverter(typeof(QuaternionConverter))]
    public struct Quaternion
    {
        public float x;
        public float y;
        public float z;
        public float w;

        public Quaternion(float x, float y, float z, float w)
        {
            this.x = x;
            this.y = y;
            this.z = z;
            this.w = w;
        }

        public static implicit operator Godot.Quaternion(Quaternion q) => new Godot.Quaternion(q.x, q.y, q.z, q.w);
        public static implicit operator Quaternion(Godot.Quaternion q) => new Quaternion(q.X, q.Y, q.Z, q.W);

        public static Quaternion identity => new Quaternion(0f, 0f, 0f, 1f);

        public static Quaternion AngleAxis(float angleDegrees, Vector3 axis)
        {
            float angleRadians = Mathf.DegToRad(angleDegrees);
            return (Quaternion)new Godot.Quaternion((Godot.Vector3)axis, angleRadians);
        }

        public static Quaternion Slerp(Quaternion a, Quaternion b, float t)
        {
            return (Quaternion)((Godot.Quaternion)a).Slerp((Godot.Quaternion)b, t);
        }

        public static Quaternion operator *(Quaternion a, Quaternion b)
        {
            return (Quaternion)((Godot.Quaternion)a * (Godot.Quaternion)b);
        }

        public static Vector3 operator *(Quaternion q, Vector3 v)
        {
            return (Vector3)((Godot.Quaternion)q * (Godot.Vector3)v);
        }
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    [JsonConverter(typeof(ColorConverter))]
    public struct Color
    {
        public float r;
        public float g;
        public float b;
        public float a;

        public Color(float r, float g, float b, float a = 1.0f)
        {
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
        }

        public static implicit operator Godot.Color(Color c) => new Godot.Color(c.r, c.g, c.b, c.a);
        public static implicit operator Color(Godot.Color c) => new Color(c.R, c.G, c.B, c.A);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    [JsonConverter(typeof(Color32Converter))]
    public struct Color32
    {
        public byte r;
        public byte g;
        public byte b;
        public byte a;

        public Color32(byte r, byte g, byte b, byte a = 255)
        {
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
        }

        public static implicit operator Godot.Color(Color32 c)
        {
            const float inv = 1.0f / 255.0f;
            return new Godot.Color(c.r * inv, c.g * inv, c.b * inv, c.a * inv);
        }

        public static implicit operator Color32(Godot.Color c)
        {
            return new Color32(
                (byte)System.Math.Clamp((int)(c.R * 255.0f), 0, 255),
                (byte)System.Math.Clamp((int)(c.G * 255.0f), 0, 255),
                (byte)System.Math.Clamp((int)(c.B * 255.0f), 0, 255),
                (byte)System.Math.Clamp((int)(c.A * 255.0f), 0, 255));
        }
    }
}
