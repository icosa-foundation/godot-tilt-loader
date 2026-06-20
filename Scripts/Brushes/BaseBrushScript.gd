class_name BaseBrushScript
extends Node3D

const K_PREVIEW_DURATION := 0.2

var m_bCanBatch := false
var m_Desc: BrushDescriptor
var m_EnableBackfaces := false
var m_PreviewMode := false
var m_IsLoading := false
var m_Color := Color.WHITE
var m_LastSpawnXf := TrTransform.identity()
var m_BaseSize_PS := 0.0
var m_rng := StatelessRng.create(0)
var stroke: Stroke
var mesh_data := MeshData.new()
var _mesh_instance: MeshInstance3D

static var _brush_type_registry := {}

static func register_brush_type(durable_name: String, factory: Callable) -> void:
	_brush_type_registry[durable_name] = factory

static func clear_brush_types() -> void:
	_brush_type_registry.clear()

static func has_brush_type(durable_name: String) -> bool:
	return _brush_type_registry.has(durable_name)

static func registered_brush_count() -> int:
	return _brush_type_registry.size()

static func create_brush(parent: Node, xf_in_parent_space: TrTransform, desc: BrushDescriptor, color: Color, size_ps: float) -> BaseBrushScript:
	var factory: Callable = _brush_type_registry.get(desc.m_DurableName, Callable())
	if not factory.is_valid():
		push_error("No brush script mapping found for '%s'" % desc.m_DurableName)
		return null
	var line: BaseBrushScript = factory.call(desc)
	line.name = desc.description()
	parent.add_child(line)
	Coords.apply_local(line, TrTransform.identity())
	line.m_Color = color
	line.m_BaseSize_PS = size_ps
	line.init_brush(desc, xf_in_parent_space)
	return line

func setup_base(can_batch: bool) -> void:
	m_bCanBatch = can_batch

func stroke_scale() -> float:
	return m_LastSpawnXf.scale

func local_to_pointer() -> float:
	return 1.0 / m_LastSpawnXf.scale

func pointer_to_local() -> float:
	return m_LastSpawnXf.scale

func base_size_ls() -> float:
	return m_BaseSize_PS * pointer_to_local()

func canvas() -> CanvasScript:
	var parent := get_parent()
	return parent as CanvasScript

func random_seed() -> int:
	return m_rng.seed

func set_random_seed(value: int) -> void:
	m_rng = StatelessRng.create(value)

func set_is_loading() -> void:
	m_IsLoading = true

func set_preview_mode() -> void:
	m_PreviewMode = true

func update_position_ls(xf: TrTransform, pressure: float) -> bool:
	if is_out_of_verts():
		return false
	var generated := update_position_impl(xf.translation, xf.rotation, pressure)
	if generated:
		m_LastSpawnXf = xf
	return generated

func set_preview_properties(color: Color, size: float) -> void:
	m_Color = color
	m_BaseSize_PS = size

func destroy_mesh() -> void:
	mesh_data.clear()
	if _mesh_instance != null:
		_mesh_instance.mesh = null

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	assert(m_BaseSize_PS != 0.0)
	m_Desc = desc
	m_EnableBackfaces = desc.m_RenderBackfaces
	m_rng = StatelessRng.create(MathUtils.random_int())
	m_LastSpawnXf = local_pointer_xf

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	m_LastSpawnXf = local_pointer_xf

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	return GeometryPool.VertexLayout.create(GeometryPool.TexcoordInfo.create(), null, null, false, false, false)

func apply_changes_to_visuals() -> void:
	pass

func hide_brush(hidden: bool) -> void:
	visible = not hidden

func get_num_used_verts() -> int:
	return 0

func get_spawn_interval(_pressure01: float) -> float:
	return INF

func always_rebuild_preview_brush() -> bool:
	return false

func decay_brush() -> void:
	pass

func needs_straight_edge_proxy() -> bool:
	return false

func init_undo_clone(_clone: Node3D) -> void:
	pass

func update_position_impl(_position: Vector3, _orientation: Quaternion, _pressure: float) -> bool:
	return false

func is_out_of_verts() -> bool:
	return false

func should_current_line_end() -> bool:
	return is_out_of_verts()

func should_discard() -> bool:
	return false

func debug_get_geometry() -> Dictionary:
	return {"verts": [], "nVerts": 0, "uv0s": [], "tris": [], "nTris": 0}

func finalize_solitary_brush() -> void:
	pass

func update_visible_mesh() -> void:
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "GeneratedMesh"
		add_child(_mesh_instance)
	_mesh_instance.mesh = mesh_data.to_array_mesh()
	if _mesh_instance.mesh != null and _mesh_instance.mesh.get_surface_count() > 0:
		_mesh_instance.mesh.surface_set_material(0, _make_runtime_material())

func _make_runtime_material() -> Material:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = m_Color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED if m_EnableBackfaces else BaseMaterial3D.CULL_BACK
	return material

func pressured_size(pressure01: float) -> float:
	var multiplier := lerpf(m_Desc.pressure_size_min(m_PreviewMode), 1.0, pressure01)
	return m_BaseSize_PS * pointer_to_local() * multiplier

func pressured_random_size(pressure01: float, salt: int) -> float:
	var randomness := 1.0 + m_rng.in01(salt) * m_Desc.m_SizeVariance
	return pressured_size(pressure01) * randomness

func pressured_opacity(pressure01: float) -> float:
	var multiplier := lerpf(m_Desc.m_PressureOpacityRange.x, m_Desc.m_PressureOpacityRange.y, pressure01)
	return clamp(m_Desc.m_Opacity * multiplier, 0.0, 1.0)

static func in_direction_of(desired: Vector3, value: Vector3) -> Vector3:
	return value if desired.dot(value) >= 0.0 else -value

static func compute_surface_frame_new(v_preferred_r: Vector3, n_move: Vector3, orientation: Quaternion) -> Dictionary:
	var basis := Basis(orientation)
	var n_pointer_f := basis * Vector3.FORWARD * -1.0
	var n_pointer_u := basis * Vector3.UP
	var v_right1 := in_direction_of(v_preferred_r, n_pointer_f.cross(n_move))
	var v_right2 := in_direction_of(v_preferred_r, n_pointer_u.cross(n_move))
	v_right2 *= abs(n_pointer_f.dot(n_move))
	var n_right := (v_right1 + v_right2).normalized()
	var n_normal := n_move.cross(n_right)
	return {"right": n_right, "normal": n_normal}

static func mirror_quad_face(array: Array, index: int) -> void:
	var dst_index := index + 6
	array[dst_index] = array[index]
	array[dst_index + 1] = array[index + 2]
	array[dst_index + 2] = array[index + 1]
	array[dst_index + 3] = array[index + 3]
	array[dst_index + 4] = array[index + 5]
	array[dst_index + 5] = array[index + 4]

static func mirror_tangents(array: Array[Vector4], index: int) -> void:
	mirror_quad_face(array, index)
	var dst_index := index + 6
	for offset in range(6):
		var tangent := array[dst_index + offset]
		tangent.w *= -1.0
		array[dst_index + offset] = tangent

static func create_duplicate_quad(vertices: Array[Vector3], normals: Array[Vector3], quad_index: int, quad_normal: Vector3) -> void:
	var previous_vertex_index := (quad_index - 1) * 6
	var current_vertex_index := quad_index * 6
	mirror_quad_face(vertices, previous_vertex_index)
	for offset in range(6):
		normals[current_vertex_index + offset] = -quad_normal

static func compute_st(vertices: Array[Vector3], uvs: Array[Vector2], base_vertex: int, iv0: int = 0, iv1: int = 1, iv2: int = 2) -> Dictionary:
	var v1 := vertices[base_vertex + iv0]
	var v2 := vertices[base_vertex + iv1]
	var v3 := vertices[base_vertex + iv2]
	var w1 := uvs[base_vertex + iv0]
	var w2 := uvs[base_vertex + iv1]
	var w3 := uvs[base_vertex + iv2]
	var x1 := v2.x - v1.x
	var x2 := v3.x - v1.x
	var y1 := v2.y - v1.y
	var y2 := v3.y - v1.y
	var z1 := v2.z - v1.z
	var z2 := v3.z - v1.z
	var s1 := w2.x - w1.x
	var s2 := w3.x - w1.x
	var t1 := w2.y - w1.y
	var t2 := w3.y - w1.y
	var r := 1.0 / (s1 * t2 - s2 * t1)
	var s_vec := Vector3(r * (t2 * x1 - t1 * x2), r * (t2 * y1 - t1 * y2), r * (t2 * z1 - t1 * z2))
	var t_vec := Vector3(r * (s1 * x2 - s2 * x1), r * (s1 * y2 - s2 * y1), r * (s1 * z2 - s2 * z1))
	return {"s": s_vec, "t": t_vec}

static func compute_s(vertices: Array[Vector3], uvs: Array[Vector2], base_vertex: int) -> Vector3:
	return compute_st(vertices, uvs, base_vertex).s

static func compute_tangent_space_for_quads(
	vertices: Array[Vector3],
	uvs: Array[Vector2],
	normals: Array[Vector3],
	tangents: Array[Vector4],
	stride: int,
	i_vert0: int,
	i_vert1: int
) -> void:
	assert((i_vert1 - i_vert0) % stride == 0)
	for i_cur in range(i_vert0, i_vert1, stride):
		var n023 := normals[i_cur]
		var n145 := normals[i_cur + 1]
		var i_prev := i_cur - stride
		var have_previous_quad := i_prev >= i_vert0
		var have_next_quad := i_cur + stride < i_vert1
		var v_s_012: Vector3
		var v_t_012: Vector3
		var w: float
		if have_previous_quad:
			v_s_012 = compute_s(vertices, uvs, i_cur)
			w = tangents[i_prev].w
		else:
			var st := compute_st(vertices, uvs, i_cur)
			v_s_012 = st.s
			v_t_012 = st.t
			w = -1.0 if n023.cross(v_s_012).dot(v_t_012) < 0.0 else 1.0
		var v_s_345 := v_s_012

		var t02 := v_s_012 - v_s_012.dot(n023) * n023
		var t3 := v_s_345 - v_s_345.dot(n023) * n023
		var tmp := (t02 + t3).normalized()
		tangents[i_cur + 2] = Vector4(tmp.x, tmp.y, tmp.z, w)
		tangents[i_cur + 3] = tangents[i_cur + 2]
		t02 = t02.normalized()
		tangents[i_cur] = Vector4(t02.x, t02.y, t02.z, w)
		if have_previous_quad:
			tangents[i_prev + 1] = tangents[i_cur]
			tangents[i_prev + 4] = tangents[i_cur]
			tangents[i_prev + 5] = tangents[i_cur + 2]

		if not have_next_quad:
			var t1 := v_s_012 - v_s_012.dot(n145) * n145
			var t45 := v_s_345 - v_s_345.dot(n145) * n145
			tmp = (t1 + t45).normalized()
			tangents[i_cur + 1] = Vector4(tmp.x, tmp.y, tmp.z, w)
			tangents[i_cur + 4] = tangents[i_cur + 1]
			t45 = t45.normalized()
			tangents[i_cur + 5] = Vector4(t45.x, t45.y, t45.z, w)
