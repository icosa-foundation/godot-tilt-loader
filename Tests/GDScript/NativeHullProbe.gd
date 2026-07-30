extends SceneTree

func _init() -> void:
	load("res://native/open_brush_hull/open_brush_hull.gdextension")
	print("NATIVE_HULL_PROBE: class_exists=%s" % str(ClassDB.class_exists("NativeConvexHullUtil")))
	if not ClassDB.class_exists("NativeConvexHullUtil"):
		quit(1)
		return
	var ci_prefix := OS.get_environment("OPEN_BRUSH_HULL_LOG_PREFIX")
	if ci_prefix.is_empty():
		ci_prefix = "NATIVE_HULL_PROBE"
	print("%s: native_extension_loaded=true" % ci_prefix)
	var util = ClassDB.instantiate("NativeConvexHullUtil")
	if util == null:
		print("NATIVE_HULL_PROBE: instantiate_failed")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var csv_path := ""
	var csv_tolerance := NAN
	var dump_points := false
	var expected_points := -1
	var expected_faces := -1
	var expected_triangles := -1
	for arg in args:
		if arg.begins_with("--csv="):
			csv_path = arg.trim_prefix("--csv=")
		elif arg.begins_with("--tolerance="):
			csv_tolerance = arg.trim_prefix("--tolerance=").to_float()
		elif arg == "--dump-points":
			dump_points = true
		elif arg.begins_with("--expect-points="):
			expected_points = int(arg.trim_prefix("--expect-points="))
		elif arg.begins_with("--expect-faces="):
			expected_faces = int(arg.trim_prefix("--expect-faces="))
		elif arg.begins_with("--expect-triangles="):
			expected_triangles = int(arg.trim_prefix("--expect-triangles="))
	if not csv_path.is_empty():
		if is_nan(csv_tolerance):
			_run_csv_sweep(util, csv_path)
		else:
			_run_csv(util, csv_path, csv_tolerance, dump_points, expected_points, expected_faces, expected_triangles)
		return
	var failures := 0
	var tetra_points := PackedVector3Array([
		Vector3(1.0, 1.0, 1.0),
		Vector3(-1.0, -1.0, 1.0),
		Vector3(-1.0, 1.0, -1.0),
		Vector3(1.0, -1.0, -1.0),
	])
	var result: Dictionary = util.call("create", tetra_points, 1e-5)
	print("NATIVE_HULL_PROBE: ok=%s points=%d faces=%d" % [
		str(result.get("ok", false)),
		result.get("points", []).size(),
		result.get("faces", []).size(),
	])
	if not bool(result.get("ok", false)):
		failures += 1

	var cube_points := PackedVector3Array()
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				cube_points.append(Vector3(x, y, z))
	var cube_result: Dictionary = util.call("create", cube_points, 1e-5)
	print("NATIVE_HULL_PROBE: cube_ok=%s points=%d faces=%d" % [
		str(cube_result.get("ok", false)),
		cube_result.get("points", []).size(),
		cube_result.get("faces", []).size(),
	])
	if not bool(cube_result.get("ok", false)):
		failures += 1
	if cube_result.get("points", []).size() != 8:
		failures += 1
	if cube_result.get("faces", []).size() != 6:
		failures += 1
	for face in cube_result.get("faces", []):
		if face.get("indices", []).size() != 4:
			failures += 1
		var normal: Vector3 = face.get("normal", Vector3.ZERO)
		if not is_equal_approx(normal.length(), 1.0):
			failures += 1
		var indices: Array = face.get("indices", [])
		if indices.size() >= 3:
			var p0: Vector3 = cube_result.points[int(indices[0])]
			var p1: Vector3 = cube_result.points[int(indices[1])]
			var p2: Vector3 = cube_result.points[int(indices[2])]
			if (p1 - p0).cross(p2 - p0).dot(normal) <= 0.0:
				failures += 1
			var center := Vector3.ZERO
			for index in indices:
				center += cube_result.points[int(index)]
			center /= float(indices.size())
			if center.dot(normal) <= 0.0:
				failures += 1

	var coplanar_points := PackedVector3Array([
		Vector3(-1.0, -1.0, 0.0),
		Vector3(1.0, -1.0, 0.0),
		Vector3(1.0, 1.0, 0.0),
		Vector3(-1.0, 1.0, 0.0),
		Vector3.ZERO,
	])
	var coplanar_result: Dictionary = util.call("create", coplanar_points, 1e-5)
	print("NATIVE_HULL_PROBE: coplanar_ok=%s points=%d faces=%d" % [
		str(coplanar_result.get("ok", false)),
		coplanar_result.get("points", []).size(),
		coplanar_result.get("faces", []).size(),
	])
	if bool(coplanar_result.get("ok", false)):
		failures += 1

	quit(1 if failures > 0 else 0)


func _run_csv_sweep(util: Object, csv_path: String) -> void:
	var points := _read_csv_points(csv_path)
	if points.is_empty():
		print("NATIVE_HULL_PROBE: csv_empty path=%s" % csv_path)
		quit(1)
		return
	for tolerance in [1e-12, 1e-9, 1e-7, 0.000001115168, 1e-5, 1e-4, 1e-3]:
		_print_csv_result(util, csv_path, points, tolerance)
	quit(0)


func _run_csv(
	util: Object,
	csv_path: String,
	tolerance: float,
	dump_points: bool,
	expected_points: int,
	expected_faces: int,
	expected_triangles: int
) -> void:
	var points := _read_csv_points(csv_path)
	if points.is_empty():
		print("NATIVE_HULL_PROBE: csv_empty path=%s" % csv_path)
		quit(1)
		return
	var result := _print_csv_result(util, csv_path, points, tolerance)
	if dump_points:
		_dump_result_points(points, result)
	var failures := 0
	if expected_points >= 0 and result.get("points", []).size() != expected_points:
		print("NATIVE_HULL_PROBE: expected_points=%d actual=%d" % [
			expected_points,
			result.get("points", []).size(),
		])
		failures += 1
	if expected_faces >= 0 and result.get("faces", []).size() != expected_faces:
		print("NATIVE_HULL_PROBE: expected_faces=%d actual=%d" % [
			expected_faces,
			result.get("faces", []).size(),
		])
		failures += 1
	if expected_triangles >= 0 and _fan_triangle_count(result.get("faces", [])) != expected_triangles:
		print("NATIVE_HULL_PROBE: expected_triangles=%d actual=%d" % [
			expected_triangles,
			_fan_triangle_count(result.get("faces", [])),
		])
		failures += 1
	quit(1 if failures > 0 else 0)


func _print_csv_result(util: Object, csv_path: String, points: PackedVector3Array, tolerance: float) -> Dictionary:
	var result: Dictionary = util.call("create", points, tolerance)
	print("NATIVE_HULL_PROBE: csv=%s tolerance=%s ok=%s input=%d points=%d faces=%d triangles=%d" % [
		csv_path,
		str(tolerance),
		str(result.get("ok", false)),
		points.size(),
		result.get("points", []).size(),
		result.get("faces", []).size(),
		_fan_triangle_count(result.get("faces", [])),
	])
	return result


func _fan_triangle_count(faces: Array) -> int:
	var triangles := 0
	for face in faces:
		triangles += maxi(0, face.get("indices", []).size() - 2)
	return triangles


func _dump_result_points(input_points: PackedVector3Array, result: Dictionary) -> void:
	var points: Array = result.get("points", [])
	for hull_index in range(points.size()):
		var point: Vector3 = points[hull_index]
		var input_index := _find_input_index(input_points, point)
		print("NATIVE_HULL_PROBE_POINT: hull=%d input=%d point=(%.9f,%.9f,%.9f)" % [
			hull_index,
			input_index,
			point.x,
			point.y,
			point.z,
		])


func _find_input_index(input_points: PackedVector3Array, point: Vector3) -> int:
	var best_index := -1
	var best_distance := INF
	for index in range(input_points.size()):
		var distance := input_points[index].distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


func _read_csv_points(csv_path: String) -> PackedVector3Array:
	var file := FileAccess.open(csv_path, FileAccess.READ)
	var points := PackedVector3Array()
	if file == null:
		return points
	var first := true
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if first:
			first = false
			continue
		if line.is_empty():
			continue
		var parts := line.split(",", false)
		if parts.size() != 3:
			continue
		points.append(Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float()))
	file.close()
	return points
