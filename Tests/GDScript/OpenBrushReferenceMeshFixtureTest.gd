extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")
const StrokeBridgeScript := preload("res://addons/open_brush_stroke_integration/open_brush_stroke_bridge.gd")
const IcosaOpenBrushScript := preload("res://addons/icosa/open_brush/open_brush.gd")

const REFERENCE_DIR := "res://Resources/Fixtures/OpenBrushReferenceMeshes"
const DEFAULT_POSITION_TOLERANCE := 0.00001
const DEFAULT_UV_TOLERANCE := 0.00001

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
	_expect(String(reference.get("schema", "")) == "open-brush-reference-mesh-v1", "%s schema" % path)

	var stroke_fixture := _load_stroke_fixture(reference, path)
	_expect(not stroke_fixture.is_empty(), "%s stroke fixture loads" % path)
	if stroke_fixture.is_empty():
		return

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
	var expected_vertices := _vec3_array_list(mesh.get("vertices", []))
	var expected_triangles := _int_array_list(mesh.get("triangles", []))
	var expected_uv0 := _vec2_array_list(mesh.get("uv0", []))
	var arrays := actual_mesh.to_mesh_arrays()
	var actual_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var actual_triangles: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var actual_uv0: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]

	_expect(actual_vertices.size() == expected_vertices.size(), "%s vertex count" % path)
	_expect(actual_triangles.size() == expected_triangles.size(), "%s triangle index count" % path)
	if not expected_uv0.is_empty():
		_expect(actual_uv0.size() == expected_uv0.size(), "%s uv0 count" % path)

	var max_position_delta := _max_vec3_delta(actual_vertices, expected_vertices)
	var max_uv_delta := _max_vec2_delta(actual_uv0, expected_uv0)
	print("OPEN_BRUSH_REFERENCE_MESH\tpath=%s\tbrush=%s\tverts=%d\ttris=%d\tuv0=%d\tmax_position_delta=%.8f\tmax_uv_delta=%.8f" % [
		path,
		desc.m_DurableName,
		actual_vertices.size(),
		actual_triangles.size(),
		actual_uv0.size(),
		max_position_delta,
		max_uv_delta,
	])

	var position_tolerance := float(reference.get("position_tolerance", DEFAULT_POSITION_TOLERANCE))
	var uv_tolerance := float(reference.get("uv_tolerance", DEFAULT_UV_TOLERANCE))
	_expect(max_position_delta <= position_tolerance, "%s vertex positions within tolerance %.8f" % [path, position_tolerance])
	if not expected_uv0.is_empty():
		_expect(max_uv_delta <= uv_tolerance, "%s uv0 within tolerance %.8f" % [path, uv_tolerance])
	_compare_triangles(path, actual_triangles, expected_triangles)

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

func _int_array_list(values: Variant) -> Array[int]:
	var output: Array[int] = []
	if not values is Array:
		return output
	for value in values:
		output.append(int(value))
	return output

func _max_vec3_delta(actual: PackedVector3Array, expected: Array[Vector3]) -> float:
	var max_delta := 0.0
	var count := mini(actual.size(), expected.size())
	for index in range(count):
		max_delta = maxf(max_delta, actual[index].distance_to(expected[index]))
	return max_delta

func _max_vec2_delta(actual: PackedVector2Array, expected: Array[Vector2]) -> float:
	var max_delta := 0.0
	var count := mini(actual.size(), expected.size())
	for index in range(count):
		max_delta = maxf(max_delta, actual[index].distance_to(expected[index]))
	return max_delta

func _compare_triangles(path: String, actual: PackedInt32Array, expected: Array[int]) -> void:
	var count := mini(actual.size(), expected.size())
	for index in range(count):
		if actual[index] != expected[index]:
			_expect(false, "%s triangle index %d expected %d but got %d" % [path, index, expected[index], actual[index]])
			return

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("OpenBrushReferenceMeshFixtureTest: %s" % message)
