extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")
const StrokeBridgeScript := preload("res://addons/open_brush_stroke_integration/open_brush_stroke_bridge.gd")
const IcosaOpenBrushScript := preload("res://addons/icosa/open_brush/open_brush.gd")

const FLOAT_TOLERANCE := 0.00001
const FIXTURES := [
	{
		"path": "res://Resources/Fixtures/cafe_ink_stroke_150.json",
		"brush": "Ink",
		"runtime": "QuadStripBrushStretchUV",
		"control_points": 51,
		"vertices": 600,
		"indices": 600,
		"bounds_min": Vector3(-12.95441, 3.510177, -2.274141),
		"bounds_max": Vector3(-12.30314, 4.81896, -1.628555),
	},
	{
		"path": "res://Resources/Fixtures/cafe_duct_tape_geometry_stroke_496.json",
		"brush": "DuctTapeGeometry",
		"runtime": "FlatGeometryBrush",
		"control_points": 26,
		"vertices": 104,
		"indices": 300,
		"bounds_min": Vector3(13.12367, -8.358246, 1.216269),
		"bounds_max": Vector3(13.61481, -6.600898, 2.6376),
	},
	{
		"path": "res://Resources/Fixtures/cafe_stars_stroke_130.json",
		"brush": "Stars",
		"runtime": "GeniusParticlesBrush",
		"control_points": 2,
		"vertices": 4,
		"indices": 6,
		"bounds_min": Vector3(-7.21665, 10.08923, -1.997503),
		"bounds_max": Vector3(-7.179084, 10.13264, -1.97293),
	},
	{
		"path": "res://Resources/Fixtures/cafe_sparks_stroke_463.json",
		"brush": "Sparks",
		"runtime": "TubeBrush",
		"control_points": 2,
		"vertices": 34,
		"indices": 96,
		"bounds_min": Vector3(0.730572, -7.083524, -13.51105),
		"bounds_max": Vector3(0.948587, -6.927797, -13.4268),
	},
	{
		"path": "res://Resources/Fixtures/cafe_matte_hull_stroke_11.json",
		"brush": "MatteHull",
		"runtime": "HullBrush",
		"control_points": 2,
		"vertices": 36,
		"indices": 36,
		"bounds_min": Vector3(2.405931, -0.059916, 5.959974),
		"bounds_max": Vector3(2.412326, -0.055921, 5.966994),
	},
]

var _failures := 0

func _init() -> void:
	var manifest := _load_manifest()
	_expect(manifest != null, "runtime manifest loads")
	if manifest != null:
		BrushCatalog.init(manifest)
		BrushRuntimeRegistryScript.register_supported_brushes(manifest)
		for fixture_spec in FIXTURES:
			_check_fixture_replay(fixture_spec)
	quit(1 if _failures > 0 else 0)

func _load_manifest() -> TiltBrushManifest:
	var project_path := ProjectSettings.globalize_path("res://")
	var manifest := UnityAssetLoader.load_manifest(project_path.path_join("Manifest.asset"))
	if manifest == null:
		return null
	var experimental := UnityAssetLoader.load_manifest(project_path.path_join("Manifest_Experimental.asset"))
	if experimental != null:
		manifest.append_from(experimental)
	return manifest

func _check_fixture_replay(fixture_spec: Dictionary) -> void:
	var fixture := _load_fixture(String(fixture_spec["path"]))
	_expect(not fixture.is_empty(), "%s fixture loads" % fixture_spec["path"])
	if fixture.is_empty():
		return

	var desc := _resolve_fixture_descriptor(fixture)
	_expect(desc != null, "%s brush descriptor resolves" % fixture_spec["path"])
	if desc == null:
		return
	_expect(desc.m_DurableName == String(fixture_spec["brush"]), "%s brush name" % fixture_spec["path"])
	_expect(BrushRuntimeRegistryScript.is_supported(desc), "%s brush is runtime supported" % fixture_spec["path"])
	_expect(_runtime_class_for_descriptor(desc) == String(fixture_spec["runtime"]), "%s runtime class" % fixture_spec["path"])

	var stroke_dict := _fixture_to_stroke_dict(fixture)
	_expect(stroke_dict["control_points"].size() == int(fixture_spec["control_points"]), "%s control point count" % fixture_spec["path"])
	var bridge := StrokeBridgeScript.new()
	var stroke: Stroke = bridge.stroke_from_icosa_stroke(stroke_dict, null, float(fixture.get("scene_scale", 1.0)), desc)
	_expect(stroke != null, "%s converts to runtime stroke" % fixture_spec["path"])
	if stroke == null:
		return

	var mesh_data: MeshData = BrushStrokeReplay.build_mesh_data_for_stroke(stroke)
	_expect(mesh_data != null, "%s runtime replay returns mesh data" % fixture_spec["path"])
	if mesh_data == null:
		return
	_expect(not mesh_data.is_empty(), "%s runtime replay mesh is non-empty" % fixture_spec["path"])

	var arrays := mesh_data.to_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uv0: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var bounds := _bounds(vertices)
	print("CAFE_STROKE_FIXTURE\tpath=%s\tbrush=%s\truntime=%s\tverts=%d\tindices=%d\tuv0=%d\tcolors=%d\tbounds_min=%s\tbounds_max=%s" % [
		fixture_spec["path"],
		desc.m_DurableName,
		_runtime_class_for_descriptor(desc),
		vertices.size(),
		indices.size(),
		uv0.size(),
		colors.size(),
		bounds["min"],
		bounds["max"],
	])

	var expected_vertices := int(fixture_spec["vertices"])
	var expected_indices := int(fixture_spec["indices"])
	if expected_vertices >= 0:
		_expect(vertices.size() == expected_vertices, "%s vertex count" % fixture_spec["path"])
	if expected_indices >= 0:
		_expect(indices.size() == expected_indices, "%s index count" % fixture_spec["path"])
	_expect(uv0.size() == vertices.size(), "%s uv0 count" % fixture_spec["path"])
	_expect(colors.size() == vertices.size(), "%s color count" % fixture_spec["path"])
	if expected_vertices >= 0:
		_expect_vec3_close(bounds["min"], fixture_spec["bounds_min"], "%s bounds min" % fixture_spec["path"])
		_expect_vec3_close(bounds["max"], fixture_spec["bounds_max"], "%s bounds max" % fixture_spec["path"])

func _load_fixture(path: String) -> Dictionary:
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

func _runtime_class_for_descriptor(desc: BrushDescriptor) -> String:
	var brush: BaseBrushScript = BrushRuntimeRegistryScript.create_brush_for_descriptor(desc)
	if brush == null:
		return "<none>"
	var runtime_name: String = brush.get_script().get_global_name()
	brush.free()
	return runtime_name

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

func _bounds(vertices: PackedVector3Array) -> Dictionary:
	if vertices.is_empty():
		return {"min": Vector3.ZERO, "max": Vector3.ZERO}
	var min_value := vertices[0]
	var max_value := vertices[0]
	for vertex in vertices:
		min_value.x = minf(min_value.x, vertex.x)
		min_value.y = minf(min_value.y, vertex.y)
		min_value.z = minf(min_value.z, vertex.z)
		max_value.x = maxf(max_value.x, vertex.x)
		max_value.y = maxf(max_value.y, vertex.y)
		max_value.z = maxf(max_value.z, vertex.z)
	return {"min": min_value, "max": max_value}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("CafeStrokeFixturesReplayTest: %s" % message)

func _expect_vec3_close(actual: Vector3, expected: Vector3, message: String) -> void:
	if actual.distance_to(expected) > FLOAT_TOLERANCE:
		_failures += 1
		push_error("CafeStrokeFixturesReplayTest: %s expected %s but got %s" % [message, expected, actual])
