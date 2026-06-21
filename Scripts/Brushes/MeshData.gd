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
var use_particle_attributes := false
var bounds_padding_ls := 0.0

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
	use_particle_attributes = false
	bounds_padding_ls = 0.0

func vertex_count() -> int:
	return vertices.size()

func is_empty() -> bool:
	return vertices.is_empty() or triangles.is_empty()

func copy_from(source: MeshData) -> void:
	clear()
	use_particle_attributes = source.use_particle_attributes
	bounds_padding_ls = source.bounds_padding_ls
	append_mesh_data(source)

func append_mesh_data(source: MeshData) -> void:
	if source == null:
		return
	if vertices.is_empty():
		use_particle_attributes = source.use_particle_attributes
	bounds_padding_ls = maxf(bounds_padding_ls, source.bounds_padding_ls)
	var vertex_offset := vertices.size()
	vertices.append_array(source.vertices)
	for tri in source.triangles:
		triangles.append(vertex_offset + tri)
	normals.append_array(source.normals)
	uv0_v2.append_array(source.uv0_v2)
	uv0_v3.append_array(source.uv0_v3)
	uv0_v4.append_array(source.uv0_v4)
	uv1_v2.append_array(source.uv1_v2)
	uv1_v3.append_array(source.uv1_v3)
	uv1_v4.append_array(source.uv1_v4)
	uv2_v2.append_array(source.uv2_v2)
	uv2_v3.append_array(source.uv2_v3)
	uv2_v4.append_array(source.uv2_v4)
	colors.append_array(source.colors)
	tangents.append_array(source.tangents)

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
	var mesh := ArrayMesh.new()
	var arrays := to_mesh_arrays()
	if not vertices.is_empty() and not triangles.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, surface_format_flags(arrays))
	return mesh

func to_mesh_arrays() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	if vertices.is_empty() or triangles.is_empty():
		return arrays

	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(triangles)
	if normals.size() == vertices.size() and not use_particle_attributes:
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	if use_particle_attributes:
		_add_particle_arrays(arrays)
	else:
		_add_uv0_arrays(arrays)
		_add_uv1_arrays(arrays)
		_add_uv2_arrays(arrays)
	if colors.size() == vertices.size():
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(colors)
	if tangents.size() == vertices.size() and not use_particle_attributes:
		arrays[Mesh.ARRAY_TANGENT] = _pack_tangents(tangents)
	return arrays

static func surface_format_flags(arrays: Array) -> int:
	var format_flags := 0
	if arrays[Mesh.ARRAY_CUSTOM0] != null:
		format_flags |= (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	if arrays[Mesh.ARRAY_CUSTOM1] != null:
		format_flags |= (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	if arrays[Mesh.ARRAY_CUSTOM2] != null:
		format_flags |= (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	if arrays[Mesh.ARRAY_CUSTOM3] != null:
		format_flags |= (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
	return format_flags

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

func _add_uv0_arrays(arrays: Array) -> void:
	if uv0_v2.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uv0_v2)
	elif uv0_v3.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = _pack_vec3_xy(uv0_v3)
		arrays[Mesh.ARRAY_CUSTOM0] = _pack_vec3_custom(uv0_v3)
	elif uv0_v4.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = _pack_vec4_xy(uv0_v4)
		arrays[Mesh.ARRAY_CUSTOM0] = _pack_vec4_custom(uv0_v4)

func _add_uv1_arrays(arrays: Array) -> void:
	if uv1_v2.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(uv1_v2)
	elif uv1_v3.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV2] = _pack_vec3_xy(uv1_v3)
		arrays[Mesh.ARRAY_CUSTOM1] = _pack_vec3_custom(uv1_v3)
	elif uv1_v4.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV2] = _pack_vec4_xy(uv1_v4)
		arrays[Mesh.ARRAY_CUSTOM1] = _pack_vec4_custom(uv1_v4)

func _add_uv2_arrays(arrays: Array) -> void:
	if uv2_v2.size() == vertices.size():
		arrays[Mesh.ARRAY_CUSTOM2] = _pack_vec2_custom(uv2_v2)
	elif uv2_v3.size() == vertices.size():
		arrays[Mesh.ARRAY_CUSTOM2] = _pack_vec3_custom(uv2_v3)
	elif uv2_v4.size() == vertices.size():
		arrays[Mesh.ARRAY_CUSTOM2] = _pack_vec4_custom(uv2_v4)

func _add_particle_arrays(arrays: Array) -> void:
	if uv0_v4.size() != vertices.size() or normals.size() != vertices.size():
		push_error("Particle mesh export requires uv0_v4 and normals for every vertex")
		return
	arrays[Mesh.ARRAY_TEX_UV] = _pack_vec4_xy(uv0_v4)
	arrays[Mesh.ARRAY_TEX_UV2] = _pack_particle_birth_times(uv0_v4)
	arrays[Mesh.ARRAY_TANGENT] = _pack_particle_tangents(uv0_v4)
	arrays[Mesh.ARRAY_CUSTOM0] = _pack_particle_custom0(normals)

static func _pack_vec2_custom(values: Array[Vector2]) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for value in values:
		packed.append(value.x)
		packed.append(value.y)
		packed.append(0.0)
		packed.append(0.0)
	return packed

static func _pack_vec3_xy(values: Array[Vector3]) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for value in values:
		packed.append(Vector2(value.x, value.y))
	return packed

static func _pack_vec3_custom(values: Array[Vector3]) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for value in values:
		packed.append(value.x)
		packed.append(value.y)
		packed.append(value.z)
		packed.append(0.0)
	return packed

static func _pack_vec4_xy(values: Array[Vector4]) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for value in values:
		packed.append(Vector2(value.x, value.y))
	return packed

static func _pack_vec4_custom(values: Array[Vector4]) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for value in values:
		packed.append(value.x)
		packed.append(value.y)
		packed.append(value.z)
		packed.append(value.w)
	return packed

static func _pack_particle_birth_times(values: Array[Vector4]) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for value in values:
		packed.append(Vector2(value.w, value.z))
	return packed

static func _pack_particle_tangents(values: Array[Vector4]) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for value in values:
		packed.append(0.0)
		packed.append(0.0)
		packed.append(value.z)
		packed.append(1.0)
	return packed

static func _pack_particle_custom0(centers: Array[Vector3]) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for index in range(centers.size()):
		var center := centers[index]
		packed.append(float(index))
		packed.append(center.x)
		packed.append(center.y)
		packed.append(center.z)
	return packed

static func _pack_tangents(values: Array[Vector4]) -> PackedFloat32Array:
	var packed := PackedFloat32Array()
	for value in values:
		packed.append(value.x)
		packed.append(value.y)
		packed.append(value.z)
		packed.append(value.w)
	return packed
