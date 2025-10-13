// Unity-to-Godot compatibility layer for mesh and rendering
using Godot;
using System;
using System.Collections.Generic;

namespace UnityEngine
{
    // Mesh wrapper
    public class Mesh : IDisposable
    {
        private ArrayMesh _godotMesh;
        private List<Vector3> _vertices = new List<Vector3>();
        private List<int> _triangles = new List<int>();
        private List<Vector3> _normals = new List<Vector3>();
        private List<Vector2> _uv = new List<Vector2>();
        private List<Vector4> _tangents = new List<Vector4>();
        private List<Color32> _colors = new List<Color32>();
        private Aabb _bounds;
        private bool _needsCommit = false;
        private MeshInstance3D _meshInstance; // Keep reference to auto-update on commit

        public Mesh()
        {
            _godotMesh = new ArrayMesh();
        }

        internal ArrayMesh GodotMesh => _godotMesh;

        internal void SetMeshInstance(MeshInstance3D meshInstance)
        {
            _meshInstance = meshInstance;
            // Assign the mesh immediately if we have surfaces
            if (_meshInstance != null && _godotMesh.GetSurfaceCount() > 0)
            {
                _meshInstance.Mesh = _godotMesh;
            }
        }

        public Vector3[] vertices
        {
            get => _vertices.ToArray();
            set
            {
                _vertices.Clear();
                if (value != null) _vertices.AddRange(value);
                _needsCommit = true;
            }
        }

        public int[] triangles
        {
            get => _triangles.ToArray();
            set
            {
                _triangles.Clear();
                if (value != null) _triangles.AddRange(value);
                _needsCommit = true;
            }
        }

        public Vector3[] normals
        {
            get => _normals.ToArray();
            set
            {
                _normals.Clear();
                if (value != null) _normals.AddRange(value);
            }
        }

        public Vector2[] uv
        {
            get => _uv.ToArray();
            set
            {
                _uv.Clear();
                if (value != null) _uv.AddRange(value);
            }
        }

        public Vector4[] tangents
        {
            get => _tangents.ToArray();
            set
            {
                _tangents.Clear();
                if (value != null) _tangents.AddRange(value);
            }
        }

        public Color32[] colors32
        {
            get => _colors.ToArray();
            set
            {
                _colors.Clear();
                if (value != null) _colors.AddRange(value);
            }
        }

        public void MarkDynamic()
        {
            // In Godot, meshes can be modified at runtime by default
        }

        public void Clear(bool keepVertexLayout = true)
        {
            _vertices.Clear();
            _triangles.Clear();
            _normals.Clear();
            _uv.Clear();
            _tangents.Clear();
            _colors.Clear();
            _godotMesh.ClearSurfaces();
            _needsCommit = false;
        }

        // Unity's Set methods - automatically commit to Godot mesh
        public void SetVertices(List<Vector3> inVertices)
        {
            _vertices = new List<Vector3>(inVertices);
            _needsCommit = true;
        }
        public void SetTriangles(List<int> inTriangles, int submesh = 0)
        {
            _triangles = new List<int>(inTriangles);
            _needsCommit = true;
        }
        public void SetNormals(List<Vector3> inNormals)
        {
            _normals = new List<Vector3>(inNormals);
            _needsCommit = true;
        }
        public void SetColors(List<Color32> inColors)
        {
            _colors = new List<Color32>(inColors);
            _needsCommit = true;
        }
        public void SetTangents(List<Vector4> inTangents)
        {
            _tangents = new List<Vector4>(inTangents);
            _needsCommit = true;
        }
        public void SetUVs(int channel, List<Vector2> uvs)
        {
            if (channel == 0)
            {
                _uv = new List<Vector2>(uvs);
                _needsCommit = true;
            }
            // Other UV channels could be added if needed
        }
        public void SetUVs(int channel, List<Vector3> uvs)
        {
            if (channel == 0)
            {
                _uv.Clear();
                foreach (var uv in uvs) _uv.Add(new Vector2(uv.x, uv.y));
                _needsCommit = true;
            }
        }
        public void SetUVs(int channel, List<Vector4> uvs)
        {
            if (channel == 0)
            {
                _uv.Clear();
                foreach (var uv in uvs) _uv.Add(new Vector2(uv.x, uv.y));
                _needsCommit = true;
            }
        }

        // Unity's Get methods
        public int[] GetTriangles(int submesh = 0) => _triangles.ToArray();
        public int[] GetTriangles(int submesh, bool applyBaseVertex) => _triangles.ToArray();
        public void GetTriangles(List<int> triangles, int submesh = 0)
        {
            triangles.Clear();
            triangles.AddRange(_triangles);
        }
        public void GetUVs(int channel, List<Vector2> uvs)
        {
            uvs.Clear();
            if (channel == 0) uvs.AddRange(_uv);
        }
        public void GetUVs(int channel, List<Vector3> uvs)
        {
            uvs.Clear();
            if (channel == 0)
            {
                foreach (var uv in _uv) uvs.Add(new Vector3(uv.x, uv.y, 0));
            }
        }
        public void GetUVs(int channel, List<Vector4> uvs)
        {
            uvs.Clear();
            if (channel == 0)
            {
                foreach (var uv in _uv) uvs.Add(new Vector4(uv.x, uv.y, 0, 0));
            }
        }

        // Unity mesh properties
        public int vertexCount => _vertices.Count;
        public int subMeshCount => _godotMesh.GetSurfaceCount();

        public int GetIndexCount(int submesh) => _triangles.Count;

        public void RecalculateBounds()
        {
            if (_vertices.Count == 0) return;

            Vector3 min = _vertices[0];
            Vector3 max = _vertices[0];

            foreach (var v in _vertices)
            {
                min.x = Mathf.Min(min.x, v.x);
                min.y = Mathf.Min(min.y, v.y);
                min.z = Mathf.Min(min.z, v.z);
                max.x = Mathf.Max(max.x, v.x);
                max.y = Mathf.Max(max.y, v.y);
                max.z = Mathf.Max(max.z, v.z);
            }

            _bounds = new Aabb(min, max - min);

            // RecalculateBounds is typically called after all mesh data is set,
            // so commit the mesh data to Godot now
            if (_needsCommit)
            {
                CommitToGodotMesh();
                _needsCommit = false;
            }
        }

        public void RecalculateNormals()
        {
            _normals.Clear();
            _normals.AddRange(new Vector3[_vertices.Count]);

            for (int i = 0; i < _triangles.Count; i += 3)
            {
                int i0 = _triangles[i];
                int i1 = _triangles[i + 1];
                int i2 = _triangles[i + 2];

                Vector3 v0 = _vertices[i0];
                Vector3 v1 = _vertices[i1];
                Vector3 v2 = _vertices[i2];

                Vector3 normal = Vector3.Cross(v1 - v0, v2 - v0).normalized;

                _normals[i0] += normal;
                _normals[i1] += normal;
                _normals[i2] += normal;
            }

            for (int i = 0; i < _normals.Count; i++)
            {
                _normals[i] = _normals[i].normalized;
            }
        }

        public void UploadMeshData(bool markNoLongerReadable)
        {
            CommitToGodotMesh();
        }

        /// <summary>
        /// Uploads the collected mesh data to the Godot ArrayMesh.
        /// This must be called after setting vertices/triangles/normals/etc.
        /// </summary>
        private void CommitToGodotMesh()
        {

            if (_vertices.Count == 0 || _triangles.Count == 0)
            {
                    return;
            }

            // Clear existing surfaces
            _godotMesh.ClearSurfaces();

            // Build Godot surface arrays
            var arrays = new Godot.Collections.Array();
            arrays.Resize((int)Godot.Mesh.ArrayType.Max);

            // Required: Vertices
            var godotVertices = new Godot.Vector3[_vertices.Count];
            for (int i = 0; i < _vertices.Count; i++)
            {
                godotVertices[i] = _vertices[i];
            }
            arrays[(int)Godot.Mesh.ArrayType.Vertex] = godotVertices;

            // Required: Indices (triangles)
            arrays[(int)Godot.Mesh.ArrayType.Index] = _triangles.ToArray();

            // Optional: Normals
            if (_normals.Count == _vertices.Count)
            {
                var godotNormals = new Godot.Vector3[_normals.Count];
                for (int i = 0; i < _normals.Count; i++)
                {
                    godotNormals[i] = _normals[i];
                }
                arrays[(int)Godot.Mesh.ArrayType.Normal] = godotNormals;
            }

            // Optional: UVs (Texcoord0)
            if (_uv.Count == _vertices.Count)
            {
                var godotUVs = new Godot.Vector2[_uv.Count];
                for (int i = 0; i < _uv.Count; i++)
                {
                    godotUVs[i] = _uv[i];
                }
                arrays[(int)Godot.Mesh.ArrayType.TexUV] = godotUVs;
            }

            // Optional: Tangents
            if (_tangents.Count == _vertices.Count)
            {
                // Godot tangents are float[] with 4 floats per vertex (x,y,z,d)
                var godotTangents = new float[_tangents.Count * 4];
                for (int i = 0; i < _tangents.Count; i++)
                {
                    godotTangents[i * 4 + 0] = _tangents[i].x;
                    godotTangents[i * 4 + 1] = _tangents[i].y;
                    godotTangents[i * 4 + 2] = _tangents[i].z;
                    godotTangents[i * 4 + 3] = _tangents[i].w;
                }
                arrays[(int)Godot.Mesh.ArrayType.Tangent] = godotTangents;
            }

            // Optional: Colors
            if (_colors.Count == _vertices.Count)
            {
                var godotColors = new Godot.Color[_colors.Count];
                for (int i = 0; i < _colors.Count; i++)
                {
                    var c = _colors[i];
                    godotColors[i] = new Godot.Color(c.r / 255f, c.g / 255f, c.b / 255f, c.a / 255f);
                }
                arrays[(int)Godot.Mesh.ArrayType.Color] = godotColors;
            }

            // Add the surface to the mesh
            _godotMesh.AddSurfaceFromArrays(Godot.Mesh.PrimitiveType.Triangles, arrays);

            // CRITICAL: Assign the mesh to MeshInstance3D so it actually renders!
            if (_meshInstance != null)
            {
                _meshInstance.Mesh = _godotMesh;
            }

        }

        public void Dispose()
        {
            _godotMesh?.Dispose();
            _vertices.Clear();
            _triangles.Clear();
            _normals.Clear();
            _uv.Clear();
            _tangents.Clear();
            _colors.Clear();
        }
    }

    // MeshFilter component wrapper
    public class MeshFilter
    {
        private Mesh _mesh;
        private MeshInstance3D _meshInstance;

        internal MeshFilter(MeshInstance3D meshInstance)
        {
            _meshInstance = meshInstance;
        }

        public Mesh mesh
        {
            get
            {
                // Auto-create mesh if null (Unity behavior)
                if (_mesh == null)
                {
                    _mesh = new Mesh();
                    // Link the mesh to the MeshInstance3D so it can auto-update
                    if (_meshInstance != null)
                    {
                        _mesh.SetMeshInstance(_meshInstance);
                    }
                }
                return _mesh;
            }
            set
            {
                _mesh = value;
                if (_meshInstance != null && _mesh != null)
                {
                    _mesh.SetMeshInstance(_meshInstance);
                    _meshInstance.Mesh = _mesh.GodotMesh;
                }
            }
        }

        public Mesh sharedMesh
        {
            get => mesh;
            set => mesh = value;
        }
    }

    // Renderer component wrapper
    public class Renderer
    {
        private MeshInstance3D _meshInstance;
        private Material _material;

        internal Renderer(MeshInstance3D meshInstance)
        {
            _meshInstance = meshInstance;
        }

        public Material material
        {
            get => _material;
            set
            {
                _material = value;
                if (_meshInstance != null && _material != null)
                {
                    _meshInstance.MaterialOverride = _material.GodotMaterial;
                }
            }
        }

        public Material sharedMaterial
        {
            get => material;
            set => material = value;
        }

        public bool enabled
        {
            get => _meshInstance?.Visible ?? false;
            set { if (_meshInstance != null) _meshInstance.Visible = value; }
        }
    }

    // Material wrapper
    public class Material
    {
        private Godot.Material _godotMaterial;

        public Material()
        {
            _godotMaterial = new StandardMaterial3D();
        }

        internal Material(Godot.Material godotMaterial)
        {
            _godotMaterial = godotMaterial;
        }

        internal Godot.Material GodotMaterial => _godotMaterial;

        public void SetColor(string name, Color value)
        {
            if (_godotMaterial is StandardMaterial3D standardMat)
            {
                if (name == "_Color" || name == "albedo")
                {
                    standardMat.AlbedoColor = value;
                }
            }
        }

        public void SetFloat(string name, float value)
        {
            // Stub - implement as needed
        }

        public void SetVector(string name, Vector4 value)
        {
            // Stub - implement as needed
        }

        public void SetTexture(string name, Texture texture)
        {
            // Stub - implement as needed
        }
    }

    // Texture stub
    public class Texture
    {
        // Stub - implement as needed
    }

    // Texture2D stub
    public class Texture2D : Texture
    {
        // Stub - implement as needed
    }

    // MeshRenderer - combines MeshFilter and Renderer functionality
    public class MeshRenderer : Renderer
    {
        internal MeshRenderer(MeshInstance3D meshInstance) : base(meshInstance)
        {
        }
    }

    // Shader stub
    public class Shader
    {
        public static Shader Find(string name)
        {
            // Stub - return a default shader
            return new Shader();
        }

        public static void SetGlobalTexture(string name, Texture texture)
        {
            // Stub - global shader parameters
        }

        public static void SetGlobalFloat(string name, float value)
        {
            // Stub - global shader parameters
        }
    }

    // Bounds struct for Unity compatibility
    public struct Bounds
    {
        private Aabb _aabb;

        public Bounds(Vector3 center, Vector3 size)
        {
            var halfSize = new Vector3(size.x * 0.5f, size.y * 0.5f, size.z * 0.5f);
            _aabb = new Aabb((Godot.Vector3)(center) - (Godot.Vector3)halfSize, size);
        }

        public Vector3 center
        {
            get => _aabb.GetCenter();
            set
            {
                var halfSize = new Vector3(_aabb.Size.X * 0.5f, _aabb.Size.Y * 0.5f, _aabb.Size.Z * 0.5f);
                _aabb = new Aabb((Godot.Vector3)value - (Godot.Vector3)halfSize, _aabb.Size);
            }
        }

        public Vector3 size
        {
            get => _aabb.Size;
            set => _aabb.Size = value;
        }

        public Vector3 min
        {
            get => _aabb.Position;
            set => _aabb.Position = value;
        }

        public Vector3 max
        {
            get => _aabb.End;
            set => _aabb.End = value;
        }

        public void Encapsulate(Vector3 point)
        {
            _aabb = _aabb.Expand(point);
        }

        public void Encapsulate(Bounds bounds)
        {
            _aabb = _aabb.Merge(bounds._aabb);
        }

        public static implicit operator Bounds(Aabb aabb) => new Bounds { _aabb = aabb };
        public static implicit operator Aabb(Bounds bounds) => bounds._aabb;
    }
}
