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

namespace OpenBrush.TiltFile
{
    public static class Model
    {
        public readonly struct Location
        {
            public enum Type
            {
                Invalid = 0,
                LocalFile = 1,
                IcosaAssetId = 2
            }

            private readonly Type m_type;
            private readonly string m_path;
            private readonly string m_id;

            private Location(Type type, string path, string id)
            {
                m_type = type;
                m_path = path;
                m_id = id;
            }

            public static Location File(string relativePath)
            {
                int lastIndex = relativePath.LastIndexOf('#');
                string path = lastIndex == -1 ? relativePath : relativePath.Substring(0, lastIndex);
                return new Location(Type.LocalFile, path, null);
            }

            public static Location IcosaAsset(string assetId, string path)
            {
                return new Location(Type.IcosaAssetId, path, assetId);
            }

            public Type GetLocationType() => m_type;

            public string RelativePath
            {
                get
                {
                    if (m_type == Type.LocalFile) { return m_path; }
                    throw new System.InvalidOperationException("Invalid relative path request.");
                }
            }

            public string AssetId
            {
                get
                {
                    if (m_type == Type.IcosaAssetId) { return m_id; }
                    throw new System.InvalidOperationException("Invalid Icosa asset id request.");
                }
            }

            public override int GetHashCode()
            {
                return ToString().GetHashCode();
            }

            public override string ToString()
            {
                return (m_type == Type.IcosaAssetId) ? $"{m_type}:{m_id}" : $"{m_type}:{m_path}";
            }

            public override bool Equals(object obj)
            {
                return obj is Location other && this == other;
            }

            public static bool operator ==(Location a, Location b)
            {
                return a.m_type == b.m_type && a.m_path == b.m_path && a.m_id == b.m_id;
            }

            public static bool operator !=(Location a, Location b)
            {
                return !(a == b);
            }
        }
    }
}
