extends SceneTree

const AdapterScript := preload("res://Tests/GDScript/Support/OpenBrushMeshFixtureAdapter.gd")

var _failures := 0

func _init() -> void:
	_check_runtime_stroke_conversion()
	_check_indexed_mesh_conversion()
	_check_triangle_soup_conversion()
	quit(1 if _failures > 0 else 0)

func _check_runtime_stroke_conversion() -> void:
	var converted := AdapterScript.runtime_stroke_fixture({
		"coordinate_space": "unity_open_brush_units",
		"control_points": [{
			"position": [10.0, 20.0, 30.0],
			"orientation": [0.1, 0.2, 0.3, 0.4],
			"pressure": 0.5,
			"timestamp": 12,
		}],
	})
	_expect(converted.coordinate_space == "godot_open_brush_units", "runtime coordinate-space label")
	_expect(converted.control_points[0].position == [10.0, 20.0, -30.0], "runtime position reflects Z")
	_expect(converted.control_points[0].orientation == [-0.1, -0.2, 0.3, 0.4], "runtime orientation reflection")
	_expect(converted.control_points[0].pressure == 0.5, "runtime pressure preserved")
	_expect(converted.control_points[0].timestamp == 12, "runtime timestamp preserved")

func _check_indexed_mesh_conversion() -> void:
	var converted := AdapterScript.expected_mesh_for_comparison({
		"mesh": {
			"vertex_count": 3,
			"layout": {
				"normal_semantic": "Unspecified",
				"uv0_size": 3,
				"uv0_semantic": "XyIsUvZIsDistance",
			},
			"attributes": {
				"position": _attribute(3, "Position", [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0]),
				"normal": _attribute(3, "Unspecified", [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0]),
				"tangent": _attribute(4, "Unspecified", [1.0, 0.0, 0.5, 1.0, 1.0, 0.0, 0.5, 1.0, 1.0, 0.0, 0.5, 1.0]),
				"texcoord0": _attribute(3, "XyIsUvZIsDistance", [0.25, 0.5, 10.0, 0.5, 0.75, 20.0, 0.75, 1.0, 30.0]),
			},
			"triangles": [2, 0, 1],
			"bounds": {"min": [10.0, 20.0, 30.0], "max": [70.0, 80.0, 90.0]},
		},
	})
	_expect(converted.vertices[0] == [1.0, 2.0, -3.0], "indexed position scale and reflection")
	_expect(converted.normals[0] == [0.0, 0.0, -1.0], "indexed normal reflection")
	_expect(converted.tangents[0] == [1.0, 0.0, -0.5, -1.0], "indexed tangent reflection and handedness")
	_expect(converted.uv0[0] == [0.25, 0.5, 1.0], "distance UV metric component scale")
	_expect(converted.triangles == [2, 0, 1], "indexed winding preserved for Godot")
	_expect(converted.bounds.min == [1.0, 2.0, -9.0], "bounds minimum conversion")
	_expect(converted.bounds.max == [7.0, 8.0, -3.0], "bounds maximum conversion")

func _check_triangle_soup_conversion() -> void:
	var converted := AdapterScript.expected_mesh_for_comparison({
		"mesh": {
			"vertex_count": 3,
			"layout": {},
			"attributes": {
				"position": _attribute(3, "Position", [10.0, 0.0, 0.0, 20.0, 0.0, 0.0, 30.0, 0.0, 0.0]),
				"color": _attribute(4, "Unspecified", [1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0]),
			},
			"triangles": [0, 1, 2],
		},
	})
	_expect(converted.triangles == [0, 1, 2], "triangle-soup indices remain sequential")
	_expect(converted.vertices == [[1.0, 0.0, 0.0], [2.0, 0.0, 0.0], [3.0, 0.0, 0.0]], "triangle-soup record order preserved for Godot")
	_expect(converted.colors == [[1.0, 0.0, 0.0, 1.0], [0.0, 1.0, 0.0, 1.0], [0.0, 0.0, 1.0, 1.0]], "triangle-soup channels stay aligned")

func _attribute(item_size: int, semantic: String, data: Array) -> Dictionary:
	return {"itemSize": item_size, "semantic": semantic, "componentType": "float32", "data": data}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("OpenBrushMeshFixtureAdapterTest: %s" % message)
