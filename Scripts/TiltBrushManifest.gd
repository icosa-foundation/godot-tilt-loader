class_name TiltBrushManifest
extends Resource

var Brushes: Array[BrushDescriptor] = []
var CompatibilityBrushes: Array[BrushDescriptor] = []

func append_from(rhs: TiltBrushManifest) -> void:
	Brushes = _append_unique(Brushes, rhs.Brushes)
	CompatibilityBrushes = _append_unique(CompatibilityBrushes, rhs.CompatibilityBrushes)

static func _append_unique(lhs: Array[BrushDescriptor], rhs: Array[BrushDescriptor]) -> Array[BrushDescriptor]:
	var output: Array[BrushDescriptor] = []
	for brush in lhs:
		if brush != null and not rhs.has(brush):
			output.append(brush)
	for brush in rhs:
		if brush != null and not output.has(brush):
			output.append(brush)
	return output
