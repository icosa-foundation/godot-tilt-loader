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

namespace OpenBrush.TiltFile
{
    public static class WidgetManager
    {
        public static string GetModelSubpath(string fullPath)
        {
            if (string.IsNullOrEmpty(fullPath))
            {
                throw new ArgumentException("Path must not be empty.", nameof(fullPath));
            }
            if (!System.IO.Path.IsPathRooted(fullPath))
            {
                throw new ArgumentException("Path is not rooted.", nameof(fullPath));
            }

            string normalized = fullPath.Replace('\\', '/');
            const string marker = "/Media Library/Models/";
            int index = normalized.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
            if (index < 0)
            {
                return null;
            }

            return normalized.Substring(index + marker.Length);
        }
    }
}
