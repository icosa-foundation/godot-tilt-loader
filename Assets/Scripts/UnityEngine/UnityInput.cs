// Unity Input and Profiling stubs
using Godot;

namespace UnityEngine
{
    // Input stub - basic Godot Input wrapper
    public static class Input
    {
        public static bool IsKeyJustPressed(Key key) => Godot.Input.IsKeyPressed(key);
        public static bool IsKeyJustReleased(Key key) => !Godot.Input.IsKeyPressed(key);
    }
}

namespace UnityEngine.Profiling
{
    // Profiling stub for compatibility
    public static class Profiler
    {
        public static void BeginSample(string name)
        {
            // Stub - no-op
        }

        public static void EndSample()
        {
            // Stub - no-op
        }
    }
}
