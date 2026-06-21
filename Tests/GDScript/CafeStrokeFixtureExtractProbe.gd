extends SceneTree

const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"
const SAMPLE_TILT_PATH := "res://Temp/TiltEvidence/brush_cafe_experimental.tilt"
const SOURCE_STROKE_INDEX := 150

func _init() -> void:
	var source_stroke_index := SOURCE_STROKE_INDEX
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source-stroke-index="):
			source_stroke_index = int(arg.trim_prefix("--source-stroke-index="))
	var reader_script := load(TILT_READER_PATH)
	var tilt_data: Dictionary = reader_script.new().load_tilt(SAMPLE_TILT_PATH)
	var strokes: Array = tilt_data.get("strokes", [])
	if source_stroke_index >= strokes.size():
		push_error("CAFE_STROKE_FIXTURE_EXTRACT: source stroke index out of range")
		quit(1)
		return
	var metadata: Dictionary = tilt_data.get("metadata", {})
	var stroke: Dictionary = strokes[source_stroke_index]
	var fixture := {
		"source_tilt": SAMPLE_TILT_PATH,
		"source_stroke_index": source_stroke_index,
		"scene_scale": _scene_scale(metadata),
		"brush_guid": String(stroke.get("brush_guid", "")),
		"brush_size": float(stroke.get("brush_size", 0.0)),
		"brush_scale": float(stroke.get("brush_scale", 1.0)),
		"seed": int(stroke.get("seed", stroke.get("random_seed", 0))),
		"color": _color_array(stroke.get("color", Color.WHITE)),
		"control_points": _control_points(stroke.get("control_points", [])),
	}
	print("CAFE_STROKE_FIXTURE_EXTRACT_BEGIN")
	print(JSON.stringify(fixture, "\t"))
	print("CAFE_STROKE_FIXTURE_EXTRACT_END")
	quit(0)

func _control_points(points: Array) -> Array:
	var output := []
	for value in points:
		if not value is Dictionary:
			continue
		var point: Dictionary = value
		output.append({
			"position": _vec3_array(point.get("position", Vector3.ZERO)),
			"orientation": _quat_array(point.get("orientation", Quaternion.IDENTITY)),
			"pressure": float(point.get("pressure", 1.0)),
			"timestamp": int(point.get("timestamp", point.get("timestamp_ms", 0))),
		})
	return output

func _scene_scale(metadata: Dictionary) -> float:
	var scene_xf: Array = metadata.get("SceneTransformInRoomSpace", [])
	if scene_xf.size() >= 3:
		return float(scene_xf[2])
	return 1.0

func _vec3_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _quat_array(value: Quaternion) -> Array:
	return [value.x, value.y, value.z, value.w]

func _color_array(value: Variant) -> Array:
	var color := Color.WHITE
	if value is Color:
		color = value
	return [color.r, color.g, color.b, color.a]
