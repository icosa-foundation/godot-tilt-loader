class_name ConvexHullUtil
extends RefCounted

const EPSILON := 1e-5
const DEFAULT_TOLERANCE := 1e-5

static var _native_checked := false
static var _native_util: Object = null

static func create(points: Array[Vector3], tolerance: float = DEFAULT_TOLERANCE) -> Dictionary:
	var native_result := _create_native(points, tolerance)
	if bool(native_result.get("attempted", false)):
		return native_result.result

	var unique_points := _unique_points(points)
	if unique_points.size() < 4:
		return {"ok": false, "points": [], "faces": []}

	var tetra := _find_initial_tetrahedron(unique_points)
	if tetra.is_empty():
		return {"ok": false, "points": [], "faces": []}

	var inside_point := (
		unique_points[int(tetra[0])] +
		unique_points[int(tetra[1])] +
		unique_points[int(tetra[2])] +
		unique_points[int(tetra[3])]
	) * 0.25

	var faces := [
		_make_face(int(tetra[0]), int(tetra[1]), int(tetra[2]), unique_points, inside_point),
		_make_face(int(tetra[0]), int(tetra[3]), int(tetra[1]), unique_points, inside_point),
		_make_face(int(tetra[0]), int(tetra[2]), int(tetra[3]), unique_points, inside_point),
		_make_face(int(tetra[1]), int(tetra[3]), int(tetra[2]), unique_points, inside_point),
	]
	faces = faces.filter(func(face: Dictionary) -> bool: return bool(face.valid))
	faces = _dedupe_faces(faces)

	var initial := {}
	for index in tetra:
		initial[int(index)] = true

	for point_index in range(unique_points.size()):
		if initial.has(point_index):
			continue
		var point := unique_points[point_index]
		var visible_faces: Array[int] = []
		for face_index in range(faces.size()):
			var face: Dictionary = faces[face_index]
			if _signed_distance(face, point, unique_points) > EPSILON:
				visible_faces.append(face_index)
		if visible_faces.is_empty():
			continue

		var visible_lookup := {}
		for face_index in visible_faces:
			visible_lookup[face_index] = true

		var horizon_edges: Dictionary = {}
		for face_index in visible_faces:
			var face: Dictionary = faces[face_index]
			_add_horizon_edge(horizon_edges, int(face.a), int(face.b))
			_add_horizon_edge(horizon_edges, int(face.b), int(face.c))
			_add_horizon_edge(horizon_edges, int(face.c), int(face.a))

		var kept_faces: Array[Dictionary] = []
		for face_index in range(faces.size()):
			if not visible_lookup.has(face_index):
				kept_faces.append(faces[face_index])
		faces = kept_faces
		var face_keys := {}
		for face in faces:
			face_keys[_face_key(face)] = true

		for edge_info in horizon_edges.values():
			if int(edge_info.count) != 1:
				continue
			var edge: Array = edge_info.edge
			var new_face := _make_face(int(edge[0]), int(edge[1]), point_index, unique_points, inside_point)
			var new_key := _face_key(new_face)
			if bool(new_face.valid) and not face_keys.has(new_key):
				faces.append(new_face)
				face_keys[new_key] = true

	if faces.is_empty():
		return {"ok": false, "points": [], "faces": []}

	return _compact_result(unique_points, faces)


static func _create_native(points: Array[Vector3], tolerance: float) -> Dictionary:
	if not _native_checked:
		_native_checked = true
		load("res://native/open_brush_hull/open_brush_hull.gdextension")
		if ClassDB.class_exists("NativeConvexHullUtil"):
			_native_util = ClassDB.instantiate("NativeConvexHullUtil")
	if _native_util == null:
		return {"attempted": false}
	var packed := PackedVector3Array(points)
	var result: Dictionary = _native_util.call("create", packed, tolerance)
	return {"attempted": true, "result": result}


static func _unique_points(points: Array[Vector3]) -> Array[Vector3]:
	var unique: Array[Vector3] = []
	for point in points:
		var found := false
		for existing in unique:
			if existing.distance_to(point) <= EPSILON:
				found = true
				break
		if not found:
			unique.append(point)
	return unique


static func _find_initial_tetrahedron(points: Array[Vector3]) -> Array[int]:
	var min_x := 0
	var max_x := 0
	for index in range(1, points.size()):
		if points[index].x < points[min_x].x:
			min_x = index
		if points[index].x > points[max_x].x:
			max_x = index
	if points[min_x].distance_to(points[max_x]) <= EPSILON:
		return []

	var line := points[max_x] - points[min_x]
	var third := -1
	var best_line_distance := 0.0
	for index in range(points.size()):
		if index == min_x or index == max_x:
			continue
		var distance := line.cross(points[index] - points[min_x]).length_squared()
		if distance > best_line_distance:
			best_line_distance = distance
			third = index
	if third < 0 or best_line_distance <= EPSILON * EPSILON:
		return []

	var normal := (points[max_x] - points[min_x]).cross(points[third] - points[min_x])
	var fourth := -1
	var best_plane_distance := 0.0
	for index in range(points.size()):
		if index == min_x or index == max_x or index == third:
			continue
		var distance := absf(normal.dot(points[index] - points[min_x]))
		if distance > best_plane_distance:
			best_plane_distance = distance
			fourth = index
	if fourth < 0 or best_plane_distance <= EPSILON:
		return []

	return [min_x, max_x, third, fourth]


static func _make_face(a: int, b: int, c: int, points: Array[Vector3], inside_point: Vector3) -> Dictionary:
	var normal := (points[b] - points[a]).cross(points[c] - points[a])
	var length := normal.length()
	if length <= EPSILON:
		return {"valid": false}
	normal /= length
	if normal.dot(inside_point - points[a]) > 0.0:
		var tmp := b
		b = c
		c = tmp
		normal = -normal
	return {
		"valid": true,
		"a": a,
		"b": b,
		"c": c,
		"indices": [a, b, c],
		"normal": normal,
	}


static func _signed_distance(face: Dictionary, point: Vector3, points: Array[Vector3]) -> float:
	return (face.normal as Vector3).dot(point - points[int(face.a)])


static func _add_horizon_edge(edges: Dictionary, a: int, b: int) -> void:
	var low := mini(a, b)
	var high := maxi(a, b)
	var key := "%d:%d" % [low, high]
	if edges.has(key):
		edges[key].count = int(edges[key].count) + 1
	else:
		edges[key] = {"count": 1, "edge": [a, b]}


static func _compact_result(points: Array[Vector3], faces: Array) -> Dictionary:
	var used := {}
	for face in faces:
		used[int(face.a)] = true
		used[int(face.b)] = true
		used[int(face.c)] = true

	var remap := {}
	var hull_points: Array[Vector3] = []
	for original_index in used.keys():
		remap[int(original_index)] = hull_points.size()
		hull_points.append(points[int(original_index)])

	var compact_faces: Array = []
	for face in faces:
		var indices: Array[int] = [
			int(remap[int(face.a)]),
			int(remap[int(face.b)]),
			int(remap[int(face.c)]),
		]
		compact_faces.append({
			"indices": indices,
			"normal": face.normal,
		})

	return {"ok": not compact_faces.is_empty(), "points": hull_points, "faces": compact_faces}


static func _dedupe_faces(faces: Array) -> Array:
	var result: Array[Dictionary] = []
	var keys := {}
	for face in faces:
		var key := _face_key(face)
		if keys.has(key):
			continue
		keys[key] = true
		result.append(face)
	return result


static func _face_key(face: Dictionary) -> String:
	if not bool(face.get("valid", true)):
		return ""
	var indices := [int(face.a), int(face.b), int(face.c)]
	indices.sort()
	return "%d:%d:%d" % [indices[0], indices[1], indices[2]]
