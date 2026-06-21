extends SceneTree

const BridgeScript = preload("res://addons/open_brush_stroke_integration/open_brush_stroke_bridge.gd")

var _failures := 0

func _init() -> void:
	var bridge := BridgeScript.new()
	var tilt_data := {
		"metadata": {
			"SceneTransformInRoomSpace": [Vector3.ZERO, Quaternion.IDENTITY, 0.5],
		},
		"strokes": [
			{
				"brush_guid": "f5c336cf-5108-4b40-ade9-c687504385ab",
				"brush_size": 2.0,
				"color": Color(0.25, 0.5, 0.75, 1.0),
				"control_points": [
					{
						"position": Vector3(2.0, 4.0, 6.0),
						"orientation": Quaternion.IDENTITY,
						"pressure": 0.5,
						"timestamp": 10,
					},
					{
						"position": Vector3(4.0, 6.0, 8.0),
						"orientation": Quaternion(Vector3.UP, PI * 0.5),
						"pressure": 0.75,
						"timestamp": 20,
					},
				],
			},
		],
	}

	var strokes: Array[Stroke] = bridge.convert_tilt_data_to_strokes(tilt_data)
	_expect_equal(strokes.size(), 1, "bridge creates one stroke")
	var stroke: Stroke = strokes[0]
	_expect_equal(stroke.m_Type, Stroke.Type.NOT_CREATED, "stroke starts as memory stroke")
	_expect_equal(stroke.m_BrushGuid, "f5c336cf-5108-4b40-ade9-c687504385ab", "brush guid preserved")
	_expect_close(stroke.m_BrushScale, 0.5, "brush scale carries scene scale")
	_expect_close(stroke.m_BrushSize, 2.0, "brush size remains in pointer space")
	_expect_equal(stroke.m_Color, Color(0.25, 0.5, 0.75, 1.0), "color preserved")
	_expect_equal(stroke.m_ControlPoints.size(), 2, "control point count")
	_expect_equal(stroke.m_ControlPointsToDrop, [false, false], "drop flags initialized")
	_expect_vec3_close(stroke.m_ControlPoints[0].m_Pos, Vector3(1.0, 2.0, 3.0), "first position scene scaled")
	_expect_close(stroke.m_ControlPoints[0].m_Pressure, 0.5, "pressure preserved")
	_expect_equal(stroke.m_ControlPoints[1].m_TimestampMs, 20, "timestamp preserved")
	if _failures == 0:
		print("GDSCRIPT_ICOSA_BRIDGE: all checks passed")
	quit(1 if _failures > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failures += 1

func _expect_equal(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s: expected %s got %s" % [message, expected, actual])

func _expect_close(actual: float, expected: float, message: String, epsilon: float = 0.00001) -> void:
	_expect(absf(actual - expected) <= epsilon, "%s: expected %.6f got %.6f" % [message, expected, actual])

func _expect_vec3_close(actual: Vector3, expected: Vector3, message: String, epsilon: float = 0.00001) -> void:
	_expect(actual.distance_to(expected) <= epsilon, "%s: expected %s got %s" % [message, expected, actual])
