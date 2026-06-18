class_name MeshData
extends RefCounted

var vertices: Array[Vector3] = []
var triangles: Array[int] = []
var normals: Array[Vector3] = []
var uv0_v2: Array[Vector2] = []
var uv0_v3: Array[Vector3] = []
var uv0_v4: Array[Vector4] = []
var uv1_v2: Array[Vector2] = []
var uv1_v3: Array[Vector3] = []
var uv1_v4: Array[Vector4] = []
var uv2_v2: Array[Vector2] = []
var uv2_v3: Array[Vector3] = []
var uv2_v4: Array[Vector4] = []
var colors: Array[Color] = []
var tangents: Array[Vector4] = []

func clear() -> void:
	vertices.clear()
	triangles.clear()
	normals.clear()
	uv0_v2.clear()
	uv0_v3.clear()
	uv0_v4.clear()
	uv1_v2.clear()
	uv1_v3.clear()
	uv1_v4.clear()
	uv2_v2.clear()
	uv2_v3.clear()
	uv2_v4.clear()
	colors.clear()
	tangents.clear()

func vertex_count() -> int:
	return vertices.size()

func get_uvs(channel: int, size: int) -> Array:
	match channel:
		0:
			return _uv_by_size(uv0_v2, uv0_v3, uv0_v4, size)
		1:
			return _uv_by_size(uv1_v2, uv1_v3, uv1_v4, size)
		2:
			return _uv_by_size(uv2_v2, uv2_v3, uv2_v4, size)
		_:
			push_error("Invalid UV channel %d" % channel)
			return []

func set_uvs(channel: int, size: int, values: Array) -> void:
	match channel:
		0:
			_set_uv_by_size("uv0", size, values)
		1:
			_set_uv_by_size("uv1", size, values)
		2:
			_set_uv_by_size("uv2", size, values)
		_:
			push_error("Invalid UV channel %d" % channel)

func to_array_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(triangles)
	if normals.size() == vertices.size():
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	if uv0_v2.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uv0_v2)
	elif uv0_v3.size() == vertices.size():
		var uv2d: Array[Vector2] = []
		for uv in uv0_v3:
			uv2d.append(Vector2(uv.x, uv.y))
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uv2d)
	if colors.size() == vertices.size():
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(colors)
	if tangents.size() == vertices.size():
		var packed_tangents := PackedFloat32Array()
		for tangent in tangents:
			packed_tangents.append(tangent.x)
			packed_tangents.append(tangent.y)
			packed_tangents.append(tangent.z)
			packed_tangents.append(tangent.w)
		arrays[Mesh.ARRAY_TANGENT] = packed_tangents

	var mesh := ArrayMesh.new()
	if not vertices.is_empty() and not triangles.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _uv_by_size(v2: Array[Vector2], v3: Array[Vector3], v4: Array[Vector4], size: int) -> Array:
	match size:
		2:
			return v2
		3:
			return v3
		4:
			return v4
		_:
			return []

func _set_uv_by_size(channel_name: String, size: int, values: Array) -> void:
	var duplicate_values := values.duplicate()
	match [channel_name, size]:
		["uv0", 2]:
			uv0_v2.assign(duplicate_values)
		["uv0", 3]:
			uv0_v3.assign(duplicate_values)
		["uv0", 4]:
			uv0_v4.assign(duplicate_values)
		["uv1", 2]:
			uv1_v2.assign(duplicate_values)
		["uv1", 3]:
			uv1_v3.assign(duplicate_values)
		["uv1", 4]:
			uv1_v4.assign(duplicate_values)
		["uv2", 2]:
			uv2_v2.assign(duplicate_values)
		["uv2", 3]:
			uv2_v3.assign(duplicate_values)
		["uv2", 4]:
			uv2_v4.assign(duplicate_values)
