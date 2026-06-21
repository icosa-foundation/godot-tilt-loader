extends SceneTree

const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"
const TILT_SCENE_BUILDER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_scene_builder.gd"
const TILT_STROKE_BRIDGE_PATH := "res://addons/open_brush_stroke_integration/open_brush_stroke_bridge.gd"
const SAMPLE_TILT_PATH := "res://Temp/TiltEvidence/brush_cafe_experimental.tilt"

var _failures := 0

func _init() -> void:
	_check_bridge_replay_matches_tilt_builder()
	quit(1 if _failures > 0 else 0)

func _check_bridge_replay_matches_tilt_builder() -> void:
	var reader_script := load(TILT_READER_PATH)
	var builder_script := load(TILT_SCENE_BUILDER_PATH)
	var bridge_script := load(TILT_STROKE_BRIDGE_PATH)
	_expect(reader_script != null, "tilt reader loads")
	_expect(builder_script != null, "tilt scene builder loads")
	_expect(bridge_script != null, "stroke bridge loads")
	if reader_script == null or builder_script == null or bridge_script == null:
		return

	var tilt_data: Dictionary = reader_script.new().load_tilt(SAMPLE_TILT_PATH)
	_expect(String(tilt_data.get("error", "")).is_empty(), "sample tilt loads")
	var builder = builder_script.new()
	var manifest: TiltBrushManifest = builder._ensure_runtime_manifest()
	_expect(manifest != null, "runtime manifest loads")
	if manifest == null:
		return
	var scene_scale: float = builder._scene_scale_from_metadata(tilt_data.get("metadata", {}))
	var bridge = bridge_script.new()
	var canvas := CanvasScript.new()
	var pointer := PointerScript.new()
	get_root().add_child(canvas)

	var checked := 0
	for stroke_value in tilt_data.get("strokes", []):
		var stroke_dict: Dictionary = stroke_value
		var desc: BrushDescriptor = builder._resolve_stroke_descriptor(stroke_dict)
		if desc == null:
			continue
		if builder._BrushRuntimeRegistry.is_compatibility_brush(manifest, desc):
			continue
		if not builder._BrushRuntimeRegistry.is_supported(desc):
			continue
		var direct: MeshData = builder._build_runtime_mesh_data(desc, stroke_dict, scene_scale, checked)
		if direct == null or direct.is_empty():
			continue
		var stroke: Stroke = bridge.stroke_from_icosa_stroke(stroke_dict, canvas, scene_scale)
		_expect(stroke != null, "bridge creates stroke")
		if stroke == null:
			continue
		pointer.recreate_line_from_memory(stroke)
		var replay := MeshData.new()
		replay.copy_from((stroke.m_Object as BaseBrushScript).mesh_data)
		_compare_meshes("stroke %d %s scene_scale=%.6f" % [checked, desc.m_DurableName, scene_scale], direct, replay)
		checked += 1
		if checked >= 8:
			break
	_expect(checked > 0, "checked at least one runtime stroke")
	canvas.queue_free()
	pointer.free()

func _compare_meshes(label: String, direct: MeshData, replay: MeshData) -> void:
	var direct_arrays := direct.to_mesh_arrays()
	var replay_arrays := replay.to_mesh_arrays()
	var direct_vertices: PackedVector3Array = direct_arrays[Mesh.ARRAY_VERTEX]
	var replay_vertices: PackedVector3Array = replay_arrays[Mesh.ARRAY_VERTEX]
	var direct_uv: PackedVector2Array = direct_arrays[Mesh.ARRAY_TEX_UV]
	var replay_uv: PackedVector2Array = replay_arrays[Mesh.ARRAY_TEX_UV]
	print("TILT_BRIDGE_REPLAY\t%s\tverts=%d/%d\tuvs=%d/%d" % [
		label,
		direct_vertices.size(),
		replay_vertices.size(),
		direct_uv.size(),
		replay_uv.size(),
	])
	_expect_equal(replay_vertices.size(), direct_vertices.size(), "%s vertex count" % label)
	_expect_equal(replay_uv.size(), direct_uv.size(), "%s uv count" % label)
	var vertex_count := mini(direct_vertices.size(), replay_vertices.size())
	var max_vertex_delta := 0.0
	for index in range(vertex_count):
		max_vertex_delta = maxf(max_vertex_delta, direct_vertices[index].distance_to(replay_vertices[index]))
	var uv_count := mini(direct_uv.size(), replay_uv.size())
	var max_uv_delta := 0.0
	for index in range(uv_count):
		max_uv_delta = maxf(max_uv_delta, direct_uv[index].distance_to(replay_uv[index]))
	print("TILT_BRIDGE_REPLAY\t%s\tmax_vertex_delta=%.8f\tmax_uv_delta=%.8f" % [label, max_vertex_delta, max_uv_delta])
	_expect(max_vertex_delta < 0.00001, "%s vertex delta %.8f" % [label, max_vertex_delta])
	_expect(max_uv_delta < 0.00001, "%s uv delta %.8f" % [label, max_uv_delta])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("TiltBridgeReplayParityTest: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("TiltBridgeReplayParityTest: %s expected %s but got %s" % [message, expected, actual])
