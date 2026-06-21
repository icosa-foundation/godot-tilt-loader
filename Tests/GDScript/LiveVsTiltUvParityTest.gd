extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

var _failures := 0

func _init() -> void:
	var manifest := _load_manifest()
	BrushCatalog.init(manifest)
	BrushRuntimeRegistryScript.register_supported_brushes(manifest)
	_compare_brush("Ink")
	_compare_brush("Paper")
	_compare_brush("TaperedMarker")
	_compare_brush("LightWire")
	_compare_brush("DotMarker")
	_compare_brush("Plasma")
	_compare_brush("TaperedMarker_Flat")
	_compare_brush("Stars")
	_compare_brush("Embers")
	quit(1 if _failures > 0 else 0)

func _load_manifest() -> TiltBrushManifest:
	var project_path := ProjectSettings.globalize_path("res://")
	var manifest := UnityAssetLoader.load_manifest(project_path.path_join("Manifest.asset"))
	var experimental := UnityAssetLoader.load_manifest(project_path.path_join("Manifest_Experimental.asset"))
	manifest.append_from(experimental)
	return manifest

func _compare_brush(brush_name: String) -> void:
	var desc := BrushCatalog.get_brush_by_durable_name(brush_name)
	_expect(desc != null, "%s descriptor exists" % brush_name)
	if desc == null:
		return
	var points := _sample_points()
	var size := 0.12
	var scale := 1.0
	var seed := 12345
	var direct := _build_direct(desc, points, size, scale, seed)
	var live_memory := _build_live_from_memory(desc, points, size, scale, seed)
	var live_pointer_math := _build_with_pointer_math(desc, points, size, scale, seed)
	var live_object := _build_live_from_object(desc, points, size, seed)
	_compare_meshes("%s direct vs live-memory" % brush_name, direct, live_memory)
	_compare_meshes("%s direct vs pointer-math" % brush_name, direct, live_pointer_math)
	_compare_meshes("%s direct vs live-object" % brush_name, direct, live_object)

func _sample_points() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for index in range(24):
		var t := float(index) / 4.0
		output.append({
			"position": Vector3(t * 0.22, sin(t) * 0.12, cos(t * 0.7) * 0.08),
			"orientation": Quaternion(Vector3.UP, t * 0.15),
			"pressure": 1.0,
		})
	return output

func _build_direct(desc: BrushDescriptor, points: Array[Dictionary], size: float, scale: float, seed: int) -> MeshData:
	var first := points[0]
	var brush: BaseBrushScript = BrushRuntimeRegistryScript.create_brush_for_descriptor(desc)
	brush.m_BaseSize_PS = size
	brush.m_Color = Color.WHITE
	brush.set_random_seed(seed)
	brush.init_brush(desc, TrTransform.trs(first.position, first.orientation, scale))
	brush.set_random_seed(seed)
	for index in range(points.size()):
		var point := points[index]
		brush.update_position_ls(TrTransform.trs(point.position, point.orientation, scale), point.pressure)
	brush.apply_changes_to_visuals()
	brush.finalize_for_runtime()
	var result := MeshData.new()
	result.copy_from(brush.mesh_data)
	brush.free()
	return result

func _build_live_from_memory(desc: BrushDescriptor, points: Array[Dictionary], size: float, scale: float, seed: int) -> MeshData:
	var canvas := CanvasScript.new()
	var pointer := PointerScript.new()
	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_IntendedCanvas = canvas
	stroke.m_BrushGuid = desc.m_Guid
	stroke.m_BrushScale = scale
	stroke.m_BrushSize = size
	stroke.m_Color = Color.WHITE
	stroke.m_Seed = seed
	for point in points:
		stroke.m_ControlPoints.append(ControlPoint.create(point.position, point.orientation, point.pressure, 0))
		stroke.m_ControlPointsToDrop.append(false)
	pointer.recreate_line_from_memory(stroke)
	var result := MeshData.new()
	result.copy_from((stroke.m_Object as BaseBrushScript).mesh_data)
	canvas.free()
	pointer.free()
	return result

func _build_with_pointer_math(desc: BrushDescriptor, points: Array[Dictionary], size: float, scale: float, seed: int) -> MeshData:
	var first := TrTransform.trs(points[0].position, points[0].orientation, scale)
	var brush: BaseBrushScript = BrushRuntimeRegistryScript.create_brush_for_descriptor(desc)
	brush.m_BaseSize_PS = size
	brush.m_Color = Color.WHITE
	brush.set_random_seed(seed)
	brush.init_brush(desc, first)
	brush.set_random_seed(seed)
	for index in range(points.size()):
		var point := points[index]
		brush.update_position_ls(TrTransform.trs(point.position, point.orientation, scale), point.pressure)
	brush.apply_changes_to_visuals()
	brush.finalize_for_runtime()
	var result := MeshData.new()
	result.copy_from(brush.mesh_data)
	brush.free()
	return result

func _build_live_from_object(desc: BrushDescriptor, points: Array[Dictionary], size: float, seed: int) -> MeshData:
	var root := Node3D.new()
	var canvas := CanvasScript.new()
	var pointer := PointerScript.new()
	get_root().add_child(root)
	root.add_child(canvas)
	root.add_child(pointer)
	pointer.Canvas = canvas
	pointer.m_CurrentBrush = desc
	pointer.m_CurrentBrushSize = size
	pointer.m_CurrentColor = Color.WHITE
	pointer.m_CurrentPressure = 1.0
	Coords.apply_local(pointer, TrTransform.trs(points[0].position, points[0].orientation, 1.0))
	pointer.create_new_line(canvas, Coords.as_local(pointer))
	pointer.m_CurrentLine.set_random_seed(seed)
	for index in range(points.size()):
		Coords.apply_local(pointer, TrTransform.trs(points[index].position, points[index].orientation, 1.0))
		pointer.update_line_from_object()
	pointer.detach_line(false)
	var brush := canvas.get_child(0) as BaseBrushScript
	var result := MeshData.new()
	result.copy_from(brush.mesh_data)
	root.free()
	return result

func _compare_meshes(label: String, a: MeshData, b: MeshData) -> void:
	var a_arrays := a.to_mesh_arrays()
	var b_arrays := b.to_mesh_arrays()
	var a_uv: PackedVector2Array = a_arrays[Mesh.ARRAY_TEX_UV]
	var b_uv: PackedVector2Array = b_arrays[Mesh.ARRAY_TEX_UV]
	var a_vertices: PackedVector3Array = a_arrays[Mesh.ARRAY_VERTEX]
	var b_vertices: PackedVector3Array = b_arrays[Mesh.ARRAY_VERTEX]
	print("LIVE_TILT_UV\t%s\tverts=%d/%d\tuvs=%d/%d" % [label, a_vertices.size(), b_vertices.size(), a_uv.size(), b_uv.size()])
	_expect(a_vertices.size() == b_vertices.size(), "%s vertex count" % label)
	_expect(a_uv.size() == b_uv.size(), "%s uv count" % label)
	var vertex_count := mini(a_vertices.size(), b_vertices.size())
	var max_vertex_delta := 0.0
	for index in range(vertex_count):
		max_vertex_delta = maxf(max_vertex_delta, a_vertices[index].distance_to(b_vertices[index]))
	print("LIVE_TILT_UV\t%s\tmax_vertex_delta=%.8f" % [label, max_vertex_delta])
	_expect(max_vertex_delta < 0.00001, "%s vertex delta %.8f" % [label, max_vertex_delta])
	var count := mini(a_uv.size(), b_uv.size())
	var max_uv_delta := 0.0
	for index in range(count):
		max_uv_delta = maxf(max_uv_delta, a_uv[index].distance_to(b_uv[index]))
	print("LIVE_TILT_UV\t%s\tmax_uv_delta=%.8f" % [label, max_uv_delta])
	_expect(max_uv_delta < 0.00001, "%s primary uv delta %.8f" % [label, max_uv_delta])
	_compare_particle_channels(label, a, b)

func _compare_particle_channels(label: String, a: MeshData, b: MeshData) -> void:
	if not a.use_particle_attributes and not b.use_particle_attributes:
		return
	_expect(a.use_particle_attributes == b.use_particle_attributes, "%s particle attribute flag" % label)
	_expect_close(a.bounds_padding_ls, b.bounds_padding_ls, "%s bounds padding" % label)
	var a_arrays := a.to_mesh_arrays()
	var b_arrays := b.to_mesh_arrays()
	_compare_vec2_array(label, "uv2", a_arrays[Mesh.ARRAY_TEX_UV2], b_arrays[Mesh.ARRAY_TEX_UV2])
	_compare_float_array(label, "custom0", a_arrays[Mesh.ARRAY_CUSTOM0], b_arrays[Mesh.ARRAY_CUSTOM0])

func _compare_vec2_array(label: String, channel: String, a_value: Variant, b_value: Variant) -> void:
	_expect(a_value is PackedVector2Array, "%s %s exists on first mesh" % [label, channel])
	_expect(b_value is PackedVector2Array, "%s %s exists on second mesh" % [label, channel])
	if not (a_value is PackedVector2Array and b_value is PackedVector2Array):
		return
	var a_array: PackedVector2Array = a_value
	var b_array: PackedVector2Array = b_value
	_expect(a_array.size() == b_array.size(), "%s %s count" % [label, channel])
	var count := mini(a_array.size(), b_array.size())
	var max_delta := 0.0
	for index in range(count):
		max_delta = maxf(max_delta, a_array[index].distance_to(b_array[index]))
	print("LIVE_TILT_UV\t%s\t%s_max_delta=%.8f" % [label, channel, max_delta])
	_expect(max_delta < 0.00001, "%s %s delta %.8f" % [label, channel, max_delta])

func _compare_float_array(label: String, channel: String, a_value: Variant, b_value: Variant) -> void:
	_expect(a_value is PackedFloat32Array, "%s %s exists on first mesh" % [label, channel])
	_expect(b_value is PackedFloat32Array, "%s %s exists on second mesh" % [label, channel])
	if not (a_value is PackedFloat32Array and b_value is PackedFloat32Array):
		return
	var a_array: PackedFloat32Array = a_value
	var b_array: PackedFloat32Array = b_value
	_expect(a_array.size() == b_array.size(), "%s %s count" % [label, channel])
	var count := mini(a_array.size(), b_array.size())
	var max_delta := 0.0
	for index in range(count):
		max_delta = maxf(max_delta, absf(a_array[index] - b_array[index]))
	print("LIVE_TILT_UV\t%s\t%s_max_delta=%.8f" % [label, channel, max_delta])
	_expect(max_delta < 0.00001, "%s %s delta %.8f" % [label, channel, max_delta])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("LiveVsTiltUvParityTest: %s" % message)

func _expect_close(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.00001:
		_failures += 1
		push_error("LiveVsTiltUvParityTest: %s expected %.8f but got %.8f" % [message, expected, actual])
