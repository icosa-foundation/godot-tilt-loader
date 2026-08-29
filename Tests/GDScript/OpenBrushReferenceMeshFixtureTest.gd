extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")
const StrokeBridgeScript := preload("res://addons/open_brush_stroke_integration/open_brush_stroke_bridge.gd")
const IcosaOpenBrushScript := preload("res://addons/icosa/open_brush/open_brush.gd")
const FixtureAdapterScript := preload("res://Tests/GDScript/Support/OpenBrushMeshFixtureAdapter.gd")

const REFERENCE_DIR := "res://Resources/Fixtures/OpenBrushReferenceMeshes"
const DEFAULT_POSITION_TOLERANCE := 0.00001
const DEFAULT_NORMAL_TOLERANCE := 0.00001
const DEFAULT_COLOR_TOLERANCE := 0.00001
const DEFAULT_UV_TOLERANCE := 0.00001
const DEFAULT_TANGENT_TOLERANCE := 0.00005

var _failures := 0

func _init() -> void:
	var fixture_paths := _reference_fixture_paths()
	if fixture_paths.is_empty():
		print("OPEN_BRUSH_REFERENCE_MESH\tno reference fixtures found in %s" % REFERENCE_DIR)
		if _requires_fixtures():
			_expect(false, "reference fixtures are required")
		quit(1 if _failures > 0 else 0)
		return

	var manifest := _load_manifest()
	_expect(manifest != null, "runtime manifest loads")
	if manifest != null:
		BrushCatalog.init(manifest)
		BrushRuntimeRegistryScript.register_supported_brushes(manifest)
		for path in fixture_paths:
			_check_reference_fixture(path)
	quit(1 if _failures > 0 else 0)

func _requires_fixtures() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--require-open-brush-reference-fixtures":
			return true
	return false

func _reference_fixture_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(REFERENCE_DIR)
	if dir == null:
		return paths
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			paths.append(REFERENCE_DIR.path_join(file_name))
	paths.sort()
	return paths

func _load_manifest() -> TiltBrushManifest:
	var project_path := ProjectSettings.globalize_path("res://")
	var manifest := UnityAssetLoader.load_manifest(project_path.path_join("Manifest.asset"))
	if manifest == null:
		return null
	var experimental := UnityAssetLoader.load_manifest(project_path.path_join("Manifest_Experimental.asset"))
	if experimental != null:
		manifest.append_from(experimental)
	return manifest

func _check_reference_fixture(path: String) -> void:
	var reference := _load_json_file(path)
	_expect(not reference.is_empty(), "%s loads" % path)
	if reference.is_empty():
		return
	var schema := String(reference.get("schema", ""))
	_expect(schema in ["open-brush-reference-mesh-v1", FixtureAdapterScript.SCHEMA], "%s schema" % path)
	if schema not in ["open-brush-reference-mesh-v1", FixtureAdapterScript.SCHEMA]:
		return

	var stroke_fixture := _load_stroke_fixture(reference, path)
	_expect(not stroke_fixture.is_empty(), "%s stroke fixture loads" % path)
	if stroke_fixture.is_empty():
		return
	if schema == FixtureAdapterScript.SCHEMA:
		stroke_fixture = FixtureAdapterScript.runtime_stroke_fixture(stroke_fixture)

	var desc := _resolve_fixture_descriptor(stroke_fixture)
	_expect(desc != null, "%s brush descriptor resolves" % path)
	if desc == null:
		return
	var expected_brush := String(reference.get("brush", ""))
	if not expected_brush.is_empty():
		_expect(desc.m_DurableName == expected_brush, "%s brush name" % path)

	var stroke_dict := _fixture_to_stroke_dict(stroke_fixture)
	var bridge := StrokeBridgeScript.new()
	var stroke: Stroke = bridge.stroke_from_icosa_stroke(
		stroke_dict,
		null,
		float(stroke_fixture.get("scene_scale", 1.0)),
		desc)
	_expect(stroke != null, "%s converts to runtime stroke" % path)
	if stroke == null:
		return

	var actual_mesh: MeshData = BrushStrokeReplay.build_mesh_data_for_stroke(stroke)
	_expect(actual_mesh != null, "%s Godot replay returns mesh data" % path)
	if actual_mesh == null:
		return
	_compare_reference_mesh(path, desc, reference, actual_mesh)

func _load_stroke_fixture(reference: Dictionary, reference_path: String) -> Dictionary:
	var source_path := String(reference.get("source_stroke_fixture", ""))
	if source_path.is_empty():
		var stroke_value: Variant = reference.get("stroke", {})
		if stroke_value is Dictionary:
			return stroke_value
		return {}
	if not source_path.begins_with("res://"):
		source_path = REFERENCE_DIR.path_join(source_path)
	var stroke_fixture := _load_json_file(source_path)
	if stroke_fixture.is_empty():
		push_error("OpenBrushReferenceMeshFixtureTest: %s missing source stroke fixture %s" % [reference_path, source_path])
	return stroke_fixture

func _compare_reference_mesh(path: String, desc: BrushDescriptor, reference: Dictionary, actual_mesh: MeshData) -> void:
	var mesh: Dictionary = reference.get("mesh", {})
	var actual: Dictionary = {
		"vertices": actual_mesh.vertices,
		"triangles": actual_mesh.triangles,
		"normals": actual_mesh.normals,
		"colors": actual_mesh.colors,
		"tangents": actual_mesh.tangents,
	}
	var is_v2 := String(reference.get("schema", "")) == FixtureAdapterScript.SCHEMA
	if is_v2:
		mesh = FixtureAdapterScript.expected_mesh_for_comparison(reference)
	var layout: Dictionary = mesh.get("layout", {})
	if is_v2:
		actual = FixtureAdapterScript.actual_mesh_for_comparison(actual_mesh, layout)
	var expected_vertices := _vec3_array_list(mesh.get("vertices", []))
	var expected_triangles := _int_array_list(mesh.get("triangles", []))
	var expected_normals := _vec3_array_list(mesh.get("normals", []))
	var expected_colors := _color_array_list(mesh.get("colors", []))
	var expected_tangents := _vec4_array_list(mesh.get("tangents", []))

	var actual_vertices: Array = actual.get("vertices", [])
	var actual_triangles: Array = actual.get("triangles", [])
	var actual_normals: Array = actual.get("normals", [])
	var actual_colors: Array = actual.get("colors", [])
	var actual_tangents: Array = actual.get("tangents", [])
	_expect(actual_vertices.size() == expected_vertices.size(), "%s vertex count expected %d but got %d" % [path, expected_vertices.size(), actual_vertices.size()])
	_expect(actual_triangles.size() == expected_triangles.size(), "%s triangle index count expected %d but got %d" % [path, expected_triangles.size(), actual_triangles.size()])

	var position_tolerance := float(reference.get("position_tolerance", DEFAULT_POSITION_TOLERANCE))
	var normal_tolerance := float(reference.get("normal_tolerance", DEFAULT_NORMAL_TOLERANCE))
	var color_tolerance := float(reference.get("color_tolerance", DEFAULT_COLOR_TOLERANCE))
	var uv_tolerance := float(reference.get("uv_tolerance", DEFAULT_UV_TOLERANCE))
	var tangent_tolerance := float(reference.get("tangent_tolerance", DEFAULT_TANGENT_TOLERANCE))

	var max_position_delta := _max_vec3_delta(actual_vertices, expected_vertices)
	_expect(max_position_delta <= position_tolerance, "%s vertex positions exceed tolerance %.8f; %s" % [path, position_tolerance, _describe_vec3_mismatch(actual_vertices, expected_vertices)])
	if max_position_delta > position_tolerance:
		_report_triangle_position_set(path, actual_vertices, actual_triangles, expected_vertices, expected_triangles, position_tolerance)
	_compare_triangles(path, actual_triangles, expected_triangles)

	var max_normal_delta := _compare_vec3_channel(
		path,
		"normals",
		actual_normals,
		expected_normals,
		normal_tolerance,
		bool(layout.get("use_normals", false)))
	var max_color_delta := _compare_color_channel(
		path,
		actual_colors,
		expected_colors,
		color_tolerance,
		bool(layout.get("use_colors", false)))
	var max_tangent_delta := _compare_vec4_channel(
		path,
		"tangents",
		actual_tangents,
		expected_tangents,
		tangent_tolerance,
		bool(layout.get("use_tangents", false)))
	var max_uv_delta := 0.0
	for channel in range(3):
		var key := "uv%d" % channel
		var size := int(layout.get("%s_size" % key, _infer_vector_size(mesh.get(key, []))))
		var expected_uvs := _vector_array_list(mesh.get(key, []), size)
		var actual_uvs: Array = actual.get(key, actual_mesh.get_uvs(channel, size))
		var channel_delta := _compare_vector_channel(
			path,
			key,
			actual_uvs,
			expected_uvs,
			size,
			uv_tolerance,
			size > 0)
		max_uv_delta = maxf(max_uv_delta, channel_delta)

	var max_particle_render_delta := 0.0
	if _layout_has_particle_attributes(layout):
		max_particle_render_delta = _compare_particle_render_arrays(
			path,
			actual_mesh,
			expected_vertices.size(),
			expected_normals,
			_vec4_array_list(mesh.get("uv0", [])),
			uv_tolerance,
			FixtureAdapterScript.UNIT_SCALE_TO_METERS if is_v2 else 1.0)

	if is_v2:
		_compare_bounds(path, actual.get("bounds", {}), mesh.get("bounds", {}), position_tolerance)

	print("OPEN_BRUSH_REFERENCE_MESH\tpath=%s\tbrush=%s\tverts=%d\ttris=%d\tmax_position_delta=%.8f\tmax_normal_delta=%.8f\tmax_color_delta=%.8f\tmax_uv_delta=%.8f\tmax_tangent_delta=%.8f\tmax_particle_render_delta=%.8f" % [
		path,
		desc.m_DurableName,
		actual_vertices.size(),
		actual_triangles.size(),
		max_position_delta,
		max_normal_delta,
		max_color_delta,
		max_uv_delta,
		max_tangent_delta,
		max_particle_render_delta,
	])

func _load_json_file(path: String) -> Dictionary:
	var json := FileAccess.get_file_as_string(path)
	if json.is_empty():
		return {}
	var parsed = JSON.parse_string(json)
	if not parsed is Dictionary:
		return {}
	return parsed

func _resolve_fixture_descriptor(fixture: Dictionary) -> BrushDescriptor:
	var guid := String(fixture.get("brush_guid", ""))
	var desc := BrushCatalog.get_brush(guid)
	if desc != null:
		return desc
	var open_brush = IcosaOpenBrushScript.new()
	open_brush.ensure_loaded()
	var mapped_name: String = open_brush.resolve_brush_name(guid)
	if mapped_name.is_empty() or mapped_name == guid:
		return null
	return BrushCatalog.get_brush_by_durable_name(mapped_name)

func _fixture_to_stroke_dict(fixture: Dictionary) -> Dictionary:
	var color_values: Array = fixture.get("color", [1.0, 1.0, 1.0, 1.0])
	return {
		"brush_guid": String(fixture.get("brush_guid", "")),
		"brush_scale": float(fixture.get("brush_scale", 1.0)),
		"brush_size": float(fixture.get("brush_size", 1.0)),
		"seed": int(fixture.get("seed", 0)),
		"color": Color(
			float(color_values[0]),
			float(color_values[1]),
			float(color_values[2]),
			float(color_values[3])),
		"control_points": _fixture_control_points(fixture.get("control_points", [])),
	}

func _fixture_control_points(points: Array) -> Array:
	var output := []
	for value in points:
		if not value is Dictionary:
			continue
		var point: Dictionary = value
		var position_values: Array = point.get("position", [0.0, 0.0, 0.0])
		var orientation_values: Array = point.get("orientation", [0.0, 0.0, 0.0, 1.0])
		output.append({
			"position": Vector3(
				float(position_values[0]),
				float(position_values[1]),
				float(position_values[2])),
			"orientation": Quaternion(
				float(orientation_values[0]),
				float(orientation_values[1]),
				float(orientation_values[2]),
				float(orientation_values[3])),
			"pressure": float(point.get("pressure", 1.0)),
			"timestamp": int(point.get("timestamp", 0)),
		})
	return output

func _vec3_array_list(values: Variant) -> Array[Vector3]:
	var output: Array[Vector3] = []
	if not values is Array:
		return output
	for value in values:
		if value is Array and value.size() >= 3:
			output.append(Vector3(float(value[0]), float(value[1]), float(value[2])))
	return output

func _vec2_array_list(values: Variant) -> Array[Vector2]:
	var output: Array[Vector2] = []
	if not values is Array:
		return output
	for value in values:
		if value is Array and value.size() >= 2:
			output.append(Vector2(float(value[0]), float(value[1])))
	return output

func _vec4_array_list(values: Variant) -> Array[Vector4]:
	var output: Array[Vector4] = []
	if not values is Array:
		return output
	for value in values:
		if value is Array and value.size() >= 4:
			output.append(Vector4(float(value[0]), float(value[1]), float(value[2]), float(value[3])))
	return output

func _color_array_list(values: Variant) -> Array[Color]:
	var output: Array[Color] = []
	if not values is Array:
		return output
	for value in values:
		if value is Array and value.size() >= 4:
			output.append(Color(float(value[0]), float(value[1]), float(value[2]), float(value[3])))
	return output

func _vector_array_list(values: Variant, size: int) -> Array:
	match size:
		0:
			return []
		2:
			return _vec2_array_list(values)
		3:
			return _vec3_array_list(values)
		4:
			return _vec4_array_list(values)
		_:
			_expect(false, "invalid vector channel size %d" % size)
			return []

func _int_array_list(values: Variant) -> Array[int]:
	var output: Array[int] = []
	if not values is Array:
		return output
	for value in values:
		output.append(int(value))
	return output

func _infer_vector_size(values: Variant) -> int:
	if not values is Array or values.is_empty():
		return 0
	var first = values[0]
	if first is Array:
		return first.size()
	return 0

func _layout_has_particle_attributes(layout: Dictionary) -> bool:
	if layout.has("particle_attributes"):
		return bool(layout["particle_attributes"])
	return bool(layout.get("use_vertex_ids", false)) and bool(layout.get("fbx_export_normal_as_texcoord1", false))

func _max_vec3_delta(actual: Array, expected: Array[Vector3]) -> float:
	var max_delta := 0.0
	var count := mini(actual.size(), expected.size())
	for index in range(count):
		max_delta = maxf(max_delta, actual[index].distance_to(expected[index]))
	return max_delta

func _max_vec2_delta(actual: Array, expected: Array[Vector2]) -> float:
	var max_delta := 0.0
	var count := mini(actual.size(), expected.size())
	for index in range(count):
		max_delta = maxf(max_delta, actual[index].distance_to(expected[index]))
	return max_delta

func _max_vec4_delta(actual: Array, expected: Array[Vector4]) -> float:
	var max_delta := 0.0
	var count := mini(actual.size(), expected.size())
	for index in range(count):
		var delta := maxf(absf(actual[index].x - expected[index].x), absf(actual[index].y - expected[index].y))
		delta = maxf(delta, absf(actual[index].z - expected[index].z))
		delta = maxf(delta, absf(actual[index].w - expected[index].w))
		max_delta = maxf(max_delta, delta)
	return max_delta

func _max_color_delta(actual: Array[Color], expected: Array[Color]) -> float:
	var max_delta := 0.0
	var count := mini(actual.size(), expected.size())
	for index in range(count):
		var delta := maxf(absf(actual[index].r - expected[index].r), absf(actual[index].g - expected[index].g))
		delta = maxf(delta, absf(actual[index].b - expected[index].b))
		delta = maxf(delta, absf(actual[index].a - expected[index].a))
		max_delta = maxf(max_delta, delta)
	return max_delta

func _describe_vec2_mismatch(actual: Array, expected: Array[Vector2]) -> String:
	var mismatch_index := -1
	var mismatch_delta := -1.0
	for index in range(mini(actual.size(), expected.size())):
		var delta: float = actual[index].distance_to(expected[index])
		if delta > mismatch_delta:
			mismatch_index = index
			mismatch_delta = delta
	return _format_mismatch(mismatch_index, actual, expected, mismatch_delta)

func _describe_vec3_mismatch(actual: Array, expected: Array[Vector3]) -> String:
	var mismatch_index := -1
	var mismatch_delta := -1.0
	for index in range(mini(actual.size(), expected.size())):
		var delta: float = actual[index].distance_to(expected[index])
		if delta > mismatch_delta:
			mismatch_index = index
			mismatch_delta = delta
	return _format_mismatch(mismatch_index, actual, expected, mismatch_delta)

func _describe_vec4_mismatch(actual: Array, expected: Array[Vector4]) -> String:
	var mismatch_index := -1
	var mismatch_delta := -1.0
	for index in range(mini(actual.size(), expected.size())):
		var delta := maxf(absf(actual[index].x - expected[index].x), absf(actual[index].y - expected[index].y))
		delta = maxf(delta, absf(actual[index].z - expected[index].z))
		delta = maxf(delta, absf(actual[index].w - expected[index].w))
		if delta > mismatch_delta:
			mismatch_index = index
			mismatch_delta = delta
	return _format_mismatch(mismatch_index, actual, expected, mismatch_delta)

func _describe_color_mismatch(actual: Array[Color], expected: Array[Color]) -> String:
	var mismatch_index := -1
	var mismatch_delta := -1.0
	for index in range(mini(actual.size(), expected.size())):
		var delta := maxf(absf(actual[index].r - expected[index].r), absf(actual[index].g - expected[index].g))
		delta = maxf(delta, absf(actual[index].b - expected[index].b))
		delta = maxf(delta, absf(actual[index].a - expected[index].a))
		if delta > mismatch_delta:
			mismatch_index = index
			mismatch_delta = delta
	return _format_mismatch(mismatch_index, actual, expected, mismatch_delta)

func _format_mismatch(index: int, actual: Array, expected: Array, delta: float) -> String:
	if index < 0:
		return "no shared elements (expected count %d, actual count %d)" % [expected.size(), actual.size()]
	return "element %d expected %s but got %s (delta %.8f)" % [index, expected[index], actual[index], delta]

func _compare_vec3_channel(path: String, channel_name: String, actual: Array[Vector3], expected: Array[Vector3], tolerance: float, required: bool) -> float:
	if expected.is_empty() and not required:
		return 0.0
	_expect(actual.size() == expected.size(), "%s %s count expected %d but got %d" % [path, channel_name, expected.size(), actual.size()])
	var max_delta := _max_vec3_delta(actual, expected)
	_expect(max_delta <= tolerance, "%s %s exceed tolerance %.8f; %s" % [path, channel_name, tolerance, _describe_vec3_mismatch(actual, expected)])
	return max_delta

func _compare_vec4_channel(path: String, channel_name: String, actual: Array[Vector4], expected: Array[Vector4], tolerance: float, required: bool) -> float:
	if expected.is_empty() and not required:
		return 0.0
	_expect(actual.size() == expected.size(), "%s %s count expected %d but got %d" % [path, channel_name, expected.size(), actual.size()])
	var max_delta := _max_vec4_delta(actual, expected)
	_expect(max_delta <= tolerance, "%s %s exceed tolerance %.8f; %s" % [path, channel_name, tolerance, _describe_vec4_mismatch(actual, expected)])
	return max_delta

func _compare_color_channel(path: String, actual: Array[Color], expected: Array[Color], tolerance: float, required: bool) -> float:
	if expected.is_empty() and not required:
		return 0.0
	_expect(actual.size() == expected.size(), "%s colors count expected %d but got %d" % [path, expected.size(), actual.size()])
	var max_delta := _max_color_delta(actual, expected)
	_expect(max_delta <= tolerance, "%s colors exceed tolerance %.8f; %s" % [path, tolerance, _describe_color_mismatch(actual, expected)])
	return max_delta

func _compare_vector_channel(path: String, channel_name: String, actual: Array, expected: Array, size: int, tolerance: float, required: bool) -> float:
	if size == 0:
		_expect(expected.is_empty(), "%s %s expected empty when layout size is 0" % [path, channel_name])
		return 0.0
	if expected.is_empty() and not required:
		return 0.0
	_expect(actual.size() == expected.size(), "%s %s count expected %d but got %d" % [path, channel_name, expected.size(), actual.size()])
	var max_delta := 0.0
	match size:
		2:
			max_delta = _max_vec2_delta(actual, expected)
		3:
			max_delta = _max_vec3_delta(actual, expected)
		4:
			max_delta = _max_vec4_delta(actual, expected)
		_:
			_expect(false, "%s %s invalid size %d" % [path, channel_name, size])
			return 0.0
	var mismatch := ""
	match size:
		2:
			mismatch = _describe_vec2_mismatch(actual, expected)
		3:
			mismatch = _describe_vec3_mismatch(actual, expected)
		4:
			mismatch = _describe_vec4_mismatch(actual, expected)
	_expect(max_delta <= tolerance, "%s %s exceed tolerance %.8f; %s" % [path, channel_name, tolerance, mismatch])
	return max_delta

func _compare_particle_render_arrays(
	path: String,
	actual_mesh: MeshData,
	expected_vertex_count: int,
	expected_centers: Array[Vector3],
	expected_uv0: Array[Vector4],
	tolerance: float,
	actual_center_scale: float = 1.0) -> float:
	_expect(actual_mesh.use_particle_attributes, "%s particle render path enabled" % path)
	_expect(expected_centers.size() == expected_vertex_count, "%s particle source center count" % path)
	_expect(expected_uv0.size() == expected_vertex_count, "%s particle source uv0 count" % path)

	var arrays := actual_mesh.to_mesh_arrays()
	_expect(arrays[Mesh.ARRAY_NORMAL] == null, "%s particle render omits normal stream" % path)
	_expect(arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array, "%s particle render UV array" % path)
	_expect(arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array, "%s particle render UV2 array" % path)
	_expect(arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array, "%s particle render tangent array" % path)
	_expect(arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array, "%s particle render CUSTOM0 array" % path)
	if not (
		arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array
		and arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array
		and arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array
		and arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array
	):
		return INF

	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var custom0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	_expect(uv.size() == expected_vertex_count, "%s particle render UV count" % path)
	_expect(uv2.size() == expected_vertex_count, "%s particle render UV2 count" % path)
	_expect(tangents.size() == expected_vertex_count * 4, "%s particle render tangent float count" % path)
	_expect(custom0.size() == expected_vertex_count * 4, "%s particle render CUSTOM0 float count" % path)

	var max_delta := 0.0
	var count := mini(expected_vertex_count, expected_uv0.size())
	count = mini(count, expected_centers.size())
	count = mini(count, uv.size())
	count = mini(count, uv2.size())
	for index in range(count):
		var source_uv := expected_uv0[index]
		max_delta = maxf(max_delta, uv[index].distance_to(Vector2(source_uv.x, source_uv.y)))
		max_delta = maxf(max_delta, uv2[index].distance_to(Vector2(source_uv.w, source_uv.z)))
		if index * 4 + 3 < tangents.size():
			max_delta = maxf(max_delta, absf(tangents[index * 4] - 0.0))
			max_delta = maxf(max_delta, absf(tangents[index * 4 + 1] - 0.0))
			max_delta = maxf(max_delta, absf(tangents[index * 4 + 2] - source_uv.z))
			max_delta = maxf(max_delta, absf(tangents[index * 4 + 3] - 1.0))
		if index * 4 + 3 < custom0.size():
			var center := expected_centers[index]
			max_delta = maxf(max_delta, absf(custom0[index * 4] - float(index)))
			max_delta = maxf(max_delta, absf(custom0[index * 4 + 1] * actual_center_scale - center.x))
			max_delta = maxf(max_delta, absf(custom0[index * 4 + 2] * actual_center_scale - center.y))
			max_delta = maxf(max_delta, absf(custom0[index * 4 + 3] * actual_center_scale - center.z))

	_expect(max_delta <= tolerance, "%s particle render arrays within tolerance %.8f" % [path, tolerance])
	return max_delta

func _compare_bounds(path: String, actual: Dictionary, expected: Dictionary, tolerance: float) -> void:
	if expected.is_empty():
		return
	var expected_min := _vec3_from_value(expected.get("min", []))
	var expected_max := _vec3_from_value(expected.get("max", []))
	var actual_min := _vec3_from_value(actual.get("min", Vector3.ZERO))
	var actual_max := _vec3_from_value(actual.get("max", Vector3.ZERO))
	_expect(actual_min.distance_to(expected_min) <= tolerance, "%s bounds min within tolerance %.8f" % [path, tolerance])
	_expect(actual_max.distance_to(expected_max) <= tolerance, "%s bounds max within tolerance %.8f" % [path, tolerance])

func _vec3_from_value(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _compare_triangles(path: String, actual: Array[int], expected: Array[int]) -> void:
	var count := mini(actual.size(), expected.size())
	for index in range(count):
		if actual[index] != expected[index]:
			_expect(false, "%s triangle index %d expected %d but got %d" % [path, index, expected[index], actual[index]])
			return

func _report_triangle_position_set(
	path: String,
	actual_vertices: Array,
	actual_triangles: Array,
	expected_vertices: Array,
	expected_triangles: Array,
	tolerance: float
) -> void:
	var actual_set := _triangle_position_multiset(actual_vertices, actual_triangles, tolerance)
	var expected_set := _triangle_position_multiset(expected_vertices, expected_triangles, tolerance)
	var missing := 0
	var extra := 0
	for key in expected_set:
		missing += maxi(0, int(expected_set[key]) - int(actual_set.get(key, 0)))
	for key in actual_set:
		extra += maxi(0, int(actual_set[key]) - int(expected_set.get(key, 0)))
	print("OPEN_BRUSH_REFERENCE_TRIANGLE_SET\tpath=%s\texpected=%d\tactual=%d\tmissing=%d\textra=%d" % [
		path,
		int(expected_triangles.size() / 3),
		int(actual_triangles.size() / 3),
		missing,
		extra,
	])

func _triangle_position_multiset(vertices: Array, triangles: Array, tolerance: float) -> Dictionary:
	var result := {}
	for index in range(0, triangles.size() - 2, 3):
		var point_keys: Array[String] = []
		for offset in range(3):
			var vertex_index := int(triangles[index + offset])
			if vertex_index < 0 or vertex_index >= vertices.size():
				continue
			var point: Vector3 = vertices[vertex_index]
			point_keys.append("%d:%d:%d" % [
				roundi(point.x / tolerance),
				roundi(point.y / tolerance),
				roundi(point.z / tolerance),
			])
		if point_keys.size() != 3:
			continue
		point_keys.sort()
		var key := "|".join(point_keys)
		result[key] = int(result.get(key, 0)) + 1
	return result

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("OpenBrushReferenceMeshFixtureTest: %s" % message)
