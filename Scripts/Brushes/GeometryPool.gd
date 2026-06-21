class_name GeometryPool
extends RefCounted

const K_NUM_TEXCOORDS := 3

enum Semantic {
	UNSPECIFIED,
	POSITION,
	VECTOR,
	XY_IS_UV_Z_IS_DISTANCE,
	UNITLESS_VECTOR,
	XY_IS_UV,
	TIMESTAMP,
}

class TexcoordInfo:
	var size := 0
	var semantic := Semantic.UNSPECIFIED

	static func create(size_value: int = 0, semantic_value: int = Semantic.UNSPECIFIED) -> TexcoordInfo:
		var info := TexcoordInfo.new()
		info.size = size_value
		info.semantic = semantic_value
		return info

	func equals(rhs: TexcoordInfo) -> bool:
		return rhs != null and size == rhs.size and semantic == rhs.semantic

class TexcoordData:
	var v2: Array[Vector2] = []
	var v3: Array[Vector3] = []
	var v4: Array[Vector4] = []

	func set_size(size: int) -> void:
		match size:
			0:
				v2.clear()
				v3.clear()
				v4.clear()
			2:
				v3.clear()
				v4.clear()
			3:
				v2.clear()
				v4.clear()
			4:
				v2.clear()
				v3.clear()

	func clear() -> void:
		v2.clear()
		v3.clear()
		v4.clear()

class VertexLayout:
	var texcoord0 := TexcoordInfo.create(2)
	var texcoord1 := TexcoordInfo.create()
	var texcoord2 := TexcoordInfo.create()
	var bUseNormals := true
	var normalSemantic := Semantic.UNSPECIFIED
	var bUseColors := true
	var bUseTangents := true
	var bUseVertexIds := false
	var bFbxExportNormalAsTexcoord1 := false

	func get_texcoord_info(channel: int) -> TexcoordInfo:
		match channel:
			0:
				return texcoord0
			1:
				return texcoord1
			2:
				return texcoord2
			_:
				push_error("Invalid texcoord channel %d" % channel)
				return TexcoordInfo.create()

	func equals(rhs: VertexLayout) -> bool:
		return (
			rhs != null
			and texcoord0.equals(rhs.texcoord0)
			and texcoord1.equals(rhs.texcoord1)
			and texcoord2.equals(rhs.texcoord2)
			and bUseNormals == rhs.bUseNormals
			and bUseColors == rhs.bUseColors
			and bUseTangents == rhs.bUseTangents
		)

	static func default_layout() -> VertexLayout:
		return VertexLayout.new()

	static func create(
		texcoord0_value: TexcoordInfo = null,
		texcoord1_value: TexcoordInfo = null,
		texcoord2_value: TexcoordInfo = null,
		use_normals: bool = true,
		use_colors: bool = true,
		use_tangents: bool = true
	) -> VertexLayout:
		var layout := VertexLayout.new()
		if texcoord0_value != null:
			layout.texcoord0 = texcoord0_value
		if texcoord1_value != null:
			layout.texcoord1 = texcoord1_value
		if texcoord2_value != null:
			layout.texcoord2 = texcoord2_value
		layout.bUseNormals = use_normals
		layout.bUseColors = use_colors
		layout.bUseTangents = use_tangents
		return layout

static var _unused: Array[GeometryPool] = []

var m_Vertices: Array[Vector3] = []
var m_Tris: Array[int] = []
var m_Normals: Array[Vector3] = []
var m_Texcoord0 := TexcoordData.new()
var m_Texcoord1 := TexcoordData.new()
var m_Texcoord2 := TexcoordData.new()
var m_Colors: Array[Color] = []
var m_Tangents: Array[Vector4] = []
var _layout := VertexLayout.default_layout()
var is_geometry_resident := true

static func allocate() -> GeometryPool:
	if _unused.is_empty():
		return GeometryPool.new()
	return _unused.pop_back()

static func release(pool: GeometryPool) -> void:
	pool.reset(false)
	_unused.append(pool)

func _init() -> void:
	reset(false)

func set_layout(layout: VertexLayout) -> void:
	_layout = layout
	m_Texcoord0.set_size(layout.texcoord0.size)
	m_Texcoord1.set_size(layout.texcoord1.size)
	m_Texcoord2.set_size(layout.texcoord2.size)

func get_layout() -> VertexLayout:
	return _layout

func num_verts() -> int:
	return m_Vertices.size()

func set_num_verts(value: int) -> void:
	if value == num_verts():
		return
	ListUtils.set_count(m_Vertices, value, Vector3.ZERO)
	if _layout.bUseNormals:
		ListUtils.set_count(m_Normals, value, Vector3.ZERO)
	for channel in range(K_NUM_TEXCOORDS):
		var data := get_texcoord_data(channel)
		match _layout.get_texcoord_info(channel).size:
			2:
				ListUtils.set_count(data.v2, value, Vector2.ZERO)
			3:
				ListUtils.set_count(data.v3, value, Vector3.ZERO)
			4:
				ListUtils.set_count(data.v4, value, Vector4.ZERO)
	if _layout.bUseColors:
		ListUtils.set_count(m_Colors, value, Color.WHITE)
	if _layout.bUseTangents:
		ListUtils.set_count(m_Tangents, value, Vector4.ZERO)

func num_tri_indices() -> int:
	return m_Tris.size()

func set_num_tri_indices(value: int) -> void:
	assert(value % 3 == 0)
	ListUtils.set_count(m_Tris, value, 0)

func shift_forward(verts: int, tris: int) -> void:
	if verts > m_Vertices.size() or tris > m_Tris.size():
		push_error("ShiftForward range out of bounds")
		return
	m_Vertices = m_Vertices.slice(verts)
	if _layout.bUseNormals:
		m_Normals = m_Normals.slice(verts)
	if _layout.bUseColors:
		m_Colors = m_Colors.slice(verts)
	if _layout.bUseTangents:
		m_Tangents = m_Tangents.slice(verts)
	for channel in range(K_NUM_TEXCOORDS):
		var data := get_texcoord_data(channel)
		match _layout.get_texcoord_info(channel).size:
			2:
				data.v2 = data.v2.slice(verts)
			3:
				data.v3 = data.v3.slice(verts)
			4:
				data.v4 = data.v4.slice(verts)
	m_Tris = m_Tris.slice(tris * 3)
	for index in range(m_Tris.size()):
		m_Tris[index] -= verts

func clone() -> GeometryPool:
	var clone_pool := GeometryPool.new()
	clone_pool.set_layout(_layout)
	clone_pool.append_pool(self, 0, num_verts(), 0, num_tri_indices())
	return clone_pool

func reset(keep_vertex_layout: bool = true) -> void:
	m_Vertices.clear()
	m_Tris.clear()
	m_Normals.clear()
	m_Texcoord0.clear()
	m_Texcoord1.clear()
	m_Texcoord2.clear()
	m_Colors.clear()
	m_Tangents.clear()
	is_geometry_resident = true
	if not keep_vertex_layout:
		set_layout(VertexLayout.default_layout())

func get_texcoord_data(channel: int) -> TexcoordData:
	match channel:
		0:
			return m_Texcoord0
		1:
			return m_Texcoord1
		2:
			return m_Texcoord2
		_:
			push_error("Invalid texcoord channel %d" % channel)
			return m_Texcoord0

func copy_to_mesh_data(mesh: MeshData, i_vert: int = 0, n_vert: int = -1, i_tri_index: int = 0, n_tri_index: int = -1) -> void:
	if n_vert < 0:
		n_vert = m_Vertices.size()
	if n_tri_index < 0:
		n_tri_index = m_Tris.size()
	mesh.clear()
	mesh.vertices.assign(m_Vertices.slice(i_vert, i_vert + n_vert))
	for tri in m_Tris.slice(i_tri_index, i_tri_index + n_tri_index):
		mesh.triangles.append(tri - i_vert)
	if _layout.bUseNormals:
		mesh.normals.assign(m_Normals.slice(i_vert, i_vert + n_vert))
	for channel in range(K_NUM_TEXCOORDS):
		var info := _layout.get_texcoord_info(channel)
		var data := get_texcoord_data(channel)
		match info.size:
			2:
				mesh.set_uvs(channel, 2, data.v2.slice(i_vert, i_vert + n_vert))
			3:
				mesh.set_uvs(channel, 3, data.v3.slice(i_vert, i_vert + n_vert))
			4:
				mesh.set_uvs(channel, 4, data.v4.slice(i_vert, i_vert + n_vert))
	if _layout.bUseColors:
		mesh.colors.assign(m_Colors.slice(i_vert, i_vert + n_vert))
	if _layout.bUseTangents:
		mesh.tangents.assign(m_Tangents.slice(i_vert, i_vert + n_vert))

func append_mesh_data(mesh: MeshData) -> void:
	var index_offset := m_Vertices.size()
	append_vertex_data(mesh)
	for tri in mesh.triangles:
		m_Tris.append(index_offset + tri)
	verify_sizes()

func append_vertex_data(mesh: MeshData) -> void:
	var mesh_vertex_count := mesh.vertex_count()
	m_Vertices.append_array(mesh.vertices)
	if _layout.bUseNormals:
		if mesh.normals.size() != mesh_vertex_count:
			push_error("Missing normal")
			return
		m_Normals.append_array(mesh.normals)
	for channel in range(K_NUM_TEXCOORDS):
		var info := _layout.get_texcoord_info(channel)
		var dst := get_texcoord_data(channel)
		match info.size:
			2:
				_copy_texcoord_required(dst.v2, mesh.get_uvs(channel, 2), mesh_vertex_count, channel)
			3:
				_copy_texcoord_required(dst.v3, mesh.get_uvs(channel, 3), mesh_vertex_count, channel)
			4:
				_copy_texcoord_required(dst.v4, mesh.get_uvs(channel, 4), mesh_vertex_count, channel)
	if _layout.bUseColors:
		if mesh.colors.size() != mesh_vertex_count:
			push_error("Missing color")
			return
		else:
			m_Colors.append_array(mesh.colors)
	if _layout.bUseTangents:
		if mesh.tangents.size() != mesh_vertex_count:
			push_error("Missing tangent")
			return
		m_Tangents.append_array(mesh.tangents)
	verify_sizes()

func append_pool(rhs: GeometryPool, i_vert: int, n_vert: int, i_tri_index: int, n_tri_index: int, left_transform: TrTransform = null) -> void:
	if not _layout.equals(rhs.get_layout()):
		push_error("rhs: must have same layout")
		return
	var i_vert_dest := m_Vertices.size()
	var index_offset := i_vert_dest - i_vert
	m_Vertices.append_array(rhs.m_Vertices.slice(i_vert, i_vert + n_vert))
	if _layout.bUseNormals:
		m_Normals.append_array(rhs.m_Normals.slice(i_vert, i_vert + n_vert))
	for channel in range(K_NUM_TEXCOORDS):
		var data := get_texcoord_data(channel)
		var rhs_data := rhs.get_texcoord_data(channel)
		match _layout.get_texcoord_info(channel).size:
			2:
				data.v2.append_array(rhs_data.v2.slice(i_vert, i_vert + n_vert))
			3:
				data.v3.append_array(rhs_data.v3.slice(i_vert, i_vert + n_vert))
			4:
				data.v4.append_array(rhs_data.v4.slice(i_vert, i_vert + n_vert))
	if _layout.bUseColors:
		m_Colors.append_array(rhs.m_Colors.slice(i_vert, i_vert + n_vert))
	if _layout.bUseTangents:
		m_Tangents.append_array(rhs.m_Tangents.slice(i_vert, i_vert + n_vert))
	if left_transform != null:
		apply_transform(left_transform, i_vert_dest, n_vert)
	for tri in rhs.m_Tris.slice(i_tri_index, i_tri_index + n_tri_index):
		m_Tris.append(index_offset + tri)
	verify_sizes()

func apply_transform(left_transform: TrTransform, i_vert: int, n_vert: int) -> void:
	var i_vert_end := i_vert + n_vert
	_apply_transform_to_vector3(left_transform, left_transform.scale, i_vert, i_vert_end, m_Vertices, Semantic.POSITION)
	if _layout.bUseNormals:
		if _layout.normalSemantic == Semantic.UNSPECIFIED:
			var rotation_only := TrTransform.r(left_transform.rotation)
			_apply_transform_to_vector3(rotation_only, 1.0, i_vert, i_vert_end, m_Normals, Semantic.VECTOR)
		else:
			_apply_transform_to_vector3(left_transform, left_transform.scale, i_vert, i_vert_end, m_Normals, _layout.normalSemantic)
	for channel in range(K_NUM_TEXCOORDS):
		var data := get_texcoord_data(channel)
		var info := _layout.get_texcoord_info(channel)
		if info.size == 3:
			_apply_transform_to_vector3(left_transform, left_transform.scale, i_vert, i_vert_end, data.v3, info.semantic)
		elif info.size == 4:
			_apply_transform_to_vector4(left_transform, left_transform.scale, i_vert, i_vert_end, data.v4, info.semantic)
	if _layout.bUseTangents:
		var rotation_only := TrTransform.r(left_transform.rotation)
		_apply_transform_to_vector4(rotation_only, 1.0, i_vert, i_vert_end, m_Tangents, Semantic.VECTOR)

func verify_sizes() -> bool:
	var ok := true
	var n_vert := m_Vertices.size()
	if _layout.bUseNormals:
		ok = ok and m_Normals.size() == n_vert
	for channel in range(K_NUM_TEXCOORDS):
		var data := get_texcoord_data(channel)
		match _layout.get_texcoord_info(channel).size:
			2:
				ok = ok and data.v2.size() == n_vert
			3:
				ok = ok and data.v3.size() == n_vert
			4:
				ok = ok and data.v4.size() == n_vert
	if _layout.bUseColors:
		ok = ok and m_Colors.size() == n_vert
	if _layout.bUseTangents:
		ok = ok and m_Tangents.size() == n_vert
	if not ok:
		push_error("Arrays not correctly sized")
	return ok

static func _copy_texcoord_required(dst: Array, src: Array, count: int, channel: int) -> void:
	if src.size() == count:
		dst.append_array(src)
	else:
		push_error("Missing texcoord%d data" % channel)

static func _apply_transform_to_vector3(xf: TrTransform, scale_value: float, i_vert: int, i_vert_end: int, values: Array[Vector3], semantic: int) -> void:
	match semantic:
		Semantic.POSITION:
			for index in range(i_vert, i_vert_end):
				values[index] = xf.multiply_point(values[index])
		Semantic.VECTOR:
			for index in range(i_vert, i_vert_end):
				values[index] = xf.multiply_vector(values[index])
		Semantic.XY_IS_UV_Z_IS_DISTANCE:
			for index in range(i_vert, i_vert_end):
				values[index] = Vector3(values[index].x, values[index].y, scale_value * values[index].z)
		Semantic.TIMESTAMP:
			pass
		_:
			push_error("Cannot transform Vector3 as %s" % semantic)

static func _apply_transform_to_vector4(xf: TrTransform, scale_value: float, i_vert: int, i_vert_end: int, values: Array[Vector4], semantic: int) -> void:
	match semantic:
		Semantic.POSITION:
			for index in range(i_vert, i_vert_end):
				var p := xf.multiply_point(Vector3(values[index].x, values[index].y, values[index].z))
				values[index] = Vector4(p.x, p.y, p.z, values[index].w)
		Semantic.VECTOR:
			for index in range(i_vert, i_vert_end):
				var v := xf.multiply_vector(Vector3(values[index].x, values[index].y, values[index].z))
				values[index] = Vector4(v.x, v.y, v.z, values[index].w)
		Semantic.XY_IS_UV_Z_IS_DISTANCE:
			for index in range(i_vert, i_vert_end):
				values[index] = Vector4(values[index].x, values[index].y, scale_value * values[index].z, values[index].w)
		Semantic.TIMESTAMP:
			pass
