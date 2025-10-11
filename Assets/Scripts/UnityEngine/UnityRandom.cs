// Unity Random stub
using System;

namespace UnityEngine
{
    // Random stub - wraps System.Random
    public static class Random
    {
        private static System.Random _random = new System.Random();

        public static float value => (float)_random.NextDouble();
        public static float Range(float min, float max) => min + (float)_random.NextDouble() * (max - min);
        public static int Range(int min, int max) => _random.Next(min, max);
    }
}
