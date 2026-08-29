extends SceneTree

const NORMALIZED_SCHEMA := "open-brush-reference-mesh-v2"
const RAW_SCHEMA_VERSION := 1
const SOURCE_COORDINATE_SYSTEM := "Unity X-right, Y-up, Z-forward; mesh positions are mesh-local"
const DEFAULT_OUTPUT_DIR := "res://Resources/Fixtures/OpenBrushReferenceMeshes"
const UNIT_SCALE_TO_METERS := 0.1

var _failed := false

func _init() -> void:
	var options := _parse_arguments(OS.get_cmdline_user_args())
	if _failed:
		quit(1)
		return
	if bool(options.get("help", false)):
		_print_usage()
		quit(0)
		return

	var source_dir := _global_path(String(options.get("source_dir", "")))
	var output_dir := _global_path(String(options.get("output_dir", DEFAULT_OUTPUT_DIR)))
	var source_commit := String(options.get("source_commit", ""))
	var selected_brushes: Dictionary = options.get("brushes", {})
	var check_only := bool(options.get("check", false))
	if source_dir.is_empty():
		_fail("--source-dir is required")
	if source_commit.is_empty():
		_fail("--source-commit is required")
	elif not _is_full_commit_hash(source_commit):
		_fail("--source-commit must be a 40-character hexadecimal commit hash")
	if _failed:
		_print_usage()
		quit(1)
		return

	var source := DirAccess.open(source_dir)
	if source == null:
		_fail("cannot open source directory %s" % source_dir)
		quit(1)
		return
	if not check_only:
		var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
		if mkdir_error != OK:
			_fail("cannot create output directory %s: error %d" % [output_dir, mkdir_error])
			quit(1)
			return

	var file_names: Array[String] = []
	for file_name in source.get_files():
		if file_name.begins_with("brush-") and file_name.ends_with(".mesh.json"):
			file_names.append(file_name)
	file_names.sort()

	var converted := 0
	var selected_found := {}
	for file_name in file_names:
		var source_path := source_dir.path_join(file_name)
		var raw := _load_json(source_path)
		if raw.is_empty():
			continue
		var durable_name := String(raw.get("durableName", ""))
		if not selected_brushes.is_empty() and not selected_brushes.has(durable_name):
			continue
		selected_found[durable_name] = true
		var normalized := _normalize_fixture(raw, file_name, source_path, source_commit)
		if normalized.is_empty():
			continue
		var output_path := output_dir.path_join("brush-%s.json" % durable_name)
		var output_text := JSON.stringify(normalized, "\t", true, true) + "\n"
		if check_only:
			var current_text := FileAccess.get_file_as_string(output_path)
			if current_text != output_text:
				_fail("normalized fixture is stale or missing: %s" % output_path)
				continue
		else:
			var output := FileAccess.open(output_path, FileAccess.WRITE)
			if output == null:
				_fail("cannot write %s: error %d" % [output_path, FileAccess.get_open_error()])
				continue
			output.store_string(output_text)
		converted += 1
		print("OPEN_BRUSH_FIXTURE_CONVERT\tbrush=%s\tsource=%s\toutput=%s" % [
			durable_name,
			file_name,
			output_path,
		])

	for requested_brush in selected_brushes:
		if not selected_found.has(requested_brush):
			_fail("requested brush fixture not found: %s" % requested_brush)
	if converted == 0:
		_fail("no fixtures converted")

	print("OPEN_BRUSH_FIXTURE_CONVERT\tmode=%s\tfixtures=%d\tsource_commit=%s" % [
		"check" if check_only else "write",
		converted,
		source_commit,
	])
	quit(1 if _failed else 0)

func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var options := {
		"source_dir": "",
		"output_dir": DEFAULT_OUTPUT_DIR,
		"source_commit": "",
		"brushes": {},
		"check": false,
		"help": false,
	}
	for argument in arguments:
		if argument == "--check":
			options.check = true
		elif argument == "--help" or argument == "-h":
			options.help = true
		elif argument.begins_with("--source-dir="):
			options.source_dir = argument.trim_prefix("--source-dir=")
		elif argument.begins_with("--output-dir="):
			options.output_dir = argument.trim_prefix("--output-dir=")
		elif argument.begins_with("--source-commit="):
			options.source_commit = argument.trim_prefix("--source-commit=")
		elif argument.begins_with("--brushes="):
			var selected := {}
			for brush_name in argument.trim_prefix("--brushes=").split(",", false):
				var trimmed_name := brush_name.strip_edges()
				if not trimmed_name.is_empty():
					selected[trimmed_name] = true
			options.brushes = selected
		else:
			_fail("unknown argument: %s" % argument)
	return options

func _normalize_fixture(raw: Dictionary, file_name: String, source_path: String, source_commit: String) -> Dictionary:
	if int(raw.get("schemaVersion", -1)) != RAW_SCHEMA_VERSION:
		_fail("%s has unsupported schemaVersion %s" % [file_name, raw.get("schemaVersion", null)])
		return {}
	if String(raw.get("coordinateSystem", "")) != SOURCE_COORDINATE_SYSTEM:
		_fail("%s has unsupported coordinate system %s" % [file_name, raw.get("coordinateSystem", null)])
		return {}
	var strokes: Array = raw.get("strokes", [])
	if strokes.size() != 1 or not strokes[0] is Dictionary:
		_fail("%s must contain exactly one stroke" % file_name)
		return {}
	var source_stroke: Dictionary = strokes[0]
	var input: Dictionary = source_stroke.get("input", {})
	var source_layout: Dictionary = source_stroke.get("vertexLayout", {})
	var live_mesh: Dictionary = source_stroke.get("live", {})
	if input.is_empty() or source_layout.is_empty() or live_mesh.is_empty():
		_fail("%s is missing input, vertexLayout, or live data" % file_name)
		return {}
	if not _is_identity_matrix(input.get("localToWorldMatrix", [])):
		_fail("%s has a non-identity localToWorldMatrix, which is not supported yet" % file_name)
		return {}
	if not _validate_live_mesh(file_name, live_mesh):
		return {}
	var source_polygon_faces: Dictionary = source_stroke.get("polygonFaces", {})
	if not source_polygon_faces.is_empty() and not _validate_polygon_faces(file_name, source_polygon_faces):
		return {}

	var durable_name := String(raw.get("durableName", ""))
	var brush_guid := String(raw.get("brushGuid", ""))
	if durable_name.is_empty() or brush_guid.is_empty():
		_fail("%s is missing durableName or brushGuid" % file_name)
		return {}
	if String(input.get("brushGuid", "")) != brush_guid:
		_fail("%s stroke brushGuid does not match the fixture brushGuid" % file_name)
		return {}

	var normalized := {
		"schema": NORMALIZED_SCHEMA,
		"name": "brush-%s" % durable_name,
		"brush": durable_name,
		"source": {
			"open_brush_commit": source_commit,
			"raw_fixture_file": file_name,
			"raw_fixture_sha256": FileAccess.get_sha256(source_path),
			"raw_schema_version": RAW_SCHEMA_VERSION,
			"fixed_shader_time_seconds": float(raw.get("fixedShaderTimeSeconds", 0.0)),
		},
		"coordinate_boundary": {
			"source": SOURCE_COORDINATE_SYSTEM,
			"target": "Godot X-right, Y-up, Z-back; comparison values are metres",
			"unit_scale_to_meters": UNIT_SCALE_TO_METERS,
			"reflection_axis": "z",
		},
		"stroke": _normalize_stroke_input(input, brush_guid),
		"material": (source_stroke.get("material", {}) as Dictionary).duplicate(true),
		"mesh": {
			"stage": "finalized_live_pre_brush_baker",
			"vertex_count": int(live_mesh.get("vertexCount", 0)),
			"index_count": int(live_mesh.get("indexCount", 0)),
			"index_format": String(live_mesh.get("indexFormat", "")),
			"sub_mesh_count": int(live_mesh.get("subMeshCount", 0)),
			"layout": _normalize_layout(source_layout),
			"attributes": live_mesh.get("attributes", {}).duplicate(true),
			"triangles": (live_mesh.get("indices", []) as Array).duplicate(),
			"bounds": (live_mesh.get("bounds", {}) as Dictionary).duplicate(true),
		},
	}
	if not source_polygon_faces.is_empty():
		normalized["polygon_faces"] = _normalize_polygon_faces(source_polygon_faces)
	return normalized

func _normalize_polygon_faces(source: Dictionary) -> Dictionary:
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

func _vec3_from_array(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _normalize_stroke_input(input: Dictionary, brush_guid: String) -> Dictionary:
	var control_points: Array = []
	for point_value in input.get("controlPoints", []):
		if not point_value is Dictionary:
			continue
		var point: Dictionary = point_value
		control_points.append({
			"position": (point.get("position", []) as Array).duplicate(),
			"orientation": (point.get("orientation", []) as Array).duplicate(),
			"pressure": float(point.get("pressure", 1.0)),
			"timestamp": int(point.get("timestampMs", 0)),
		})
	return {
		"coordinate_space": "unity_open_brush_units",
		"brush_guid": brush_guid,
		"brush_scale": float(input.get("brushScale", 1.0)),
		"brush_size": float(input.get("brushSize", 1.0)),
		"flags": int(input.get("flags", 0)),
		"seed": int(input.get("seed", 0)),
		"color": (input.get("color", [1.0, 1.0, 1.0, 1.0]) as Array).duplicate(),
		"control_points": control_points,
		"local_to_world_matrix": (input.get("localToWorldMatrix", []) as Array).duplicate(),
	}

func _normalize_layout(source_layout: Dictionary) -> Dictionary:
	var layout := {
		"use_normals": bool(source_layout.get("usesNormals", false)),
		"normal_semantic": String(source_layout.get("normalSemantic", "Unspecified")),
		"use_colors": bool(source_layout.get("usesColors", false)),
		"use_tangents": bool(source_layout.get("usesTangents", false)),
		"use_vertex_ids": bool(source_layout.get("usesVertexIds", false)),
		"fbx_export_normal_as_texcoord1": bool(source_layout.get("fbxExportsNormalAsTexcoord1", false)),
	}
	layout.particle_attributes = bool(layout.use_vertex_ids) and bool(layout.fbx_export_normal_as_texcoord1)
	for channel in range(3):
		layout["uv%d_size" % channel] = 0
		layout["uv%d_semantic" % channel] = "Unspecified"
	for texcoord_value in source_layout.get("texcoords", []):
		if not texcoord_value is Dictionary:
			continue
		var texcoord: Dictionary = texcoord_value
		var channel := int(texcoord.get("channel", -1))
		if channel < 0 or channel > 2:
			continue
		layout["uv%d_size" % channel] = int(texcoord.get("itemSize", 0))
		layout["uv%d_semantic" % channel] = String(texcoord.get("semantic", "Unspecified"))
	return layout

func _validate_live_mesh(file_name: String, live_mesh: Dictionary) -> bool:
	var vertex_count := int(live_mesh.get("vertexCount", -1))
	var index_count := int(live_mesh.get("indexCount", -1))
	var indices: Array = live_mesh.get("indices", [])
	if vertex_count < 0 or index_count < 0 or indices.size() != index_count:
		_fail("%s has inconsistent live mesh counts" % file_name)
		return false
	var attributes: Dictionary = live_mesh.get("attributes", {})
	for attribute_name in attributes:
		var attribute_value = attributes[attribute_name]
		if not attribute_value is Dictionary:
			_fail("%s attribute %s is not an object" % [file_name, attribute_name])
			return false
		var attribute: Dictionary = attribute_value
		var item_size := int(attribute.get("itemSize", 0))
		var data: Array = attribute.get("data", [])
		if item_size <= 0 or data.size() != vertex_count * item_size:
			_fail("%s attribute %s has %d values; expected %d" % [
				file_name,
				attribute_name,
				data.size(),
				vertex_count * item_size,
			])
			return false
	return true

func _validate_polygon_faces(file_name: String, source: Dictionary) -> bool:
	var faces: Array = source.get("faces", [])
	if int(source.get("faceCount", -1)) != faces.size():
		_fail("%s has an inconsistent polygon face count" % file_name)
		return false
	if float(source.get("pointTolerance", 0.0)) <= 0.0 or float(source.get("planeTolerance", 0.0)) <= 0.0:
		_fail("%s has invalid polygon face tolerances" % file_name)
		return false
	for face_index in range(faces.size()):
		if not faces[face_index] is Dictionary:
			_fail("%s polygon face %d is not an object" % [file_name, face_index])
			return false
		var face: Dictionary = faces[face_index]
		var normal: Array = face.get("normal", [])
		var vertices: Array = face.get("vertices", [])
		if normal.size() != 3 or vertices.size() < 3:
			_fail("%s polygon face %d has invalid normal or vertices" % [file_name, face_index])
			return false
		for vertex in vertices:
			if not vertex is Array or vertex.size() != 3:
				_fail("%s polygon face %d has an invalid vertex" % [file_name, face_index])
				return false
	return true

func _is_identity_matrix(value: Variant) -> bool:
	if not value is Array or value.size() != 16:
		return false
	var expected := [
		1.0, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		0.0, 0.0, 0.0, 1.0,
	]
	for index in range(16):
		if not is_equal_approx(float(value[index]), expected[index]):
			return false
	return true

func _is_full_commit_hash(value: String) -> bool:
	if value.length() != 40:
		return false
	for character in value.to_lower():
		if character not in "0123456789abcdef":
			return false
	return true

func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_fail("cannot read %s" % path)
		return {}
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		_fail("%s does not contain a JSON object" % path)
		return {}
	return parsed

func _global_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path.simplify_path()

func _print_usage() -> void:
	print("Usage:")
	print("  godot --headless --xr-mode off --path . --script res://Tools/OpenBrushMeshFixtures/ConvertOpenBrushMeshFixtures.gd -- --source-dir=<BrushFixtures> --source-commit=<40-char hash> [--output-dir=<path>] [--brushes=<name,...>] [--check]")

func _fail(message: String) -> void:
	_failed = true
	push_error("ConvertOpenBrushMeshFixtures: %s" % message)
