extends SceneTree

const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"
const TILT_SCENE_BUILDER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_scene_builder.gd"
const SAMPLE_TILT_PATH := "res://Temp/TiltEvidence/brush_cafe_experimental.tilt"

func _init() -> void:
	var reader_script := load(TILT_READER_PATH)
	var builder_script := load(TILT_SCENE_BUILDER_PATH)
	if reader_script == null or builder_script == null:
		push_error("CAFE_FIXTURE_CANDIDATE: missing tilt reader or scene builder")
		quit(1)
		return

	var tilt_data: Dictionary = reader_script.new().load_tilt(SAMPLE_TILT_PATH)
	var error := String(tilt_data.get("error", ""))
	if not error.is_empty():
		push_error("CAFE_FIXTURE_CANDIDATE: %s" % error)
		quit(1)
		return

	var builder = builder_script.new()
	var manifest: TiltBrushManifest = builder._ensure_runtime_manifest()
	if manifest == null:
		push_error("CAFE_FIXTURE_CANDIDATE: runtime manifest unavailable")
		quit(1)
		return

	var seen := {}
	var scene_scale: float = builder._scene_scale_from_metadata(tilt_data.get("metadata", {}))
	var strokes: Array = tilt_data.get("strokes", [])
	for index in range(strokes.size()):
		var stroke: Dictionary = strokes[index]
		var desc: BrushDescriptor = builder._resolve_stroke_descriptor(stroke)
		if desc == null:
			continue
		if builder._BrushRuntimeRegistry.is_compatibility_brush(manifest, desc):
			continue
		if not builder._BrushRuntimeRegistry.is_supported(desc):
			continue
		var runtime_class := _runtime_class_for_descriptor(builder, desc)
		var key := "%s:%s" % [runtime_class, String(desc.prefab_fields.get("prefab_name", ""))]
		if seen.has(key):
			continue
		seen[key] = true
		var control_points: Array = stroke.get("control_points", [])
		var bounds := _bounds(control_points, scene_scale)
		print("CAFE_FIXTURE_CANDIDATE\tindex=%d\tbrush=%s\tguid=%s\tprefab=%s\truntime=%s\tcp=%d\tbrush_size=%.9f\tbrush_scale=%.9f\tscene_scale=%.9f\tbounds_min=%s\tbounds_max=%s" % [
			index,
			desc.m_DurableName,
			String(stroke.get("brush_guid", "")),
			String(desc.prefab_fields.get("prefab_name", "")),
			runtime_class,
			control_points.size(),
			float(stroke.get("brush_size", 0.0)),
			float(stroke.get("brush_scale", 1.0)),
			scene_scale,
			bounds["min"],
			bounds["max"],
		])
	quit(0)

func _runtime_class_for_descriptor(builder, desc: BrushDescriptor) -> String:
	var brush: BaseBrushScript = builder._BrushRuntimeRegistry.create_brush_for_descriptor(desc)
	if brush == null:
		return "<none>"
	var runtime_name: String = brush.get_script().get_global_name()
	brush.free()
	return runtime_name

func _bounds(control_points: Array, scene_scale: float) -> Dictionary:
	var result := {"valid": false, "min": Vector3.ZERO, "max": Vector3.ZERO}
	for control_point in control_points:
		if not control_point is Dictionary:
			continue
		var position: Vector3 = control_point.get("position", Vector3.ZERO) * scene_scale
		if not result.valid:
			result.valid = true
			result.min = position
			result.max = position
		else:
			result.min = result.min.min(position)
			result.max = result.max.max(position)
	return {"min": result.min, "max": result.max}
