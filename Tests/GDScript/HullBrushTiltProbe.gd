extends SceneTree

const TILT_READER_PATH := "res://addons/icosa/open_brush/open_brush_tilt_reader.gd"
const OPEN_BRUSH_PATH := "res://addons/icosa/open_brush/open_brush.gd"
const OUTPUT_LOG := "user://hull_brush_tilt_probe.log"

var _log_file: FileAccess
var _descriptor_cache := {}
var _logged_descriptors := {}
var _detail_write_failures := 0

func _init() -> void:
	_log_file = FileAccess.open(OUTPUT_LOG, FileAccess.WRITE)
	var args := OS.get_cmdline_user_args()
	var tilt_path := "res://Temp/TiltEvidence/brush_cafe_experimental.tilt"
	var max_strokes := 5
	var skip_strokes := 0
	var detail_hull_index := 0
	var detail_output := ""
	var detail_indices := {}
	var detail_output_prefix := ""
	var concave_window_exports := 1
	for arg in args:
		if arg.begins_with("--tilt="):
			tilt_path = arg.trim_prefix("--tilt=")
		elif arg.begins_with("--max-hull-strokes="):
			max_strokes = int(arg.trim_prefix("--max-hull-strokes="))
		elif arg.begins_with("--skip-hull-strokes="):
			skip_strokes = int(arg.trim_prefix("--skip-hull-strokes="))
		elif arg.begins_with("--detail-hull-index="):
			detail_hull_index = int(arg.trim_prefix("--detail-hull-index="))
		elif arg.begins_with("--detail-output="):
			detail_output = arg.trim_prefix("--detail-output=")
		elif arg.begins_with("--detail-hull-indices="):
			for value in arg.trim_prefix("--detail-hull-indices=").split(",", false):
				detail_indices[int(value.strip_edges())] = true
		elif arg.begins_with("--detail-output-prefix="):
			detail_output_prefix = arg.trim_prefix("--detail-output-prefix=")
		elif arg.begins_with("--concave-window-exports="):
			concave_window_exports = maxi(1, int(arg.trim_prefix("--concave-window-exports=")))

	if detail_hull_index != 0:
		detail_indices[detail_hull_index] = true
	_run(tilt_path, max_strokes, skip_strokes, detail_indices, detail_output, detail_output_prefix, concave_window_exports)


func _run(tilt_path: String, max_strokes: int, skip_strokes: int, detail_indices: Dictionary, detail_output: String, detail_output_prefix: String, concave_window_exports: int) -> void:
	_log("HULL_TILT_PROBE: tilt=%s max_hull_strokes=%d skip_hull_strokes=%d detail_hull_indices=%s" % [tilt_path, max_strokes, skip_strokes, str(detail_indices.keys())])
	var reader_script := load(TILT_READER_PATH)
	var open_brush_script := load(OPEN_BRUSH_PATH)
	if reader_script == null or open_brush_script == null:
		_fail("HULL_TILT_PROBE: missing Icosa scripts")
		return

	var data: Dictionary = reader_script.new().load_tilt(tilt_path)
	var error := String(data.get("error", ""))
	if not error.is_empty():
		_fail("HULL_TILT_PROBE: reader error: %s" % error)
		return

	var scene_scale := _scene_scale(data.get("metadata", {}))
	var ob = open_brush_script.new()
	ob.ensure_loaded()

	var hull_seen := 0
	var hull_built := 0
	var start_total := Time.get_ticks_msec()
	for stroke in data.get("strokes", []):
		if not stroke is Dictionary:
			continue
		var brush_name: String = ob.resolve_brush_name(stroke.get("brush_guid", ""))
		if not brush_name.ends_with("Hull"):
			continue
		hull_seen += 1
		if hull_seen <= skip_strokes:
			continue
		if hull_built >= max_strokes:
			continue
		var descriptor := _load_brush_descriptor(brush_name)
		if descriptor == null:
			_log("HULL_TILT_PROBE: skip missing descriptor brush=%s" % brush_name)
			continue
		var built := _build_hull_stroke(stroke, descriptor, scene_scale, brush_name, hull_seen, detail_indices.has(hull_seen), _detail_output_for(hull_seen, detail_output, detail_output_prefix), concave_window_exports)
		if built:
			hull_built += 1

	var elapsed := Time.get_ticks_msec() - start_total
	_log("HULL_TILT_PROBE: hull_seen=%d hull_built=%d elapsed_ms=%d" % [hull_seen, hull_built, elapsed])
	var exit_code := 0
	if _detail_write_failures > 0:
		_log("HULL_TILT_PROBE: detail_write_failures=%d" % _detail_write_failures)
		exit_code = 1
	_close_log()
	quit(exit_code)


func _build_hull_stroke(stroke: Dictionary, descriptor: BrushDescriptor, scene_scale: float, brush_name: String, hull_index: int, detail: bool, detail_output: String, concave_window_exports: int) -> bool:
	var control_points: Array = stroke.get("control_points", [])
	if control_points.size() < 2:
		return false

	var first_cp: Dictionary = control_points[0]
	var first_pos: Vector3 = first_cp.get("position", Vector3.ZERO) * scene_scale
	var first_orientation: Quaternion = first_cp.get("orientation", Quaternion.IDENTITY)
	var first_pressure := float(first_cp.get("pressure", 1.0))
	var stroke_scale := float(stroke.get("brush_scale", 1.0)) * scene_scale
	if not _logged_descriptors.has(brush_name):
		_logged_descriptors[brush_name] = true
		_log("HULL_TILT_PROBE: descriptor brush=%s prefab=%s fields=%s" % [
			brush_name,
			str(descriptor.prefab_fields.get("prefab_name", "")),
			str(descriptor.prefab_fields),
		])

	var brush = ConcaveHullBrush.new() if brush_name == "ConcaveHull" else HullBrush.new()
	brush.m_BaseSize_PS = float(stroke.get("brush_size", 0.01))
	brush.m_Color = stroke.get("color", Color.WHITE)
	brush.m_Faceted = bool(descriptor.prefab_fields.get("m_Faceted", brush.m_Faceted))
	if brush_name != "ConcaveHull":
		brush.m_TrackInterior = bool(descriptor.prefab_fields.get("m_TrackInterior", brush.m_TrackInterior))
		brush.m_Simplification_PS = float(descriptor.prefab_fields.get("m_Simplification_PS", brush.m_Simplification_PS))
		brush.m_SimplifyMode = int(descriptor.prefab_fields.get("m_SimplifyMode", brush.m_SimplifyMode))
	else:
		brush.m_KnotsInHull = int(descriptor.prefab_fields.get("m_KnotsInHull", brush.m_KnotsInHull))
	brush.m_KnotConversion = int(descriptor.prefab_fields.get("m_KnotConversion", brush.m_KnotConversion))
	brush.set_random_seed(int(stroke.get("seed", 0)))
	brush.init_brush(descriptor, TrTransform.trs(first_pos, first_orientation, stroke_scale))
	brush.set_random_seed(int(stroke.get("seed", 0)))

	var start_ms := Time.get_ticks_msec()
	var kept_points := 0
	for i in range(1, control_points.size()):
		var cp: Dictionary = control_points[i]
		var position: Vector3 = cp.get("position", Vector3.ZERO) * scene_scale
		var orientation: Quaternion = cp.get("orientation", Quaternion.IDENTITY)
		var pressure := float(cp.get("pressure", first_pressure))
		if brush.update_position_ls(TrTransform.trs(position, orientation, stroke_scale), pressure):
			kept_points += 1

	brush.apply_changes_to_visuals()
	if detail:
		if brush is HullBrush:
			_log_hull_detail(brush, control_points, scene_scale, hull_index)
		elif brush is ConcaveHullBrush:
			_log_concave_hull_detail(brush, hull_index)
		if not detail_output.is_empty():
			if brush is HullBrush:
				_write_hull_input_csv(brush, detail_output)
			elif brush is ConcaveHullBrush:
				_write_concave_window_input_csvs(brush, detail_output, concave_window_exports)
	brush.finalize_solitary_brush()
	var elapsed := Time.get_ticks_msec() - start_ms
	_log("HULL_TILT_PROBE: built hull_index=%d brush=%s cps=%d kept=%d brush_size=%f brush_scale=%f scene_scale=%f conversion=%d input_points=%d faceted=%s verts=%d tris=%d elapsed_ms=%d" % [
		hull_index,
		brush_name,
		control_points.size(),
		kept_points,
		float(stroke.get("brush_size", 0.01)),
		float(stroke.get("brush_scale", 1.0)),
		scene_scale,
		brush.m_KnotConversion,
		brush.m_LastHullInputCount if brush is HullBrush else brush.m_AllVertices.size(),
		str(brush.m_Faceted),
		brush.mesh_data.vertices.size(),
		brush.mesh_data.triangles.size() / 3,
		elapsed,
	])
	brush.free()
	return true


func _detail_output_for(hull_index: int, detail_output: String, detail_output_prefix: String) -> String:
	if not detail_output_prefix.is_empty():
		return "%s_%03d.csv" % [detail_output_prefix, hull_index]
	return detail_output


func _write_hull_input_csv(brush: HullBrush, output_path: String) -> void:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_log("HULL_TILT_DETAIL: failed to write detail_output=%s error=%d" % [output_path, FileAccess.get_open_error()])
		_detail_write_failures += 1
		return
	file.store_line("x,y,z")
	for point in _hull_input_positions(brush):
		file.store_line("%.9f,%.9f,%.9f" % [point.x, point.y, point.z])
	file.close()
	_log("HULL_TILT_DETAIL: wrote detail_output=%s points=%d" % [output_path, brush.m_LastHullInputCount])


func _hull_input_positions(brush: HullBrush) -> Array[Vector3]:
	var input: Array[Vector3] = []
	var input_vertex_count := brush.m_AllVertices.size()
	if brush.m_TrackInterior and brush.m_knots.size() >= 2:
		var last := brush.m_knots.size() - 1
		if brush.m_knots[last].point.m_Pos == brush.m_knots[last - 1].point.m_Pos:
			input_vertex_count = maxi(0, input_vertex_count - brush.get_num_vertices_per_knot())
	for vertex_index in range(input_vertex_count):
		var vertex: Dictionary = brush.m_AllVertices[vertex_index]
		if not bool(vertex.interior):
			input.append(vertex.position)
	return input


func _write_concave_window_input_csvs(brush: ConcaveHullBrush, output_path: String, window_exports: int) -> void:
	for export_offset in range(window_exports):
		var knot_range1 := brush.m_knots.size() - export_offset
		if knot_range1 <= 0:
			return
		var path := output_path
		if window_exports > 1:
			path = output_path.get_basename() + "_window_%03d.csv" % knot_range1
		_write_concave_window_input_csv(brush, path, knot_range1)


func _write_concave_window_input_csv(brush: ConcaveHullBrush, output_path: String, knot_range1: int) -> void:
	var vertices_per_knot := brush.get_num_vertices_per_knot()
	var knots_in_hull := maxi(brush.m_KnotsInHull, 1)
	var knot_range0 := maxi(0, knot_range1 - knots_in_hull)
	var vertex_start := vertices_per_knot * knot_range0
	var vertex_end := vertices_per_knot * knot_range1
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_log("HULL_TILT_DETAIL: failed to write concave detail_output=%s error=%d" % [output_path, FileAccess.get_open_error()])
		_detail_write_failures += 1
		return
	file.store_line("x,y,z")
	for vertex_index in range(vertex_start, vertex_end):
		var point: Vector3 = brush.m_AllVertices[vertex_index]
		file.store_line("%.9f,%.9f,%.9f" % [point.x, point.y, point.z])
	file.close()
	_log("HULL_TILT_DETAIL: wrote concave detail_output=%s points=%d knot_range=[%d,%d)" % [
		output_path,
		vertex_end - vertex_start,
		knot_range0,
		knot_range1,
	])


func _log_concave_hull_detail(brush: ConcaveHullBrush, hull_index: int) -> void:
	var vertices_per_knot := brush.get_num_vertices_per_knot()
	var knots_in_hull := maxi(brush.m_KnotsInHull, 1)
	var knot_range1 := brush.m_knots.size()
	var knot_range0 := maxi(0, knot_range1 - knots_in_hull)
	var input_count := vertices_per_knot * (knot_range1 - knot_range0)
	_log("HULL_TILT_DETAIL: hull_index=%d concave_window knot_range=[%d,%d) input=%d vertices_per_knot=%d tolerance=%0.12f" % [
		hull_index,
		knot_range0,
		knot_range1,
		input_count,
		vertices_per_knot,
		ConcaveHullBrush.K_TOLERANCE_METERS_PS * App.METERS_TO_UNITS * brush.pointer_to_local(),
	])


func _log_hull_detail(brush: HullBrush, control_points: Array, scene_scale: float, hull_index: int) -> void:
	var plane := _control_point_plane(control_points, scene_scale)
	var normal: Vector3 = plane.normal
	var origin: Vector3 = plane.origin
	var cp_range := _signed_distance_range(_scaled_control_points(control_points, scene_scale), origin, normal)
	var input_positions: Array[Vector3] = []
	for position in _hull_input_positions(brush):
		input_positions.append(position)
	var input_range := _signed_distance_range(input_positions, origin, normal)
	var mesh_range := _signed_distance_range(brush.m_geometry.m_Vertices, origin, normal)
	var surface_dot_min := 1.0
	var surface_dot_max := -1.0
	var right_dot_min := 1.0
	var right_dot_max := -1.0
	for knot in brush.m_knots:
		if knot.nSurface.length_squared() > 1e-12:
			var surface_dot := knot.nSurface.normalized().dot(normal)
			surface_dot_min = minf(surface_dot_min, surface_dot)
			surface_dot_max = maxf(surface_dot_max, surface_dot)
		if knot.nRight.length_squared() > 1e-12:
			var right_dot := knot.nRight.normalized().dot(normal)
			right_dot_min = minf(right_dot_min, right_dot)
			right_dot_max = maxf(right_dot_max, right_dot)
	var face_dot_min := 1.0
	var face_dot_max := -1.0
	for normal_value in brush.m_geometry.m_Normals:
		if normal_value.length_squared() > 1e-12:
			var face_dot := normal_value.normalized().dot(normal)
			face_dot_min = minf(face_dot_min, face_dot)
			face_dot_max = maxf(face_dot_max, face_dot)
	_log("HULL_TILT_DETAIL: hull_index=%d plane_origin=%s plane_normal=%s cp_dist=[%f,%f] input_dist=[%f,%f] mesh_dist=[%f,%f]" % [
		hull_index,
		str(origin),
		str(normal),
		cp_range.x,
		cp_range.y,
		input_range.x,
		input_range.y,
		mesh_range.x,
		mesh_range.y,
	])
	_log("HULL_TILT_DETAIL: hull_index=%d tolerance=%0.12f" % [
		hull_index,
		HullBrush.K_TOLERANCE_METERS_PS * App.METERS_TO_UNITS * brush.pointer_to_local(),
	])
	_log("HULL_TILT_DETAIL: hull_index=%d surface_dot=[%f,%f] right_dot=[%f,%f] face_dot=[%f,%f] knots=%d input=%d verts=%d tris=%d" % [
		hull_index,
		surface_dot_min,
		surface_dot_max,
		right_dot_min,
		right_dot_max,
		face_dot_min,
		face_dot_max,
		brush.m_knots.size(),
		brush.m_LastHullInputCount,
		brush.m_geometry.m_Vertices.size(),
		brush.m_geometry.m_Tris.size() / 3,
	])


func _scaled_control_points(control_points: Array, scene_scale: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for cp in control_points:
		result.append(cp.get("position", Vector3.ZERO) * scene_scale)
	return result


func _control_point_plane(control_points: Array, scene_scale: float) -> Dictionary:
	var points := _scaled_control_points(control_points, scene_scale)
	var origin := points[0] if not points.is_empty() else Vector3.ZERO
	var axis0 := Vector3.ZERO
	for point in points:
		if point.distance_squared_to(origin) > axis0.length_squared():
			axis0 = point - origin
	var normal := Vector3.UP
	var best_area := 0.0
	for point in points:
		var candidate := axis0.cross(point - origin)
		var area := candidate.length_squared()
		if area > best_area:
			best_area = area
			normal = candidate.normalized()
	if normal.length_squared() <= 1e-12:
		normal = Vector3.UP
	return {"origin": origin, "normal": normal}


func _signed_distance_range(points: Array, origin: Vector3, normal: Vector3) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var min_distance := INF
	var max_distance := -INF
	for point in points:
		var distance := normal.dot(point - origin)
		min_distance = minf(min_distance, distance)
		max_distance = maxf(max_distance, distance)
	return Vector2(min_distance, max_distance)


func _load_brush_descriptor(brush_name: String) -> BrushDescriptor:
	if _descriptor_cache.has(brush_name):
		return _descriptor_cache[brush_name]
	var project_path := ProjectSettings.globalize_path("res://")
	var candidates := [
		project_path.path_join("Resources").path_join("Brushes").path_join("Basic").path_join(brush_name).path_join("%s.asset" % brush_name),
		project_path.path_join("Resources").path_join("X").path_join("Brushes").path_join(brush_name).path_join("%s.asset" % brush_name),
	]
	for path in candidates:
		var descriptor := UnityAssetLoader.load_brush_descriptor(path)
		if descriptor != null:
			_descriptor_cache[brush_name] = descriptor
			return descriptor
	_descriptor_cache[brush_name] = null
	return null


func _scene_scale(metadata: Dictionary) -> float:
	var scene_xf: Array = metadata.get("SceneTransformInRoomSpace", [])
	if scene_xf.size() >= 3:
		var scale := float(scene_xf[2])
		if scale > 0.0:
			return scale
	return 1.0


func _log(message: String) -> void:
	print(message)
	if _log_file != null:
		_log_file.store_line(message)
		_log_file.flush()


func _fail(message: String) -> void:
	_log(message)
	_close_log()
	push_error(message)
	quit(1)


func _close_log() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null
