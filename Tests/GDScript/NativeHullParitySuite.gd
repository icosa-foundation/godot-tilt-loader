extends SceneTree

const USER_DATA_DIR := "C:/Users/andyb/AppData/Roaming/Godot/app_userdata/open-brush-stroke-gen-godot"

const CASES := [
	{"name": "hull_003", "csv": "hull_compare_003.csv", "tolerance": 0.000011151688, "points": 62, "faces": 120},
	{"name": "hull_031", "csv": "hull_compare_031.csv", "tolerance": 0.000001982968, "points": 108, "faces": 212},
	{"name": "hull_085", "csv": "hull_compare_085.csv", "tolerance": 0.000014966814, "points": 221, "faces": 438},
	{"name": "hull_089", "csv": "hull_compare_089.csv", "tolerance": 0.000007012848, "points": 153, "faces": 302},
	{"name": "hull_091", "csv": "hull_compare_091.csv", "tolerance": 0.000007213367, "points": 152, "faces": 300},
	{"name": "hull_092", "csv": "hull_compare_092.csv", "tolerance": 0.000006941712, "points": 147, "faces": 290},
	{"name": "hull_098", "csv": "hull_compare_098.csv", "tolerance": 0.000008222184, "points": 202, "faces": 400},
	{"name": "hull_099", "csv": "hull_compare_099.csv", "tolerance": 0.000012797912, "points": 192, "faces": 380},
	{"name": "hull_111", "csv": "hull_compare_111.csv", "tolerance": 0.000010017480, "points": 190, "faces": 376},
	{"name": "concave_096", "csv": "concave_compare_current_096.csv", "tolerance": 0.000004755093, "points": 7, "faces": 10},
	{"name": "concave_097", "csv": "concave_compare_current_097.csv", "tolerance": 0.000004755093, "points": 6, "faces": 8},
]

const KNOWN_MISMATCHES := [
	{"name": "concave_095", "csv": "concave_compare_current_095.csv", "tolerance": 0.000007726552, "points": 6, "faces": 8, "native_points": 8, "native_triangles": 12},
]

func _init() -> void:
	load("res://native/open_brush_hull/open_brush_hull.gdextension")
	print("NATIVE_HULL_PARITY: class_exists=%s" % str(ClassDB.class_exists("NativeConvexHullUtil")))
	if not ClassDB.class_exists("NativeConvexHullUtil"):
		quit(1)
		return
	var util = ClassDB.instantiate("NativeConvexHullUtil")
	if util == null:
		print("NATIVE_HULL_PARITY: instantiate_failed")
		quit(1)
		return

	var failures := 0
	for test_case in CASES:
		if not _check_case(util, test_case, false):
			failures += 1
	for test_case in KNOWN_MISMATCHES:
		if not _check_case(util, test_case, true):
			failures += 1
	print("NATIVE_HULL_PARITY: failures=%d" % failures)
	quit(1 if failures > 0 else 0)


func _check_case(util: Object, test_case: Dictionary, known_mismatch: bool) -> bool:
	var csv_path := USER_DATA_DIR.path_join(test_case.csv)
	var points := _read_csv_points(csv_path)
	if points.is_empty():
		print("NATIVE_HULL_PARITY: missing_or_empty name=%s csv=%s" % [test_case.name, csv_path])
		return false
	var result: Dictionary = util.call("create", points, float(test_case.tolerance))
	var point_count: int = result.get("points", []).size()
	var face_count: int = result.get("faces", []).size()
	var triangle_count := _fan_triangle_count(result.get("faces", []))
	if known_mismatch:
		var expected_mismatch: bool = point_count == int(test_case.native_points) and triangle_count == int(test_case.native_triangles)
		print("NATIVE_HULL_PARITY: known_mismatch name=%s unity=%d/%d native=%d/%d faces=%d expected_native=%s" % [
			test_case.name,
			int(test_case.points),
			int(test_case.faces),
			point_count,
			triangle_count,
			face_count,
			str(expected_mismatch),
		])
		return expected_mismatch
	var ok: bool = bool(result.get("ok", false)) and point_count == int(test_case.points) and triangle_count == int(test_case.faces)
	print("NATIVE_HULL_PARITY: case=%s ok=%s input=%d points=%d/%d triangles=%d/%d faces=%d" % [
		test_case.name,
		str(ok),
		points.size(),
		point_count,
		int(test_case.points),
		triangle_count,
		int(test_case.faces),
		face_count,
	])
	return ok


func _fan_triangle_count(faces: Array) -> int:
	var triangles := 0
	for face in faces:
		triangles += maxi(0, face.get("indices", []).size() - 2)
	return triangles


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
