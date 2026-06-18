class_name ConvexHullUtil
extends RefCounted

const EPSILON := 1e-5

static func create(points: Array[Vector3]) -> Dictionary:
	var unique_points := _unique_points(points)
	if unique_points.size() < 4:
		return {"ok": false, "points": [], "faces": []}
	var center := Vector3.ZERO
	for point in unique_points:
		center += point
	center /= float(unique_points.size())

	var plane_faces := {}
	var count := unique_points.size()
	for i in range(count - 2):
		for j in range(i + 1, count - 1):
			for k in range(j + 1, count):
				var a := unique_points[i]
				var b := unique_points[j]
				var c := unique_points[k]
				var normal := (b - a).cross(c - a)
				if normal.length_squared() < EPSILON * EPSILON:
					continue
				normal = normal.normalized()
				var positive := 0
				var negative := 0
				var d := normal.dot(a)
				for point in unique_points:
					var distance := normal.dot(point) - d
					if distance > EPSILON:
						positive += 1
					elif distance < -EPSILON:
						negative += 1
				if positive > 0 and negative > 0:
					continue
				if positive > 0:
					normal = -normal
					d = -d
				if normal.dot(((a + b + c) / 3.0) - center) < 0.0:
					normal = -normal
					d = -d
				var key := _plane_key(normal, d)
				if not plane_faces.has(key):
					var plane_indices: Array[int] = []
					for point_index in range(count):
						if absf(normal.dot(unique_points[point_index]) - d) <= EPSILON * 4.0:
							plane_indices.append(point_index)
					plane_faces[key] = {
						"normal": normal,
						"indices": plane_indices,
					}

	var faces: Array = []
	for face_data in plane_faces.values():
		var indices: Array[int] = face_data.indices
		if indices.size() < 3:
			continue
		var sorted_indices := _sort_face_indices(unique_points, indices, face_data.normal)
		if sorted_indices.size() >= 3:
			faces.append({"indices": sorted_indices, "normal": face_data.normal})
	return {"ok": not faces.is_empty(), "points": unique_points, "faces": faces}

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

static func _plane_key(normal: Vector3, d: float) -> String:
	return "%d:%d:%d:%d" % [
		roundi(normal.x / EPSILON),
		roundi(normal.y / EPSILON),
		roundi(normal.z / EPSILON),
		roundi(d / EPSILON),
	]

static func _sort_face_indices(points: Array[Vector3], indices: Array[int], normal: Vector3) -> Array[int]:
	var face_center := Vector3.ZERO
	for index in indices:
		face_center += points[index]
	face_center /= float(indices.size())
	var axis_u := normal.cross(Vector3.UP)
	if axis_u.length_squared() < EPSILON * EPSILON:
		axis_u = normal.cross(Vector3.RIGHT)
	axis_u = axis_u.normalized()
	var axis_v := normal.cross(axis_u).normalized()
	var sortable: Array = []
	for index in indices:
		var offset := points[index] - face_center
		sortable.append({
			"index": index,
			"angle": atan2(offset.dot(axis_v), offset.dot(axis_u)),
		})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.angle) < float(b.angle))
	var sorted_indices: Array[int] = []
	for item in sortable:
		sorted_indices.append(int(item.index))
	if sorted_indices.size() >= 3:
		var p0 := points[sorted_indices[0]]
		var p1 := points[sorted_indices[1]]
		var p2 := points[sorted_indices[2]]
		var winding_normal := (p1 - p0).cross(p2 - p0)
		if winding_normal.dot(normal) < 0.0:
			sorted_indices.reverse()
	return sorted_indices
