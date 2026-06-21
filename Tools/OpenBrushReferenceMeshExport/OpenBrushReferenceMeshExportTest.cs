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
        private const string kCafeInkStrokeFixture = "Resources/Fixtures/cafe_ink_stroke_150.json";

        [Test]
        [Explicit("Writes Open Brush reference mesh fixtures into the Godot parity repo.")]
        [Category("OpenBrushReferenceExport")]
        public void ExportCafeInkStroke150()
        {
            ExportReferenceFixture(
                name: "cafe_ink_stroke_150",
                brushName: "Ink",
                sourceStrokeFixtureRelativePath: kCafeInkStrokeFixture);
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
                ["uv_tolerance"] = 0.00001f,
                ["mesh"] = new JObject
                {
                    ["vertices"] = SerializeVertices(geometry, subset),
                    ["triangles"] = SerializeTriangles(geometry, subset),
                    ["uv0"] = SerializeUv0(geometry, subset)
                }
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

        private static JArray SerializeUv0(GeometryPool geometry, BatchSubset subset)
        {
            var values = new JArray();
            if (geometry.Layout.texcoord0.size == 0)
            {
                return values;
            }

            int end = subset.m_StartVertIndex + subset.m_VertLength;
            for (int i = subset.m_StartVertIndex; i < end; i++)
            {
                values.Add(SerializeVector2(GetUv0Xy(geometry, i)));
            }
            return values;
        }

        private static Vector2 GetUv0Xy(GeometryPool geometry, int index)
        {
            switch (geometry.Layout.texcoord0.size)
            {
                case 2:
                    return geometry.m_Texcoord0.v2[index];
                case 3:
                    Vector3 uvw = geometry.m_Texcoord0.v3[index];
                    return new Vector2(uvw.x, uvw.y);
                case 4:
                    Vector4 uv4 = geometry.m_Texcoord0.v4[index];
                    return new Vector2(uv4.x, uv4.y);
                default:
                    throw new InvalidOperationException(
                        $"Unsupported UV0 size {geometry.Layout.texcoord0.size}");
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
