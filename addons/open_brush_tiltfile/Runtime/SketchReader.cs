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
using System.Collections.Generic;
using System.IO;

namespace OpenBrush.TiltFile
{
    [Flags]
    public enum StrokeFlags : uint
    {
        None = 0,
        IsGroupContinue = 1 << 0,
    }

    [Flags]
    public enum StrokeExtension : uint
    {
        MaskSingleWord = 0xffff,
        None = 0,
        Flags = 1 << 0,
        Scale = 1 << 1,
        Group = 1 << 2,
        Seed = 1 << 3,
        Layer = 1 << 4,
    }

    [Flags]
    public enum ControlPointExtension : uint
    {
        None = 0,
        Pressure = 1 << 0,
        Timestamp = 1 << 1,
    }

    public struct StrokeControlPoint
    {
        public Vector3 Position;
        public Quaternion Orientation;
        public float Pressure;
        public uint TimestampMs;
    }

    public sealed class StrokeData
    {
        public Guid BrushGuid;
        public Color Color;
        public float BrushSize;
        public float BrushScale;
        public int Seed;
        public StrokeFlags Flags;
        public uint GroupId;
        public uint LayerIndex;
        public List<StrokeControlPoint> ControlPoints = new List<StrokeControlPoint>();
    }

    public static class SketchReader
    {
        private const int RequiredSketchVersionMin = 5;
        private const int RequiredSketchVersionMax = 6;
        private static readonly uint SketchSentinel = 0xc576a5cd;

        public static List<StrokeData> ReadStrokes(Stream stream, Guid[] brushList)
        {
            if (brushList != null && brushList.Length > 0)
            {
                List<StrokeData> strokes = TryReadStrokesWithBrushList(stream, brushList);
                if (strokes != null)
                {
                    return strokes;
                }
                if (stream.CanSeek)
                {
                    stream.Seek(0, SeekOrigin.Begin);
                }
            }

            return TryReadStrokesWithEmbeddedGuids(stream);
        }

        private static List<StrokeData> TryReadStrokesWithBrushList(Stream stream, Guid[] brushList)
        {
            try
            {
                var reader = new SketchBinaryReader(stream);

                uint sentinel = reader.UInt32();
                if (sentinel != SketchSentinel)
                {
                    TiltFile.Logger.LogError("Invalid .sketch: bad sentinel");
                    return null;
                }

                int version = reader.Int32();
                if (version < RequiredSketchVersionMin || version > RequiredSketchVersionMax)
                {
                    TiltFile.Logger.LogErrorFormat("Invalid .sketch: unsupported version {0}", version);
                    return null;
                }

                reader.Int32();
                uint moreHeader = reader.UInt32();
                if (!reader.Skip(moreHeader))
                {
                    return null;
                }

                int numStrokes = reader.Int32();
                var result = new List<StrokeData>(Math.Max(0, numStrokes));
                for (int i = 0; i < numStrokes; ++i)
                {
                    int brushIndex = reader.Int32();
                    var stroke = new StrokeData
                    {
                        BrushGuid = (brushIndex >= 0 && brushIndex < brushList.Length)
                            ? brushList[brushIndex]
                            : Guid.Empty,
                        Color = reader.Color(),
                        BrushSize = reader.Float(),
                        BrushScale = 1f,
                        Seed = 0,
                        Flags = StrokeFlags.None,
                        GroupId = 0,
                        LayerIndex = 0
                    };

                    uint strokeExtensionMask = reader.UInt32();
                    uint controlPointExtensionMask = reader.UInt32();

                    if ((strokeExtensionMask & (uint)StrokeExtension.Seed) == 0)
                    {
                        unchecked
                        {
                            int seed = i;
                            seed = (seed * 397) ^ stroke.BrushGuid.GetHashCode();
                            seed = (seed * 397) ^ stroke.Color.GetHashCode();
                            seed = (seed * 397) ^ stroke.BrushSize.GetHashCode();
                            stroke.Seed = seed;
                        }
                    }

                    if (!ApplyStrokeExtensions(reader, strokeExtensionMask, ref stroke))
                    {
                        return null;
                    }
                    if (!ReadControlPoints(reader, controlPointExtensionMask, stroke))
                    {
                        return null;
                    }

                    result.Add(stroke);
                }

                return result;
            }
            catch
            {
                return null;
            }
        }

        private static List<StrokeData> TryReadStrokesWithEmbeddedGuids(Stream stream)
        {
            try
            {
                var reader = new SketchBinaryReader(stream);

                uint sentinel = reader.UInt32();
                if (sentinel != SketchSentinel)
                {
                    TiltFile.Logger.LogError("Invalid .sketch: bad sentinel");
                    return null;
                }

                int version = reader.Int32();
                if (version < RequiredSketchVersionMin || version > RequiredSketchVersionMax)
                {
                    TiltFile.Logger.LogErrorFormat("Invalid .sketch: unsupported version {0}", version);
                    return null;
                }

                reader.Int32();
                uint moreHeader = reader.UInt32();
                if (!reader.Skip(moreHeader))
                {
                    return null;
                }

                int numStrokes = reader.Int32();
                var result = new List<StrokeData>(Math.Max(0, numStrokes));
                for (int i = 0; i < numStrokes; ++i)
                {
                    var stroke = new StrokeData
                    {
                        BrushGuid = reader.ReadGuid(),
                        Color = reader.Color(),
                        BrushSize = reader.Float(),
                        BrushScale = 1f,
                        Seed = 0,
                        Flags = StrokeFlags.None,
                        GroupId = 0,
                        LayerIndex = 0
                    };

                    uint strokeExtensionMask = reader.UInt32();
                    uint controlPointExtensionMask = reader.UInt32();

                    if ((strokeExtensionMask & (uint)StrokeExtension.Seed) == 0)
                    {
                        unchecked
                        {
                            int seed = i;
                            seed = (seed * 397) ^ stroke.BrushGuid.GetHashCode();
                            seed = (seed * 397) ^ stroke.Color.GetHashCode();
                            seed = (seed * 397) ^ stroke.BrushSize.GetHashCode();
                            stroke.Seed = seed;
                        }
                    }

                    if (!ApplyStrokeExtensions(reader, strokeExtensionMask, ref stroke))
                    {
                        return null;
                    }
                    if (!ReadControlPoints(reader, controlPointExtensionMask, stroke))
                    {
                        return null;
                    }

                    result.Add(stroke);
                }

                return result;
            }
            catch
            {
                return null;
            }
        }

        private static bool ApplyStrokeExtensions(
            SketchBinaryReader reader, uint strokeExtensionMask, ref StrokeData stroke)
        {
            for (uint fields = strokeExtensionMask; fields != 0; fields &= (fields - 1))
            {
                uint bit = (fields & ~(fields - 1));
                switch ((StrokeExtension)bit)
                {
                    case StrokeExtension.Flags:
                        stroke.Flags = (StrokeFlags)reader.UInt32();
                        break;
                    case StrokeExtension.Scale:
                        stroke.BrushScale = reader.Float();
                        break;
                    case StrokeExtension.Group:
                        stroke.GroupId = reader.UInt32();
                        break;
                    case StrokeExtension.Layer:
                        stroke.LayerIndex = reader.UInt32();
                        break;
                    case StrokeExtension.Seed:
                        stroke.Seed = reader.Int32();
                        break;
                    default:
                        if ((bit & (uint)StrokeExtension.MaskSingleWord) != 0)
                        {
                            reader.UInt32();
                        }
                        else
                        {
                            uint size = reader.UInt32();
                            if (!reader.Skip(size))
                            {
                                return false;
                            }
                        }
                        break;
                }
            }
            return true;
        }

        private static bool ReadControlPoints(
            SketchBinaryReader reader, uint controlPointExtensionMask, StrokeData stroke)
        {
            int numControlPoints = reader.Int32();
            for (int j = 0; j < numControlPoints; ++j)
            {
                var cp = new StrokeControlPoint
                {
                    Position = reader.Vec3(),
                    Orientation = reader.Quaternion(),
                    Pressure = 1.0f,
                    TimestampMs = 0
                };

                for (uint fields = controlPointExtensionMask; fields != 0; fields &= (fields - 1))
                {
                    switch ((ControlPointExtension)(fields & ~(fields - 1)))
                    {
                        case ControlPointExtension.Pressure:
                            cp.Pressure = reader.Float();
                            break;
                        case ControlPointExtension.Timestamp:
                            cp.TimestampMs = reader.UInt32();
                            break;
                        default:
                            reader.Int32();
                            break;
                    }
                }
                stroke.ControlPoints.Add(cp);
            }
            return true;
        }
    }
}
