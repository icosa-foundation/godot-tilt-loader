// Unity-to-Godot compatibility layer for Mathf utilities
using System;

namespace UnityEngine
{
    public static class Mathf
    {
        public const float PI = (float)Math.PI;
        public const float Deg2Rad = PI / 180f;
        public const float Rad2Deg = 180f / PI;
        public const float Epsilon = 1e-5f;

        public static float Abs(float value) => Math.Abs(value);
        public static int Abs(int value) => Math.Abs(value);

        public static float Acos(float value) => (float)Math.Acos(value);
        public static float Asin(float value) => (float)Math.Asin(value);
        public static float Atan(float value) => (float)Math.Atan(value);
        public static float Atan2(float y, float x) => (float)Math.Atan2(y, x);

        public static float Ceil(float value) => (float)Math.Ceiling(value);
        public static int CeilToInt(float value) => (int)Math.Ceiling(value);

        public static float Clamp(float value, float min, float max) => value < min ? min : (value > max ? max : value);
        public static int Clamp(int value, int min, int max) => value < min ? min : (value > max ? max : value);
        public static float Clamp01(float value) => Clamp(value, 0f, 1f);

        public static float Cos(float value) => (float)Math.Cos(value);

        public static float Exp(float power) => (float)Math.Exp(power);

        public static float Floor(float value) => (float)Math.Floor(value);
        public static int FloorToInt(float value) => (int)Math.Floor(value);

        public static float Lerp(float a, float b, float t) => a + (b - a) * Clamp01(t);
        public static float LerpUnclamped(float a, float b, float t) => a + (b - a) * t;
        public static float InverseLerp(float a, float b, float value) => (value - a) / (b - a);

        public static float Log(float value) => (float)Math.Log(value);
        public static float Log10(float value) => (float)Math.Log10(value);

        public static float Max(float a, float b) => a > b ? a : b;
        public static int Max(int a, int b) => a > b ? a : b;
        public static float Max(params float[] values)
        {
            if (values.Length == 0) return 0;
            float max = values[0];
            for (int i = 1; i < values.Length; i++)
                if (values[i] > max) max = values[i];
            return max;
        }

        public static float Min(float a, float b) => a < b ? a : b;
        public static int Min(int a, int b) => a < b ? a : b;
        public static float Min(params float[] values)
        {
            if (values.Length == 0) return 0;
            float min = values[0];
            for (int i = 1; i < values.Length; i++)
                if (values[i] < min) min = values[i];
            return min;
        }

        public static float Pow(float f, float p) => (float)Math.Pow(f, p);

        public static float Round(float value) => (float)Math.Round(value);
        public static int RoundToInt(float value) => (int)Math.Round(value);

        public static float Sign(float value) => value >= 0f ? 1f : -1f;

        public static float Sin(float value) => (float)Math.Sin(value);

        public static float Sqrt(float value) => (float)Math.Sqrt(value);

        public static float Tan(float value) => (float)Math.Tan(value);

        public static bool Approximately(float a, float b) => Abs(a - b) < Epsilon;
    }
}
