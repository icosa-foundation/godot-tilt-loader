extends SceneTree

const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"
const OPEN_BRUSH_PATH := "res://addons/icosa/open_brush/open_brush.gd"
const SAMPLE_TILT_PATH := "res://Resources/Fixtures/brush_cafe_experimental.tilt"

func _init() -> void:
	var reader_script := load(TILT_READER_PATH)
	var open_brush_script := load(OPEN_BRUSH_PATH)
	var tilt_data: Dictionary = reader_script.new().load_tilt(SAMPLE_TILT_PATH)
	var ob = open_brush_script.new()
	ob.ensure_loaded()
	var scene_scale := _scene_scale(tilt_data.get("metadata", {}))
	var ink_strokes := _find_ink_strokes(tilt_data.get("strokes", []), ob)
	print("CAFE_INK_COMPARE\tcafe_ink_count=%d\tscene_scale=%.9f" % [ink_strokes.size(), scene_scale])
	for index in range(mini(3, ink_strokes.size())):
		var entry: Dictionary = ink_strokes[index]
		_print_stroke("CAFE_INK_%d" % index, entry.stroke, entry.source_index, scene_scale, ob)
	if ink_strokes.size() > 1:
		var selected: Dictionary = ink_strokes[1]
		_print_stroke("SCENE_REFERENCE", selected.stroke, selected.source_index, scene_scale, ob)
	quit(0)

func _find_ink_strokes(strokes: Array, ob) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for index in range(strokes.size()):
		var stroke = strokes[index]
		if not stroke is Dictionary:
			continue
		var guid := String(stroke.get("brush_guid", ""))
		var name: String = ob.resolve_brush_name(guid)
		if name == "Ink":
			output.append({"stroke": stroke, "source_index": index})
	return output

func _print_stroke(label: String, stroke: Dictionary, source_index: int, scene_scale: float, ob) -> void:
	var guid := String(stroke.get("brush_guid", ""))
	var cps: Array = stroke.get("control_points", [])
	var bounds := _bounds(cps, 1.0)
	var scaled_bounds := _bounds(cps, scene_scale)
	print("%s\tindex=%d\tguid=%s\tname=%s\tbrush_size=%.9f\tbrush_scale=%.9f\tscene_scale=%.9f\tcp=%d" % [
		label,
		source_index,
		guid,
		ob.resolve_brush_name(guid),
		float(stroke.get("brush_size", 0.0)),
		float(stroke.get("brush_scale", 1.0)),
		scene_scale,
		cps.size(),
	])
	print("%s\tbounds_min=%s\tbounds_max=%s\tscaled_min=%s\tscaled_max=%s" % [
		label,
		bounds.min,
		bounds.max,
		scaled_bounds.min,
		scaled_bounds.max,
	])
	for cp_index in range(mini(5, cps.size())):
		var cp: Dictionary = cps[cp_index]
		print("%s\tcp%d\tpos=%s\tscaled_pos=%s\torient=%s\tpressure=%.6f\ttimestamp=%s" % [
			label,
			cp_index,
			cp.get("position", Vector3.ZERO),
			cp.get("position", Vector3.ZERO) * scene_scale,
			cp.get("orientation", Quaternion.IDENTITY),
			float(cp.get("pressure", 1.0)),
			str(cp.get("timestamp", cp.get("timestamp_ms", ""))),
		])
	_print_step_stats(label, cps, scene_scale)

func _print_step_stats(label: String, cps: Array, scale: float) -> void:
	if cps.size() < 2:
		return
	var min_step := INF
	var max_step := 0.0
	var total := 0.0
	for index in range(1, cps.size()):
		var previous: Vector3 = cps[index - 1].get("position", Vector3.ZERO) * scale
		var current: Vector3 = cps[index].get("position", Vector3.ZERO) * scale
		var step := previous.distance_to(current)
		min_step = minf(min_step, step)
		max_step = maxf(max_step, step)
		total += step
	print("%s\tstep_min=%.9f\tstep_avg=%.9f\tstep_max=%.9f\tpath_len=%.9f" % [
		label,
		min_step,
		total / float(cps.size() - 1),
		max_step,
		total,
	])

func _bounds(cps: Array, scale: float) -> Dictionary:
	var result := {"valid": false, "min": Vector3.ZERO, "max": Vector3.ZERO}
	for cp in cps:
		if not cp is Dictionary:
			continue
		var position: Vector3 = cp.get("position", Vector3.ZERO) * scale
		if not result.valid:
			result.valid = true
			result.min = position
			result.max = position
		else:
			result.min = result.min.min(position)
			result.max = result.max.max(position)
	return result

func _scene_scale(metadata: Dictionary) -> float:
	var scene_xf: Array = metadata.get("SceneTransformInRoomSpace", [])
	if scene_xf.size() >= 3:
		return float(scene_xf[2])
	return 1.0
