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
using Godot;

namespace OpenBrush.TiltFile
{
    /// <summary>
    /// Abstraction for logging to decouple from engine-specific logging
    /// </summary>
    public interface ITiltFileLogger
    {
        void Log(string message);
        void LogWarning(string message);
        void LogError(string message);
        void LogFormat(string format, params object[] args);
        void LogWarningFormat(string format, params object[] args);
        void LogErrorFormat(string format, params object[] args);
    }

    /// <summary>
    /// Default logger that does nothing (silent)
    /// </summary>
    public class NullLogger : ITiltFileLogger
    {
        public static readonly NullLogger Instance = new NullLogger();

        public void Log(string message) { }
        public void LogWarning(string message) { }
        public void LogError(string message) { }
        public void LogFormat(string format, params object[] args) { }
        public void LogWarningFormat(string format, params object[] args) { }
        public void LogErrorFormat(string format, params object[] args) { }
    }

    /// <summary>
    /// Godot-specific logger implementation
    /// </summary>
    public class GodotLogger : ITiltFileLogger
    {
        public static readonly GodotLogger Instance = new GodotLogger();

        public void Log(string message) => GD.Print(message);
        public void LogWarning(string message) => GD.PushWarning(message);
        public void LogError(string message) => GD.PushError(message);
        public void LogFormat(string format, params object[] args) => GD.Print(string.Format(format, args));
        public void LogWarningFormat(string format, params object[] args) => GD.PushWarning(string.Format(format, args));
        public void LogErrorFormat(string format, params object[] args) => GD.PushError(string.Format(format, args));
    }
}
