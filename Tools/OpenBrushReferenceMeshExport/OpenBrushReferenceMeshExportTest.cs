// Copy this file into the Open Brush Unity project at:
// Assets/Editor/Tests/OpenBrushReferenceMeshExportTest.cs
//
// It is kept in the Godot parity repo so the fixture contract can be reviewed
// with the Godot-side comparator before the Unity-side exporter is run.

using System;
using System.IO;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using NUnit.Framework;
using UnityEngine;

namespace TiltBrush
{
    public class OpenBrushReferenceMeshExportTest
    {
        private const string kSchema = "open-brush-reference-mesh-v1";
        private const string kGodotRootEnvVar = "OPEN_BRUSH_STROKE_GEN_GODOT_ROOT";

        private static readonly ReferenceFixtureSpec[] kRepresentativeCafeFixtures =
        {
            new ReferenceFixtureSpec(
                name: "cafe_ink_stroke_150",
                brushName: "Ink",
                sourceStrokeFixtureRelativePath: "Resources/Fixtures/cafe_ink_stroke_150.json"),
            new ReferenceFixtureSpec(
                name: "cafe_duct_tape_geometry_stroke_496",
                brushName: "DuctTapeGeometry",
                sourceStrokeFixtureRelativePath: "Resources/Fixtures/cafe_duct_tape_geometry_stroke_496.json"),
            new ReferenceFixtureSpec(
                name: "cafe_stars_stroke_130",
                brushName: "Stars",
                sourceStrokeFixtureRelativePath: "Resources/Fixtures/cafe_stars_stroke_130.json"),
            new ReferenceFixtureSpec(
                name: "cafe_sparks_stroke_463",
                brushName: "Sparks",
                sourceStrokeFixtureRelativePath: "Resources/Fixtures/cafe_sparks_stroke_463.json"),
            new ReferenceFixtureSpec(
                name: "cafe_matte_hull_stroke_11",
                brushName: "MatteHull",
                sourceStrokeFixtureRelativePath: "Resources/Fixtures/cafe_matte_hull_stroke_11.json")
        };

        [Test]
        [Explicit("Writes representative Open Brush reference mesh fixtures into the Godot parity repo.")]
        [Category("OpenBrushReferenceExport")]
        public void ExportRepresentativeCafeFixtures()
        {
            foreach (ReferenceFixtureSpec spec in kRepresentativeCafeFixtures)
            {
                ExportReferenceFixture(
                    name: spec.Name,
                    brushName: spec.BrushName,
                    sourceStrokeFixtureRelativePath: spec.SourceStrokeFixtureRelativePath);
            }
        }

        [Test]
        [Explicit("Writes Open Brush reference mesh fixtures into the Godot parity repo.")]
        [Category("OpenBrushReferenceExport")]
        public void ExportCafeInkStroke150()
        {
            ReferenceFixtureSpec spec = kRepresentativeCafeFixtures[0];
            ExportReferenceFixture(
                name: spec.Name,
                brushName: spec.BrushName,
                sourceStrokeFixtureRelativePath: spec.SourceStrokeFixtureRelativePath);
        }

        private static void ExportReferenceFixture(
            string name,
            string brushName,
            string sourceStrokeFixtureRelativePath)
        {
            string godotRoot = FindGodotRoot();
            string sourcePath = Path.Combine(
                godotRoot,
                sourceStrokeFixtureRelativePath.Replace('/', Path.DirectorySeparatorChar));
            string outputDirectory = Path.Combine(
                godotRoot,
                "Resources",
                "Fixtures",
                "OpenBrushReferenceMeshes");
            string outputPath = Path.Combine(outputDirectory, name + ".json");

            Assert.IsTrue(File.Exists(sourcePath), $"Missing stroke fixture: {sourcePath}");

            StrokeFixture sourceFixture = JsonConvert.DeserializeObject<StrokeFixture>(
                File.ReadAllText(sourcePath));
            Assert.NotNull(sourceFixture, $"Could not parse stroke fixture: {sourcePath}");

            var testBrush = new TestBrush();
            testBrush.RunBeforeAnyTests();
            CanvasScript canvas = CanvasScript.UnitTestSetUp(new GameObject(name + " canvas"));
            try
            {
                Stroke stroke = CreateStroke(sourceFixture);
                BrushDescriptor desc = BrushCatalog.m_Instance.GetBrush(stroke.m_BrushGuid);
                Assert.NotNull(desc, $"Open Brush could not resolve brush GUID {stroke.m_BrushGuid}");
                Assert.AreEqual(brushName, desc.m_DurableName);

                BatchSubset subset = CreateFinalizedSubset(canvas, stroke, desc);
                JObject fixture = CreateReferenceFixtureJson(
                    name,
                    brushName,
                    sourceStrokeFixtureRelativePath,
                    subset);

                Directory.CreateDirectory(outputDirectory);
                File.WriteAllText(outputPath, fixture.ToString(Formatting.Indented));
                Debug.Log($"OPEN_BRUSH_REFERENCE_EXPORT wrote {outputPath}");
            }
            finally
            {
                CanvasScript.UnitTestTearDown(canvas.gameObject);
                testBrush.RunAfterAllTests();
            }
        }

        private static string FindGodotRoot()
        {
            string configuredRoot = System.Environment.GetEnvironmentVariable(kGodotRootEnvVar);
            if (!string.IsNullOrEmpty(configuredRoot))
            {
                return configuredRoot;
            }
            return Path.GetFullPath(Path.Combine(
                Application.dataPath,
                "..",
                "..",
                "open-brush-stroke-gen-only"));
        }

        private static Stroke CreateStroke(StrokeFixture fixture)
        {
            var stroke = new Stroke
            {
                m_BrushGuid = Guid.Parse(fixture.BrushGuid),
                m_BrushScale = fixture.BrushScale * fixture.SceneScale,
                m_BrushSize = fixture.BrushSize,
                m_Color = ToColor(fixture.Color),
                m_Seed = fixture.Seed,
                m_ControlPoints = new PointerManager.ControlPoint[fixture.ControlPoints.Length],
                m_ControlPointsToDrop = new bool[fixture.ControlPoints.Length]
            };

            for (int i = 0; i < fixture.ControlPoints.Length; i++)
            {
                ControlPointFixture source = fixture.ControlPoints[i];
                stroke.m_ControlPoints[i] = new PointerManager.ControlPoint
                {
                    m_Pos = ToVector3(source.Position) * fixture.SceneScale,
                    m_Orient = ToQuaternion(source.Orientation),
                    m_Pressure = source.Pressure,
                    m_TimestampMs = (uint)Math.Max(0, source.Timestamp)
                };
                stroke.m_ControlPointsToDrop[i] = false;
            }
            return stroke;
        }

        private static BatchSubset CreateFinalizedSubset(
            CanvasScript canvas,
            Stroke stroke,
            BrushDescriptor desc)
        {
            PointerManager.ControlPoint cp0 = stroke.m_ControlPoints[0];
            TrTransform xf0 = TrTransform.TRS(cp0.m_Pos, cp0.m_Orient, stroke.m_BrushScale);
            BaseBrushScript brush = BaseBrushScript.Create(
                canvas.transform,
                xf0,
                desc,
                stroke.m_Color,
                stroke.m_BrushSize);
            try
            {
                brush.SetIsLoading();
                brush.RandomSeed = stroke.m_Seed;
                foreach (PointerManager.ControlPoint cp in stroke.m_ControlPoints)
                {
                    brush.UpdatePosition_LS(
                        TrTransform.TRS(cp.m_Pos, cp.m_Orient, stroke.m_BrushScale),
                        cp.m_Pressure);
                }
                BatchSubset subset = brush.FinalizeBatchedBrush();
                Assert.NotNull(subset, $"Brush {desc.m_DurableName} did not create a batched subset");
                return subset;
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(brush.gameObject);
            }
        }

        private static JObject CreateReferenceFixtureJson(
            string name,
            string brushName,
            string sourceStrokeFixtureRelativePath,
            BatchSubset subset)
        {
            GeometryPool geometry = subset.m_ParentBatch.Geometry;
            geometry.EnsureGeometryResident();

            return new JObject
            {
                ["schema"] = kSchema,
                ["name"] = name,
                ["brush"] = brushName,
                ["source_stroke_fixture"] = "res://" + sourceStrokeFixtureRelativePath.Replace('\\', '/'),
                ["position_tolerance"] = 0.00001f,
                ["normal_tolerance"] = 0.00001f,
                ["color_tolerance"] = 0.00001f,
                ["uv_tolerance"] = 0.00001f,
                ["tangent_tolerance"] = 0.00001f,
                ["mesh"] = new JObject
                {
                    ["layout"] = SerializeLayout(geometry),
                    ["vertices"] = SerializeVertices(geometry, subset),
                    ["triangles"] = SerializeTriangles(geometry, subset),
                    ["normals"] = SerializeNormals(geometry, subset),
                    ["colors"] = SerializeColors(geometry, subset),
                    ["tangents"] = SerializeTangents(geometry, subset),
                    ["uv0"] = SerializeTexcoord(geometry, subset, channel: 0),
                    ["uv1"] = SerializeTexcoord(geometry, subset, channel: 1),
                    ["uv2"] = SerializeTexcoord(geometry, subset, channel: 2)
                }
            };
        }

        private static JObject SerializeLayout(GeometryPool geometry)
        {
            GeometryPool.VertexLayout layout = geometry.Layout;
            return new JObject
            {
                ["use_normals"] = layout.bUseNormals,
                ["normal_semantic"] = layout.normalSemantic.ToString(),
                ["use_colors"] = layout.bUseColors,
                ["use_tangents"] = layout.bUseTangents,
                ["use_vertex_ids"] = layout.bUseVertexIds,
                ["fbx_export_normal_as_texcoord1"] = layout.bFbxExportNormalAsTexcoord1,
                ["particle_attributes"] = layout.bUseVertexIds && layout.bFbxExportNormalAsTexcoord1,
                ["uv0_size"] = layout.texcoord0.size,
                ["uv0_semantic"] = layout.texcoord0.semantic.ToString(),
                ["uv1_size"] = layout.texcoord1.size,
                ["uv1_semantic"] = layout.texcoord1.semantic.ToString(),
                ["uv2_size"] = layout.texcoord2.size,
                ["uv2_semantic"] = layout.texcoord2.semantic.ToString()
            };
        }

        private static JArray SerializeVertices(GeometryPool geometry, BatchSubset subset)
        {
            var values = new JArray();
            int end = subset.m_StartVertIndex + subset.m_VertLength;
            for (int i = subset.m_StartVertIndex; i < end; i++)
            {
                values.Add(SerializeVector3(geometry.m_Vertices[i]));
            }
            return values;
        }

        private static JArray SerializeTriangles(GeometryPool geometry, BatchSubset subset)
        {
            var values = new JArray();
            int end = subset.m_iTriIndex + subset.m_nTriIndex;
            for (int i = subset.m_iTriIndex; i < end; i++)
            {
                values.Add(geometry.m_Tris[i] - subset.m_StartVertIndex);
            }
            return values;
        }

        private static JArray SerializeNormals(GeometryPool geometry, BatchSubset subset)
        {
            var values = new JArray();
            if (!geometry.Layout.bUseNormals)
            {
                return values;
            }

            int end = subset.m_StartVertIndex + subset.m_VertLength;
            for (int i = subset.m_StartVertIndex; i < end; i++)
            {
                values.Add(SerializeVector3(geometry.m_Normals[i]));
            }
            return values;
        }

        private static JArray SerializeColors(GeometryPool geometry, BatchSubset subset)
        {
            var values = new JArray();
            if (!geometry.Layout.bUseColors)
            {
                return values;
            }

            int end = subset.m_StartVertIndex + subset.m_VertLength;
            for (int i = subset.m_StartVertIndex; i < end; i++)
            {
                Color32 color = geometry.m_Colors[i];
                values.Add(new JArray(
                    color.r / 255.0f,
                    color.g / 255.0f,
                    color.b / 255.0f,
                    color.a / 255.0f));
            }
            return values;
        }

        private static JArray SerializeTangents(GeometryPool geometry, BatchSubset subset)
        {
            var values = new JArray();
            if (!geometry.Layout.bUseTangents)
            {
                return values;
            }

            int end = subset.m_StartVertIndex + subset.m_VertLength;
            for (int i = subset.m_StartVertIndex; i < end; i++)
            {
                values.Add(SerializeVector4(geometry.m_Tangents[i]));
            }
            return values;
        }

        private static JArray SerializeTexcoord(GeometryPool geometry, BatchSubset subset, int channel)
        {
            var values = new JArray();
            int size = geometry.Layout.GetTexcoordInfo(channel).size;
            if (size == 0)
            {
                return values;
            }

            int end = subset.m_StartVertIndex + subset.m_VertLength;
            for (int i = subset.m_StartVertIndex; i < end; i++)
            {
                values.Add(SerializeTexcoordValue(geometry, channel, size, i));
            }
            return values;
        }

        private static JArray SerializeTexcoordValue(
            GeometryPool geometry,
            int channel,
            int size,
            int index)
        {
            GeometryPool.TexcoordData texcoord = GetTexcoordData(geometry, channel);
            switch (size)
            {
                case 2:
                    return SerializeVector2(texcoord.v2[index]);
                case 3:
                    return SerializeVector3(texcoord.v3[index]);
                case 4:
                    return SerializeVector4(texcoord.v4[index]);
                default:
                    throw new InvalidOperationException(
                        $"Unsupported UV{channel} size {size}");
            }
        }

        private static GeometryPool.TexcoordData GetTexcoordData(GeometryPool geometry, int channel)
        {
            switch (channel)
            {
                case 0:
                    return geometry.m_Texcoord0;
                case 1:
                    return geometry.m_Texcoord1;
                case 2:
                    return geometry.m_Texcoord2;
                default:
                    throw new InvalidOperationException($"Unsupported UV channel {channel}");
            }
        }

        private static Color ToColor(float[] values)
        {
            Assert.NotNull(values);
            Assert.GreaterOrEqual(values.Length, 4);
            return new Color(values[0], values[1], values[2], values[3]);
        }

        private static Vector3 ToVector3(float[] values)
        {
            Assert.NotNull(values);
            Assert.GreaterOrEqual(values.Length, 3);
            return new Vector3(values[0], values[1], values[2]);
        }

        private static Quaternion ToQuaternion(float[] values)
        {
            Assert.NotNull(values);
            Assert.GreaterOrEqual(values.Length, 4);
            return new Quaternion(values[0], values[1], values[2], values[3]);
        }

        private static JArray SerializeVector2(Vector2 value)
        {
            return new JArray(value.x, value.y);
        }

        private static JArray SerializeVector3(Vector3 value)
        {
            return new JArray(value.x, value.y, value.z);
        }

        private static JArray SerializeVector4(Vector4 value)
        {
            return new JArray(value.x, value.y, value.z, value.w);
        }

        private class StrokeFixture
        {
            [JsonProperty("scene_scale")]
            public float SceneScale { get; set; } = 1.0f;

            [JsonProperty("brush_guid")]
            public string BrushGuid { get; set; }

            [JsonProperty("brush_scale")]
            public float BrushScale { get; set; } = 1.0f;

            [JsonProperty("brush_size")]
            public float BrushSize { get; set; } = 1.0f;

            [JsonProperty("seed")]
            public int Seed { get; set; }

            [JsonProperty("color")]
            public float[] Color { get; set; }

            [JsonProperty("control_points")]
            public ControlPointFixture[] ControlPoints { get; set; }
        }

        private class ReferenceFixtureSpec
        {
            public ReferenceFixtureSpec(
                string name,
                string brushName,
                string sourceStrokeFixtureRelativePath)
            {
                Name = name;
                BrushName = brushName;
                SourceStrokeFixtureRelativePath = sourceStrokeFixtureRelativePath;
            }

            public string Name { get; }
            public string BrushName { get; }
            public string SourceStrokeFixtureRelativePath { get; }
        }

        private class ControlPointFixture
        {
            [JsonProperty("position")]
            public float[] Position { get; set; }

            [JsonProperty("orientation")]
            public float[] Orientation { get; set; }

            [JsonProperty("pressure")]
            public float Pressure { get; set; } = 1.0f;

            [JsonProperty("timestamp")]
            public int Timestamp { get; set; }
        }
    }
}
