class_name MasterBrush
extends RefCounted

const K_ACTIVE_STROKE_QUADS := 1000

static var shared_pool := Pool.create(func(): return MasterBrush.new())

var m_NumVerts := 0
var m_Vertices: Array[Vector3] = []
var m_Tris: Array[int] = []
var m_Normals: Array[Vector3] = []
var m_UVs: Array[Vector2] = []
var m_UVWs: Array[Vector3] = []
var m_Colors: Array[Color] = []
var m_Tangents: Array[Vector4] = []
var vertex_layout: GeometryPool.VertexLayout

func _init() -> void:
	var num_quads := K_ACTIVE_STROKE_QUADS
	m_NumVerts = num_quads * 6
	ListUtils.set_count(m_Vertices, m_NumVerts, Vector3.ZERO)
	ListUtils.set_count(m_Tris, m_NumVerts, 0)
	ListUtils.set_count(m_Normals, m_NumVerts, Vector3.UP)
	ListUtils.set_count(m_UVs, m_NumVerts, Vector2.ZERO)
	ListUtils.set_count(m_UVWs, m_NumVerts, Vector3.ZERO)
	ListUtils.set_count(m_Colors, m_NumVerts, Color.WHITE)
	ListUtils.set_count(m_Tangents, m_NumVerts, Vector4.ZERO)
	for quad_index in range(num_quads):
		var base := quad_index * 6
		m_UVs[base] = Vector2(0.0, 0.0)
		m_UVs[base + 1] = Vector2(1.0, 0.0)
		m_UVs[base + 2] = Vector2(0.0, 1.0)
		m_UVs[base + 3] = Vector2(0.0, 1.0)
		m_UVs[base + 4] = Vector2(1.0, 0.0)
		m_UVs[base + 5] = Vector2(1.0, 1.0)
		for offset in range(6):
			var index := base + offset
			m_UVWs[index] = Vector3(m_UVs[index].x, m_UVs[index].y, 0.0)
			m_Tris[index] = index

func num_verts() -> int:
	return m_NumVerts

func reset(num_verts_to_clear: int = -1) -> void:
	var clear_count: int = m_NumVerts if num_verts_to_clear < 0 else min(num_verts_to_clear, m_NumVerts)
	for index in range(clear_count):
		m_Vertices[index] = Vector3.ZERO
	vertex_layout = null

func on_pool_put() -> void:
	pass

func on_pool_get() -> void:
	reset()

func set_vertex_layout(layout: GeometryPool.VertexLayout) -> void:
	if layout != null:
		if layout.texcoord0.size == 2 and layout.texcoord0.semantic != GeometryPool.Semantic.XY_IS_UV:
			push_error("Bad uv0 semantic for size 2")
		elif layout.texcoord0.size == 3 and layout.texcoord0.semantic != GeometryPool.Semantic.XY_IS_UV_Z_IS_DISTANCE:
			push_error("Bad uv0 semantic for size 3")
		elif layout.texcoord0.size != 2 and layout.texcoord0.size != 3:
			push_error("Bad uv0 size")
		if layout.texcoord1.size != 0:
			push_error("MasterBrush only supports texcoord1 size 0")
	vertex_layout = layout
