class_name UnityAssetLoader
extends RefCounted

static func create_manifest_from_directory(directory_path: String, include_subdirectories: bool = true) -> TiltBrushManifest:
	var manifest := TiltBrushManifest.new()
	var brush_descriptors: Array[BrushDescriptor] = []
	if not DirAccess.dir_exists_absolute(directory_path):
		push_error("Directory not found: %s" % directory_path)
		return manifest

	var asset_files := _find_files(directory_path, ".asset", include_subdirectories)
	print("Found %d .asset files in %s" % [asset_files.size(), directory_path])
	for asset_file in asset_files:
		var descriptor := load_brush_descriptor(asset_file)
		if descriptor != null:
			brush_descriptors.append(descriptor)

	manifest.Brushes = brush_descriptors
	manifest.CompatibilityBrushes = []
	print("Loaded %d brush descriptors" % brush_descriptors.size())
	return manifest

static func load_manifest(manifest_path: String) -> TiltBrushManifest:
	var manifest := TiltBrushManifest.new()
	if not FileAccess.file_exists(manifest_path):
		push_error("Manifest file not found: %s" % manifest_path)
		return manifest

	var lines := _read_lines(manifest_path)
	var brush_guids: Array[String] = []
	var compatibility_guids: Array[String] = []
	var current_array := ""

	for raw_line in lines:
		var trimmed := raw_line.strip_edges()
		if trimmed.begins_with("Brushes:"):
			current_array = "brushes"
			continue
		if trimmed.begins_with("CompatibilityBrushes:"):
			current_array = "compatibility"
			continue
		if current_array != "" and trimmed.length() > 0 and not trimmed.begins_with("-"):
			current_array = ""
		if current_array == "":
			continue
		if trimmed.begins_with("-") and trimmed.contains("guid:"):
			var guid := _extract_guid_reference(trimmed)
			if guid == "":
				continue
			if current_array == "brushes":
				brush_guids.append(guid)
			elif current_array == "compatibility":
				compatibility_guids.append(guid)

	var manifest_dir := manifest_path.get_base_dir()
	var resources_paths: Array[String] = [
		manifest_dir.path_join("Resources").path_join("Brushes"),
		manifest_dir.path_join("Resources").path_join("X").path_join("Brushes")
	]
	manifest.Brushes = _load_brushes_by_guids(brush_guids, resources_paths)
	manifest.CompatibilityBrushes = _load_brushes_by_guids(compatibility_guids, resources_paths)
	return manifest

static func load_brush_descriptor(asset_file_path: String) -> BrushDescriptor:
	if not FileAccess.file_exists(asset_file_path):
		return null

	var descriptor := BrushDescriptor.new()
	var lines := _read_lines(asset_file_path)
	var in_guid_block := false
	var in_tags := false

	for raw_line in lines:
		var trimmed := raw_line.strip_edges()
		if trimmed == "":
			continue

		if in_tags:
			if trimmed.begins_with("-"):
				descriptor.m_Tags.append(trimmed.trim_prefix("-").strip_edges())
				continue
			in_tags = false

		if trimmed.begins_with("m_Name:"):
			descriptor.name = _parse_string_value(trimmed)
		elif trimmed.begins_with("m_Guid:"):
			in_guid_block = true
			continue
		elif in_guid_block and trimmed.begins_with("m_storage:"):
			descriptor.m_Guid = _parse_string_value(trimmed)
			in_guid_block = false
		elif trimmed.begins_with("m_DurableName:"):
			descriptor.m_DurableName = _parse_string_value(trimmed)
		elif trimmed.begins_with("m_CreationVersion:"):
			descriptor.m_CreationVersion = _parse_string_value(trimmed)
		elif trimmed.begins_with("m_ShaderVersion:"):
			descriptor.m_ShaderVersion = _parse_string_value(trimmed)
		elif trimmed.begins_with("m_Tags:"):
			descriptor.m_Tags = []
			in_tags = true
		elif trimmed.begins_with("m_Nondeterministic:"):
			descriptor.m_Nondeterministic = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_LooksIdentical:"):
			descriptor.m_LooksIdentical = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_DescriptionExtra:"):
			descriptor.m_DescriptionExtra = _parse_string_value(trimmed)
		elif trimmed.begins_with("m_TextureAtlasV:"):
			descriptor.m_TextureAtlasV = int(_parse_float_value(trimmed))
		elif trimmed.begins_with("m_TileRate:"):
			descriptor.m_TileRate = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_BrushSizeRange:"):
			descriptor.m_BrushSizeRange = _parse_vector2(trimmed)
		elif trimmed.begins_with("m_PressureSizeRange:"):
			descriptor.m_PressureSizeRange = _parse_vector2(trimmed)
		elif trimmed.begins_with("m_SizeVariance:"):
			descriptor.m_SizeVariance = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_PreviewPressureSizeMin:"):
			descriptor.m_PreviewPressureSizeMin = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_Opacity:"):
			descriptor.m_Opacity = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_PressureOpacityRange:"):
			descriptor.m_PressureOpacityRange = _parse_vector2(trimmed)
		elif trimmed.begins_with("m_ColorLuminanceMin:"):
			descriptor.m_ColorLuminanceMin = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_ColorSaturationMax:"):
			descriptor.m_ColorSaturationMax = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_ParticleSpeed:"):
			descriptor.m_ParticleSpeed = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_ParticleRate:"):
			descriptor.m_ParticleRate = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_ParticleInitialRotationRange:"):
			descriptor.m_ParticleInitialRotationRange = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_RandomizeAlpha:"):
			descriptor.m_RandomizeAlpha = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_SprayRateMultiplier:"):
			descriptor.m_SprayRateMultiplier = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_RotationVariance:"):
			descriptor.m_RotationVariance = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_PositionVariance:"):
			descriptor.m_PositionVariance = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_SizeRatio:"):
			descriptor.m_SizeRatio = _parse_vector2(trimmed)
		elif trimmed.begins_with("m_M11Compatibility:"):
			descriptor.m_M11Compatibility = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_SolidMinLengthMeters_PS:"):
			descriptor.m_SolidMinLengthMeters_PS = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_TubeStoreRadiusInTexcoord0Z:"):
			descriptor.m_TubeStoreRadiusInTexcoord0Z = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_RenderBackfaces:"):
			descriptor.m_RenderBackfaces = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_BackIsInvisible:"):
			descriptor.m_BackIsInvisible = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_BackfaceHueShift:"):
			descriptor.m_BackfaceHueShift = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_BoundsPadding:"):
			descriptor.m_BoundsPadding = _parse_float_value(trimmed)

	if descriptor.m_Guid != "" and descriptor.m_DurableName != "":
		_load_prefab_fields(descriptor, asset_file_path, lines)
		return descriptor
	return null

static func get_default_brushes_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("Resources").path_join("Brushes").path_join("Basic")

static func find_brush_by_guid(guid: String, search_path: String) -> String:
	if not DirAccess.dir_exists_absolute(search_path):
		push_warning("FindBrushByGuid: searchPath does not exist: %s" % search_path)
		return ""

	var canonical_guid := guid.to_lower()
	for meta_file in _find_files(search_path, ".asset.meta", true):
		for line in _read_lines(meta_file):
			var trimmed := line.strip_edges()
			if trimmed.begins_with("guid:") and trimmed.contains(canonical_guid):
				return meta_file.substr(0, meta_file.length() - 5)
	return ""

static func _load_brushes_by_guids(guids: Array[String], resources_paths: Array[String]) -> Array[BrushDescriptor]:
	var brush_descriptors: Array[BrushDescriptor] = []
	for guid in guids:
		var brush_path := ""
		for search_path in resources_paths:
			brush_path = find_brush_by_guid(guid, search_path)
			if brush_path != "":
				break
		if brush_path == "":
			push_warning("Could not find brush with GUID %s" % guid)
			continue
		var descriptor := load_brush_descriptor(brush_path)
		if descriptor != null:
			brush_descriptors.append(descriptor)
	return brush_descriptors

static func _load_prefab_fields(descriptor: BrushDescriptor, asset_file_path: String, asset_lines: PackedStringArray) -> void:
	var prefab_path := _find_prefab_path(asset_file_path, asset_lines)
	if prefab_path == "":
		return
	descriptor.prefab_fields["prefab_path"] = prefab_path
	var in_brush_component := false
	for raw_line in _read_lines(prefab_path):
		var trimmed := raw_line.strip_edges()
		if trimmed.begins_with("m_Name:") and not descriptor.prefab_fields.has("prefab_name"):
			descriptor.prefab_fields["prefab_name"] = _parse_string_value(trimmed)
		elif trimmed.begins_with("m_Script:") and trimmed.contains("guid:"):
			descriptor.prefab_fields["script_guid"] = _extract_guid_reference(trimmed)
		if trimmed.begins_with("MonoBehaviour:"):
			in_brush_component = true
			continue
		if in_brush_component and trimmed.begins_with("---"):
			break
		if not in_brush_component:
			continue
		if trimmed.begins_with("m_ShapeModifier:"):
			descriptor.prefab_fields["m_ShapeModifier"] = int(_parse_float_value(trimmed))
		elif trimmed.begins_with("m_TaperScalar:"):
			descriptor.prefab_fields["m_TaperScalar"] = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_PetalDisplacementAmt:"):
			descriptor.prefab_fields["m_PetalDisplacementAmt"] = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_PetalDisplacementExp:"):
			descriptor.prefab_fields["m_PetalDisplacementExp"] = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_PointsInClosedCircle:"):
			descriptor.prefab_fields["m_PointsInClosedCircle"] = int(_parse_float_value(trimmed))
		elif trimmed.begins_with("m_CapAspect:"):
			descriptor.prefab_fields["m_CapAspect"] = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_EndCaps:"):
			descriptor.prefab_fields["m_EndCaps"] = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_HardEdges:"):
			descriptor.prefab_fields["m_HardEdges"] = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_uvStyle:"):
			descriptor.prefab_fields["m_uvStyle"] = int(_parse_float_value(trimmed))
		elif trimmed.begins_with("m_BreakAngleMultiplier:"):
			descriptor.prefab_fields["m_BreakAngleMultiplier"] = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_StoreWidthInTexcoord0Z:"):
			descriptor.prefab_fields["m_StoreWidthInTexcoord0Z"] = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_Faceted:"):
			descriptor.prefab_fields["m_Faceted"] = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_TrackInterior:"):
			descriptor.prefab_fields["m_TrackInterior"] = _parse_bool_value(trimmed)
		elif trimmed.begins_with("m_KnotsInHull:"):
			descriptor.prefab_fields["m_KnotsInHull"] = int(_parse_float_value(trimmed))
		elif trimmed.begins_with("m_KnotConversion:"):
			descriptor.prefab_fields["m_KnotConversion"] = int(_parse_float_value(trimmed))
		elif trimmed.begins_with("m_Simplification_PS:"):
			descriptor.prefab_fields["m_Simplification_PS"] = _parse_float_value(trimmed)
		elif trimmed.begins_with("m_SimplifyMode:"):
			descriptor.prefab_fields["m_SimplifyMode"] = int(_parse_float_value(trimmed))

static func _find_prefab_path(asset_file_path: String, asset_lines: PackedStringArray) -> String:
	for line in asset_lines:
		if line.contains("m_BrushPrefab:") and line.contains("guid:"):
			var prefab_guid := _extract_guid_reference(line)
			var resources_path := asset_file_path.get_base_dir()
			while resources_path != "" and resources_path.get_file() != "Resources":
				resources_path = resources_path.get_base_dir()
			if resources_path != "":
				var prefab_path := _find_prefab_by_guid(prefab_guid, resources_path)
				if prefab_path != "":
					return prefab_path
			break

	var prefabs := _find_files(asset_file_path.get_base_dir(), ".prefab", false)
	return prefabs[0] if prefabs.size() > 0 else ""

static func _find_prefab_by_guid(guid: String, search_path: String) -> String:
	for meta_file in _find_files(search_path, ".prefab.meta", true):
		for line in _read_lines(meta_file):
			var trimmed := line.strip_edges()
			if trimmed.begins_with("guid:") and trimmed.contains(guid.to_lower()):
				return meta_file.substr(0, meta_file.length() - 5)
	return ""

static func _find_files(directory_path: String, suffix: String, recursive: bool) -> Array[String]:
	var output: Array[String] = []
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return output
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := directory_path.path_join(file_name)
			if dir.current_is_dir():
				if recursive:
					output.append_array(_find_files(full_path, suffix, recursive))
			elif file_name.ends_with(suffix):
				output.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return output

static func _read_lines(path: String) -> PackedStringArray:
	var text := FileAccess.get_file_as_string(path)
	return text.split("\n", false)

static func _parse_string_value(line: String) -> String:
	var colon_index := line.find(":")
	if colon_index >= 0 and colon_index < line.length() - 1:
		return line.substr(colon_index + 1).strip_edges()
	return ""

static func _parse_bool_value(line: String) -> bool:
	var value := _parse_string_value(line).to_lower()
	return value == "1" or value == "true"

static func _parse_float_value(line: String) -> float:
	return _parse_string_value(line).to_float()

static func _parse_vector2(line: String) -> Vector2:
	var start := line.find("{")
	var end := line.find("}", start)
	if start == -1 or end == -1 or end <= start:
		return Vector2.ZERO
	var vector_text := line.substr(start + 1, end - start - 1)
	var result := Vector2.ZERO
	for part in vector_text.split(",", false):
		var trimmed := part.strip_edges()
		if trimmed.begins_with("x:"):
			result.x = trimmed.substr(trimmed.find(":") + 1).strip_edges().to_float()
		elif trimmed.begins_with("y:"):
			result.y = trimmed.substr(trimmed.find(":") + 1).strip_edges().to_float()
	return result

static func _extract_guid_reference(line: String) -> String:
	var guid_start := line.find("guid:")
	if guid_start == -1:
		return ""
	guid_start += 5
	var guid_end := line.find(",", guid_start)
	if guid_end == -1:
		guid_end = line.find("}", guid_start)
	if guid_end == -1:
		guid_end = line.length()
	return line.substr(guid_start, guid_end - guid_start).strip_edges().to_lower()
