class_name BrushRuntimeRegistry
extends RefCounted

static func register_supported_brushes(manifest: TiltBrushManifest = null) -> void:
	BaseBrushScript.clear_brush_types()
	var descriptor_factory := Callable(BrushRuntimeRegistry, "create_brush_for_descriptor")
	if manifest == null:
		BaseBrushScript.register_brush_type("Ink", descriptor_factory)
		return

	var compatibility_guids := _compatibility_guid_lookup(manifest)
	var skipped_count := 0
	for brush in manifest.Brushes:
		if brush == null:
			continue
		if compatibility_guids.has(_brush_key(brush)):
			continue
		if _has_factory_for_brush(brush):
			BaseBrushScript.register_brush_type(brush.m_DurableName, descriptor_factory)
		else:
			skipped_count += 1
			push_warning("BrushRuntimeRegistry: no live factory for %s (%s)" % [brush.m_DurableName, _prefab_name(brush)])
	print("BrushRuntimeRegistry: registered %d live brushes, skipped %d" % [BaseBrushScript.registered_brush_count(), skipped_count])

static func create_brush_for_descriptor(desc: BrushDescriptor) -> BaseBrushScript:
	if desc == null:
		return null
	return _create_brush(_prefab_name(desc), desc.prefab_fields.duplicate(true), desc.m_DurableName)

static func is_supported(brush: BrushDescriptor) -> bool:
	return brush != null and BaseBrushScript.has_brush_type(brush.m_DurableName)

static func is_compatibility_brush(manifest: TiltBrushManifest, brush: BrushDescriptor) -> bool:
	if manifest == null or brush == null:
		return false
	var key := _brush_key(brush)
	for compatibility_brush in manifest.CompatibilityBrushes:
		if _brush_key(compatibility_brush) == key:
			return true
	return false

static func _compatibility_guid_lookup(manifest: TiltBrushManifest) -> Dictionary:
	var output := {}
	for brush in manifest.CompatibilityBrushes:
		var key := _brush_key(brush)
		if key != "":
			output[key] = true
	return output

static func _brush_key(brush: BrushDescriptor) -> String:
	if brush == null:
		return ""
	return brush.m_Guid.strip_edges().to_lower().replace("-", "")

static func _has_factory_for_brush(brush: BrushDescriptor) -> bool:
	var prefab := _prefab_name(brush)
	if prefab == "":
		return false
	return _prefab_has_factory(prefab)

static func _prefab_has_factory(prefab: String) -> bool:
	return [
		"Line",
		"LineWithWidth",
		"UnitizedUV",
		"DistanceUV",
		"FlatDistance",
		"FlatStretch",
		"GeniusParticle",
		"Spray",
		"MiddpointPlusLifetimeGeomSpray",
		"MidpointPlusOffset",
		"ConcaveHullPrefab",
		"HullPrefab",
		"HullPrefabPassthrough",
		"HullPrefabSmooth",
		"Square3DPrintBrush",
		"SquareBrush_prefab",
		"Slice",
		"ThickDistance",
		"TubeDistanceUV",
		"TubeDistanceUVSin",
		"TubeStretchUV",
		"Tube_Petal",
		"Tube_Rain",
		"Tube_Sparks",
		"Tube_Spikes",
		"Tube_Tapered",
		"TubeBrush_Comet",
		"Lofted",
		"LoftedHueShift",
	].has(prefab)

static func _create_brush(prefab: String, fields: Dictionary, durable_name: String) -> BaseBrushScript:
	var brush: BaseBrushScript = null
	match prefab:
		"Line":
			brush = QuadStripBrushStretchUV.new()
		"LineWithWidth":
			brush = QuadStripBrushStretchUV.new()
		"UnitizedUV":
			brush = QuadStripUnitizedUVBrush.new()
		"DistanceUV":
			brush = QuadStripBrushDistanceUV.new()
		"FlatDistance":
			brush = FlatGeometryBrush.new()
		"FlatStretch":
			brush = FlatGeometryBrush.new()
		"GeniusParticle":
			brush = GeniusParticlesBrush.new()
		"Spray":
			brush = SprayBrush.new()
		"MiddpointPlusLifetimeGeomSpray":
			brush = MidpointPlusLifetimeSprayBrush.new()
		"MidpointPlusOffset":
			brush = FlatGeometryBrush.new()
		"ConcaveHullPrefab":
			brush = ConcaveHullBrush.new()
		"HullPrefab", "HullPrefabPassthrough", "HullPrefabSmooth":
			brush = HullBrush.new()
		"Square3DPrintBrush":
			brush = Square3DPrintBrush.new()
		"SquareBrush_prefab":
			brush = SquareBrush.new()
		"Slice":
			brush = SliceBrush.new()
		"ThickDistance":
			brush = ThickGeometryBrush.new()
		"TubeDistanceUV", "TubeDistanceUVSin", "TubeStretchUV", "Tube_Petal", "Tube_Rain", "Tube_Sparks", "Tube_Spikes", "Tube_Tapered", "TubeBrush_Comet", "Lofted", "LoftedHueShift":
			brush = BubbleWandBrush.new() if durable_name == "BubbleWand" else TubeBrush.new()
		_:
			return null
	if brush != null:
		_apply_prefab_fields(brush, fields)
	return brush

static func _prefab_name(brush: BrushDescriptor) -> String:
	if brush == null or brush.prefab_fields == null:
		return ""
	return String(brush.prefab_fields.get("prefab_name", ""))

static func _apply_prefab_fields(brush: BaseBrushScript, fields: Dictionary) -> void:
	if brush is TubeBrush:
		_apply_tube_fields(brush as TubeBrush, fields)
	elif brush is QuadStripBrushStretchUV:
		(brush as QuadStripBrushStretchUV).m_StoreWidthInTexcoord0Z = bool(fields.get("m_StoreWidthInTexcoord0Z", (brush as QuadStripBrushStretchUV).m_StoreWidthInTexcoord0Z))
	elif brush is FlatGeometryBrush:
		_apply_flat_fields(brush as FlatGeometryBrush, fields)
	elif brush is ThickGeometryBrush:
		(brush as ThickGeometryBrush).m_uvStyle = int(fields.get("m_uvStyle", (brush as ThickGeometryBrush).m_uvStyle))
	elif brush is HullBrush:
		_apply_hull_fields(brush as HullBrush, fields)
	elif brush is ConcaveHullBrush:
		_apply_concave_hull_fields(brush as ConcaveHullBrush, fields)

static func _apply_tube_fields(brush: TubeBrush, fields: Dictionary) -> void:
	brush.m_CapAspect = float(fields.get("m_CapAspect", brush.m_CapAspect))
	brush.m_PointsInClosedCircle = int(fields.get("m_PointsInClosedCircle", brush.m_PointsInClosedCircle))
	brush.m_EndCaps = bool(fields.get("m_EndCaps", brush.m_EndCaps))
	brush.m_HardEdges = bool(fields.get("m_HardEdges", brush.m_HardEdges))
	brush.m_uvStyle = int(fields.get("m_uvStyle", brush.m_uvStyle))
	brush.m_ShapeModifier = int(fields.get("m_ShapeModifier", brush.m_ShapeModifier))
	brush.m_TaperScalar = float(fields.get("m_TaperScalar", brush.m_TaperScalar))
	brush.m_PetalDisplacementAmt = float(fields.get("m_PetalDisplacementAmt", brush.m_PetalDisplacementAmt))
	brush.m_PetalDisplacementExp = float(fields.get("m_PetalDisplacementExp", brush.m_PetalDisplacementExp))
	brush.m_BreakAngleMultiplier = float(fields.get("m_BreakAngleMultiplier", brush.m_BreakAngleMultiplier))

static func _apply_flat_fields(brush: FlatGeometryBrush, fields: Dictionary) -> void:
	brush.m_uvStyle = int(fields.get("m_uvStyle", brush.m_uvStyle))
	brush.m_bOffsetInTexcoord1 = bool(fields.get("m_bOffsetInTexcoord1", brush.m_bOffsetInTexcoord1))

static func _apply_hull_fields(brush: HullBrush, fields: Dictionary) -> void:
	brush.m_Faceted = bool(fields.get("m_Faceted", brush.m_Faceted))
	brush.m_TrackInterior = bool(fields.get("m_TrackInterior", brush.m_TrackInterior))
	brush.m_KnotConversion = int(fields.get("m_KnotConversion", brush.m_KnotConversion))
	brush.m_Simplification_PS = float(fields.get("m_Simplification_PS", brush.m_Simplification_PS))
	brush.m_SimplifyMode = int(fields.get("m_SimplifyMode", brush.m_SimplifyMode))

static func _apply_concave_hull_fields(brush: ConcaveHullBrush, fields: Dictionary) -> void:
	brush.m_KnotsInHull = int(fields.get("m_KnotsInHull", brush.m_KnotsInHull))
	brush.m_Faceted = bool(fields.get("m_Faceted", brush.m_Faceted))
	brush.m_KnotConversion = int(fields.get("m_KnotConversion", brush.m_KnotConversion))
