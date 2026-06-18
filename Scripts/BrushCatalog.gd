class_name BrushCatalog
extends RefCounted

static var _guid_to_brush := {}
static var _gui_brush_list: Array[BrushDescriptor] = []
static var _manifest: TiltBrushManifest

static func all_brushes() -> Array[BrushDescriptor]:
	return _gui_brush_list.duplicate()

static func get_brush(guid: String) -> BrushDescriptor:
	var key := _canonical_guid(guid)
	return _guid_to_brush.get(key)

static func init(manifest: TiltBrushManifest) -> void:
	_manifest = manifest
	_guid_to_brush.clear()
	_gui_brush_list.clear()
	if manifest == null:
		return

	var manifest_brushes := _load_brushes_in_manifest()
	for brush in manifest_brushes:
		var key := _canonical_guid(brush.m_Guid)
		if key == "":
			continue
		if _guid_to_brush.has(key) and _guid_to_brush[key] != brush:
			push_warning("Guid collision: %s, %s" % [_guid_to_brush[key], brush])
			continue
		_guid_to_brush[key] = brush

	for brush in manifest_brushes:
		brush.m_SupersededBy = null
	for brush in manifest_brushes:
		var older := brush.m_Supersedes
		if older == null:
			continue
		var older_key := _canonical_guid(older.m_Guid)
		if older_key != "" and not _guid_to_brush.has(older_key):
			_guid_to_brush[older_key] = older
			older.m_HiddenInGui = true
		if older.m_SupersededBy != null and older.m_SupersededBy.name != brush.name:
			push_warning("Unexpected: %s is superseded by both %s and %s" % [older.name, older.m_SupersededBy.name, brush.name])
		else:
			older.m_SupersededBy = brush

	for brush in _guid_to_brush.values():
		if not brush.m_HiddenInGui:
			_gui_brush_list.append(brush)

static func _load_brushes_in_manifest() -> Array[BrushDescriptor]:
	var output: Array[BrushDescriptor] = []
	if _manifest == null:
		return output
	for desc in _manifest.Brushes:
		if desc != null:
			output.append(desc)
	for desc in _manifest.CompatibilityBrushes:
		if desc != null and not _manifest.Brushes.has(desc):
			desc.m_HiddenInGui = true
			output.append(desc)
	return output

static func _canonical_guid(guid: String) -> String:
	return guid.strip_edges().to_lower().replace("-", "")
