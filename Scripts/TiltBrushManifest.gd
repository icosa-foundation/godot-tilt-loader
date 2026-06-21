class_name TiltBrushManifest
extends Resource

var Brushes: Array[BrushDescriptor] = []
var CompatibilityBrushes: Array[BrushDescriptor] = []

func append_from(rhs: TiltBrushManifest) -> void:
	Brushes = _append_unique_by_brush_key(Brushes, rhs.Brushes)
	CompatibilityBrushes = _remove_brushes_by_key(
		_append_unique_by_brush_key(CompatibilityBrushes, rhs.CompatibilityBrushes),
		Brushes
	)

static func _append_unique_by_brush_key(lhs: Array[BrushDescriptor], rhs: Array[BrushDescriptor]) -> Array[BrushDescriptor]:
	var output: Array[BrushDescriptor] = []
	var seen := {}
	for brush in lhs:
		var key := _brush_key(brush)
		if key != "" and not seen.has(key):
			output.append(brush)
			seen[key] = true
	for brush in rhs:
		var key := _brush_key(brush)
		if key != "" and not seen.has(key):
			output.append(brush)
			seen[key] = true
	return output

static func _remove_brushes_by_key(source: Array[BrushDescriptor], removed: Array[BrushDescriptor]) -> Array[BrushDescriptor]:
	var removed_keys := {}
	for brush in removed:
		var key := _brush_key(brush)
		if key != "":
			removed_keys[key] = true
	var output: Array[BrushDescriptor] = []
	for brush in source:
		var key := _brush_key(brush)
		if key != "" and not removed_keys.has(key):
			output.append(brush)
	return output

static func _brush_key(brush: BrushDescriptor) -> String:
	if brush == null:
		return ""
	return brush.m_Guid.strip_edges().to_lower().replace("-", "")
