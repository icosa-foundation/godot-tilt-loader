extends RefCounted

const UNIT_SCALE_TO_METERS := 0.1

static func runtime_stroke_fixture(source: Dictionary, brush_guid: String = "") -> Dictionary:
	var output := {
		"coordinate_space": "unity_open_brush_units",
		"brush_guid": brush_guid if not brush_guid.is_empty() else String(source.get("brush_guid", source.get("brushGuid", ""))),
		"brush_scale": float(source.get("brush_scale", source.get("brushScale", 1.0))),
		"brush_size": float(source.get("brush_size", source.get("brushSize", 1.0))),
		"flags": int(source.get("flags", 0)),
		"seed": int(source.get("seed", 0)),
		"color": (source.get("color", [1.0, 1.0, 1.0, 1.0]) as Array).duplicate(),
	}
	output["coordinate_space"] = "godot_open_brush_units"
	var converted_points: Array = []
	var source_points: Array = source.get("control_points", source.get("controlPoints", []))
	for point_value in source_points:
		if not point_value is Dictionary:
			continue
		var point: Dictionary = point_value
		var position: Array = point.get("position", [0.0, 0.0, 0.0])
		var orientation: Array = point.get("orientation", [0.0, 0.0, 0.0, 1.0])
		converted_points.append({
			"position": [float(position[0]), float(position[1]), -float(position[2])],
			"orientation": [-float(orientation[0]), -float(orientation[1]), float(orientation[2]), float(orientation[3])],
			"pressure": float(point.get("pressure", 1.0)),
			"timestamp": int(point.get("timestamp", point.get("timestampMs", 0))),
		})
	output["control_points"] = converted_points
	return output

static func expected_mesh_for_comparison(source_stroke: Dictionary) -> Dictionary:
	var source_mesh: Dictionary = source_stroke.get("live", {})
	var layout := layout_from_raw(source_stroke.get("vertexLayout", {}))
	var attributes: Dictionary = {}
	for attribute_name in source_mesh.get("attributes", {}):
		var source_attribute: Dictionary = source_mesh["attributes"][attribute_name]
		attributes[attribute_name] = _normalized_reference_attribute(attribute_name, source_attribute)

	var triangles: Array = (source_mesh.get("indices", []) as Array).duplicate()

	return {
		"layout": layout.duplicate(true),
		"vertices": _attribute_rows(attributes.get("position", {})),
		"triangles": triangles,
		"normals": _attribute_rows(attributes.get("normal", {})),
		"colors": _attribute_rows(attributes.get("color", {})),
		"tangents": _attribute_rows(attributes.get("tangent", {})),
		"uv0": _attribute_rows(attributes.get("texcoord0", {})),
		"uv1": _attribute_rows(attributes.get("texcoord1", {})),
		"uv2": _attribute_rows(attributes.get("texcoord2", {})),
		"bounds": _normalized_reference_bounds(source_mesh.get("bounds", {})),
	}

static func layout_from_raw(source: Dictionary) -> Dictionary:
	var layout := {
		"use_normals": bool(source.get("usesNormals", false)),
		"normal_semantic": String(source.get("normalSemantic", "Unspecified")),
		"use_colors": bool(source.get("usesColors", false)),
		"use_tangents": bool(source.get("usesTangents", false)),
		"use_vertex_ids": bool(source.get("usesVertexIds", false)),
		"fbx_export_normal_as_texcoord1": bool(source.get("fbxExportsNormalAsTexcoord1", false)),
	}
	layout["particle_attributes"] = bool(layout.use_vertex_ids) and bool(layout.fbx_export_normal_as_texcoord1)
	for channel in range(3):
		layout["uv%d_size" % channel] = 0
		layout["uv%d_semantic" % channel] = "Unspecified"
	for texcoord_value in source.get("texcoords", []):
		if not texcoord_value is Dictionary:
			continue
		var texcoord: Dictionary = texcoord_value
		var channel := int(texcoord.get("channel", -1))
		if channel < 0 or channel > 2:
			continue
		layout["uv%d_size" % channel] = int(texcoord.get("itemSize", 0))
		layout["uv%d_semantic" % channel] = String(texcoord.get("semantic", "Unspecified"))
	return layout

static func polygon_faces_for_comparison(source_stroke: Dictionary) -> Dictionary:
	var source: Dictionary = source_stroke.get("polygonFaces", {})
	if source.is_empty():
		return {}
	var faces: Array = []
	for face_value in source.get("faces", []):
		if not face_value is Dictionary:
			continue
		var face: Dictionary = face_value
		var source_normal := _vec3_from_array(face.get("normal", []))
		var vertices: Array = []
		for vertex_value in face.get("vertices", []):
			var source_vertex := _vec3_from_array(vertex_value)
			vertices.append([
				source_vertex.x * UNIT_SCALE_TO_METERS,
				source_vertex.y * UNIT_SCALE_TO_METERS,
				-source_vertex.z * UNIT_SCALE_TO_METERS,
			])
		faces.append({
			"normal": [source_normal.x, source_normal.y, -source_normal.z],
			"plane_distance": float(face.get("planeDistance", 0.0)) * UNIT_SCALE_TO_METERS,
			"vertices": vertices,
			"source_triangle_count": int(face.get("sourceTriangleCount", 0)),
		})
	return {
		"definition": String(source.get("definition", "")),
		"point_tolerance": float(source.get("pointTolerance", 0.0)) * UNIT_SCALE_TO_METERS,
		"plane_tolerance": float(source.get("planeTolerance", 0.0)) * UNIT_SCALE_TO_METERS,
		"normal_dot_tolerance": float(source.get("normalDotTolerance", 1.0)),
		"face_count": faces.size(),
		"faces": faces,
	}

static func actual_mesh_for_comparison(actual_mesh: MeshData, layout: Dictionary) -> Dictionary:
	var normal_scale := UNIT_SCALE_TO_METERS if String(layout.get("normal_semantic", "")) == "Position" else 1.0
	return {
		"vertices": _scaled_vec3_array(actual_mesh.vertices, UNIT_SCALE_TO_METERS),
		"triangles": actual_mesh.triangles.duplicate(),
		"normals": _scaled_vec3_array(actual_mesh.normals, normal_scale),
		"colors": actual_mesh.colors.duplicate(),
		"tangents": actual_mesh.tangents.duplicate(),
		"uv0": _normalized_actual_uvs(actual_mesh, layout, 0),
		"uv1": _normalized_actual_uvs(actual_mesh, layout, 1),
		"uv2": _normalized_actual_uvs(actual_mesh, layout, 2),
		"bounds": _bounds_from_vertices(_scaled_vec3_array(actual_mesh.vertices, UNIT_SCALE_TO_METERS)),
	}

static func _normalized_reference_attribute(attribute_name: String, source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var output := source.duplicate(true)
	var item_size := int(output.get("itemSize", 0))
	var semantic := String(output.get("semantic", "Unspecified"))
	var data: Array = (output.get("data", []) as Array).duplicate()
	var scaled_components: Array[int] = []
	if attribute_name == "position" or (attribute_name == "normal" and semantic == "Position"):
		scaled_components = [0, 1, 2]
	elif attribute_name == "texcoord0" and semantic == "XyIsUvZIsDistance":
		scaled_components = [2]
	elif attribute_name == "texcoord1" and semantic in ["Position", "Vector"]:
		scaled_components = [0, 1, 2]
	for index in range(data.size()):
		var value := float(data[index])
		if index % item_size in scaled_components:
			value *= UNIT_SCALE_TO_METERS
		data[index] = value

	var reflects_z := attribute_name in ["position", "normal", "tangent"] \
		or (attribute_name == "texcoord1" and semantic in ["Position", "Vector"])
	if reflects_z and item_size >= 3:
		for index in range(2, data.size(), item_size):
			data[index] = -float(data[index])
	if attribute_name == "tangent" and item_size == 4:
		for index in range(3, data.size(), 4):
			data[index] = -float(data[index])
	output["data"] = data
	return output

static func _normalized_actual_uvs(actual_mesh: MeshData, layout: Dictionary, channel: int) -> Array:
	var size := int(layout.get("uv%d_size" % channel, 0))
	if size == 0:
		return []
	var values: Array = actual_mesh.get_uvs(channel, size)
	var semantic := String(layout.get("uv%d_semantic" % channel, "Unspecified"))
	var output: Array = []
	for value in values:
		match size:
			2:
				output.append(value)
			3:
				var converted := Vector3(value)
				if channel == 0 and semantic == "XyIsUvZIsDistance":
					converted.z *= UNIT_SCALE_TO_METERS
				elif channel == 1 and semantic in ["Position", "Vector"]:
					converted *= UNIT_SCALE_TO_METERS
				output.append(converted)
			4:
				var converted := Vector4(value)
				if channel == 1 and semantic in ["Position", "Vector"]:
					converted.x *= UNIT_SCALE_TO_METERS
					converted.y *= UNIT_SCALE_TO_METERS
					converted.z *= UNIT_SCALE_TO_METERS
				output.append(converted)
	return output

static func _scaled_vec3_array(values: Array[Vector3], scale: float) -> Array[Vector3]:
	var output: Array[Vector3] = []
	for value in values:
		output.append(value * scale)
	return output

static func _attribute_rows(attribute: Dictionary) -> Array:
	if attribute.is_empty():
		return []
	var item_size := int(attribute.get("itemSize", 0))
	var data: Array = attribute.get("data", [])
	var output: Array = []
	for offset in range(0, data.size(), item_size):
		var row: Array = []
		for component in range(item_size):
			row.append(float(data[offset + component]))
		output.append(row)
	return output

static func _normalized_reference_bounds(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var source_min: Array = source.get("min", [0.0, 0.0, 0.0])
	var source_max: Array = source.get("max", [0.0, 0.0, 0.0])
	return {
		"min": [
			float(source_min[0]) * UNIT_SCALE_TO_METERS,
			float(source_min[1]) * UNIT_SCALE_TO_METERS,
			-float(source_max[2]) * UNIT_SCALE_TO_METERS,
		],
		"max": [
			float(source_max[0]) * UNIT_SCALE_TO_METERS,
			float(source_max[1]) * UNIT_SCALE_TO_METERS,
			-float(source_min[2]) * UNIT_SCALE_TO_METERS,
		],
	}

static func _bounds_from_vertices(vertices: Array[Vector3]) -> Dictionary:
	if vertices.is_empty():
		return {"min": Vector3.ZERO, "max": Vector3.ZERO}
	var minimum := vertices[0]
	var maximum := vertices[0]
	for vertex in vertices:
		minimum = minimum.min(vertex)
		maximum = maximum.max(vertex)
	return {"min": minimum, "max": maximum}

static func _vec3_from_array(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
