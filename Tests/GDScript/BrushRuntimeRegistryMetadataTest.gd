extends SceneTree

var _failures := 0

const EXPECTED_NORMAL_PREFAB_COUNTS := {
	"ConcaveHullPrefab": 1,
	"DistanceUV": 19,
	"FlatDistance": 1,
	"FlatStretch": 2,
	"GeniusParticle": 7,
	"HullPrefab": 4,
	"HullPrefabPassthrough": 1,
	"HullPrefabSmooth": 1,
	"Line": 20,
	"LineWithWidth": 1,
	"Lofted": 1,
	"LoftedHueShift": 1,
	"MiddpointPlusLifetimeGeomSpray": 3,
	"MidpointPlusOffset": 3,
	"Slice": 1,
	"Spray": 4,
	"Square3DPrintBrush": 1,
	"SquareBrush_prefab": 1,
	"ThickDistance": 1,
	"Tube_Petal": 1,
	"Tube_Rain": 1,
	"Tube_Sparks": 1,
	"Tube_Spikes": 1,
	"Tube_Tapered": 1,
	"TubeBrush_Comet": 1,
	"TubeDistanceUV": 14,
	"TubeDistanceUVSin": 1,
	"TubeStretchUV": 2,
	"UnitizedUV": 1,
}

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_quad_strip_width_metadata()
	_check_flat_uv_metadata()
	_check_midpoint_plus_offset_metadata()
	_check_thick_uv_metadata()
	_check_genius_particle_catalog_metadata()
	_check_catalog_quad_strip_prefab_routes()
	_check_all_normal_catalog_prefabs_route_to_expected_runtime_classes()
	_check_all_catalog_mesh_metadata_is_applied()
	if _failures == 0:
		print("GDSCRIPT_REGISTRY_METADATA: all checks passed")

func _check_quad_strip_width_metadata() -> void:
	var line := _create_brush("Line", {"m_StoreWidthInTexcoord0Z": false}, "Ink")
	_expect(line is QuadStripBrushStretchUV, "Line creates stretch quad strip")
	_expect(not (line as QuadStripBrushStretchUV).m_StoreWidthInTexcoord0Z, "Line width metadata false")

	var line_with_width := _create_brush("LineWithWidth", {"m_StoreWidthInTexcoord0Z": true}, "Hypercolor")
	_expect(line_with_width is QuadStripBrushStretchUV, "LineWithWidth creates stretch quad strip")
	_expect((line_with_width as QuadStripBrushStretchUV).m_StoreWidthInTexcoord0Z, "LineWithWidth width metadata true")

func _check_flat_uv_metadata() -> void:
	var flat_distance := _create_brush("FlatDistance", {"m_uvStyle": FlatGeometryBrush.UVStyle.DISTANCE}, "DuctTapeGeometry")
	_expect(flat_distance is FlatGeometryBrush, "FlatDistance creates flat brush")
	_expect_equal((flat_distance as FlatGeometryBrush).m_uvStyle, FlatGeometryBrush.UVStyle.DISTANCE, "FlatDistance uv style")

	var flat_stretch := _create_brush("FlatStretch", {"m_uvStyle": FlatGeometryBrush.UVStyle.STRETCH}, "InkGeometry")
	_expect(flat_stretch is FlatGeometryBrush, "FlatStretch creates flat brush")
	_expect_equal((flat_stretch as FlatGeometryBrush).m_uvStyle, FlatGeometryBrush.UVStyle.STRETCH, "FlatStretch uv style")

func _check_midpoint_plus_offset_metadata() -> void:
	var brush := _create_brush("MidpointPlusOffset", {
		"m_uvStyle": FlatGeometryBrush.UVStyle.STRETCH,
		"m_bOffsetInTexcoord1": true,
	}, "DoubleTaperedMarker")
	_expect(brush is FlatGeometryBrush, "MidpointPlusOffset creates flat brush")
	_expect_equal((brush as FlatGeometryBrush).m_uvStyle, FlatGeometryBrush.UVStyle.STRETCH, "MidpointPlusOffset uv style")
	_expect((brush as FlatGeometryBrush).m_bOffsetInTexcoord1, "MidpointPlusOffset offset in texcoord1")

func _check_thick_uv_metadata() -> void:
	var brush := _create_brush("ThickDistance", {"m_uvStyle": ThickGeometryBrush.UVStyle.DISTANCE}, "ThickGeometry")
	_expect(brush is ThickGeometryBrush, "ThickDistance creates thick brush")
	_expect_equal((brush as ThickGeometryBrush).m_uvStyle, ThickGeometryBrush.UVStyle.DISTANCE, "ThickDistance uv style")

func _check_genius_particle_catalog_metadata() -> void:
	var manifest := _load_manifest()
	BrushCatalog.init(manifest)
	BrushRuntimeRegistry.register_supported_brushes(manifest)
	var compatibility := {}
	for brush in manifest.CompatibilityBrushes:
		compatibility[_brush_key(brush)] = true

	var checked := 0
	for desc in manifest.Brushes:
		if desc == null or compatibility.has(_brush_key(desc)):
			continue
		if String(desc.prefab_fields.get("prefab_name", "")) != "GeniusParticle":
			continue
		var brush := BrushRuntimeRegistry.create_brush_for_descriptor(desc)
		_expect(brush is GeniusParticlesBrush, "%s creates GeniusParticlesBrush" % desc.m_DurableName)
		if brush == null:
			continue
		_expect(desc.m_ParticleRate > 0.0, "%s particle rate is nonzero for Open Brush spawn formula" % desc.m_DurableName)
		_expect(desc.m_BrushSizeRange.x != 0.0, "%s brush size min is nonzero for Open Brush particle scale formula" % desc.m_DurableName)
		brush.m_BaseSize_PS = 1.0
		brush.init_brush(desc, TrTransform.identity())
		var genius := brush as GeniusParticlesBrush
		var expected_spawn_interval := (GeniusParticlesBrush.K_SPAWN_INTERVAL_PS * genius.pointer_to_local()) / desc.m_ParticleRate
		var expected_particle_size_scale := desc.m_ParticleSpeed / desc.m_BrushSizeRange.x
		_expect_close(genius.m_SpawnInterval, expected_spawn_interval, "%s particle spawn interval" % desc.m_DurableName)
		_expect_close(genius.m_ParticleSizeScale, expected_particle_size_scale, "%s particle size scale" % desc.m_DurableName)
		_expect_equal(genius.m_Desc.m_RandomizeAlpha, desc.m_RandomizeAlpha, "%s randomize alpha descriptor" % desc.m_DurableName)
		_expect_close(genius.m_Desc.m_ParticleInitialRotationRange, desc.m_ParticleInitialRotationRange, "%s initial rotation range descriptor" % desc.m_DurableName)
		_expect_equal(genius.m_geometry.get_layout().texcoord0.size, 4, "%s GeniusParticle uv0 layout" % desc.m_DurableName)
		_expect_equal(genius.m_geometry.get_layout().texcoord1.size, 3, "%s GeniusParticle uv1 layout" % desc.m_DurableName)
		brush.free()
		checked += 1
	_expect_equal(checked, EXPECTED_NORMAL_PREFAB_COUNTS["GeniusParticle"], "catalog GeniusParticle metadata count")

func _check_catalog_quad_strip_prefab_routes() -> void:
	var manifest := _load_manifest()
	BrushCatalog.init(manifest)
	BrushRuntimeRegistry.register_supported_brushes(manifest)
	var compatibility := {}
	for brush in manifest.CompatibilityBrushes:
		compatibility[_brush_key(brush)] = true
	var checked := 0
	for desc in manifest.Brushes:
		if desc == null or compatibility.has(_brush_key(desc)):
			continue
		var prefab := String(desc.prefab_fields.get("prefab_name", ""))
		if not ["Line", "LineWithWidth", "UnitizedUV", "DistanceUV"].has(prefab):
			continue
		var brush := BrushRuntimeRegistry.create_brush_for_descriptor(desc)
		match prefab:
			"Line", "LineWithWidth":
				_expect(brush is QuadStripBrushStretchUV, "%s routes to QuadStripBrushStretchUV" % desc.m_DurableName)
				if brush is QuadStripBrushStretchUV:
					_expect_equal((brush as QuadStripBrushStretchUV).m_StoreWidthInTexcoord0Z, bool(desc.prefab_fields.get("m_StoreWidthInTexcoord0Z", false)), "%s width metadata" % desc.m_DurableName)
			"UnitizedUV":
				_expect(brush is QuadStripUnitizedUVBrush, "%s routes to QuadStripUnitizedUVBrush" % desc.m_DurableName)
			"DistanceUV":
				_expect(brush is QuadStripBrushDistanceUV, "%s routes to QuadStripBrushDistanceUV" % desc.m_DurableName)
		if brush != null:
			brush.free()
		checked += 1
	_expect(checked > 0, "catalog contains normal quad-strip brushes")

func _check_all_normal_catalog_prefabs_route_to_expected_runtime_classes() -> void:
	var manifest := _load_manifest()
	BrushCatalog.init(manifest)
	BrushRuntimeRegistry.register_supported_brushes(manifest)
	var compatibility := {}
	for brush in manifest.CompatibilityBrushes:
		compatibility[_brush_key(brush)] = true
	var actual_counts := {}
	var checked := 0
	for desc in manifest.Brushes:
		if desc == null or compatibility.has(_brush_key(desc)):
			continue
		var prefab := String(desc.prefab_fields.get("prefab_name", ""))
		actual_counts[prefab] = int(actual_counts.get(prefab, 0)) + 1
		var brush := BrushRuntimeRegistry.create_brush_for_descriptor(desc)
		_expect(brush != null, "%s creates runtime brush for prefab %s" % [desc.m_DurableName, prefab])
		if brush != null:
			_expect_equal(_runtime_class_name(brush), _expected_runtime_class_name(desc), "%s runtime route" % desc.m_DurableName)
			brush.free()
		checked += 1
	_expect_equal(checked, 97, "merged manifest normal live brush count")
	for prefab in EXPECTED_NORMAL_PREFAB_COUNTS.keys():
		_expect_equal(int(actual_counts.get(prefab, 0)), int(EXPECTED_NORMAL_PREFAB_COUNTS[prefab]), "%s merged normal prefab count" % prefab)
	for prefab in actual_counts.keys():
		_expect(EXPECTED_NORMAL_PREFAB_COUNTS.has(prefab), "%s has documented expected normal prefab count" % prefab)

func _expected_runtime_class_name(desc: BrushDescriptor) -> String:
	var prefab := String(desc.prefab_fields.get("prefab_name", ""))
	match prefab:
		"Line", "LineWithWidth":
			return "QuadStripBrushStretchUV"
		"UnitizedUV":
			return "QuadStripUnitizedUVBrush"
		"DistanceUV":
			return "QuadStripBrushDistanceUV"
		"FlatDistance", "FlatStretch", "MidpointPlusOffset":
			return "FlatGeometryBrush"
		"GeniusParticle":
			return "GeniusParticlesBrush"
		"Spray":
			return "SprayBrush"
		"MiddpointPlusLifetimeGeomSpray":
			return "MidpointPlusLifetimeSprayBrush"
		"ConcaveHullPrefab":
			return "ConcaveHullBrush"
		"HullPrefab", "HullPrefabPassthrough", "HullPrefabSmooth":
			return "HullBrush"
		"Square3DPrintBrush":
			return "Square3DPrintBrush"
		"SquareBrush_prefab":
			return "SquareBrush"
		"Slice":
			return "SliceBrush"
		"ThickDistance":
			return "ThickGeometryBrush"
		"TubeDistanceUV", "TubeDistanceUVSin", "TubeStretchUV", "Tube_Petal", "Tube_Rain", "Tube_Sparks", "Tube_Spikes", "Tube_Tapered", "TubeBrush_Comet", "Lofted", "LoftedHueShift":
			return "BubbleWandBrush" if desc.m_DurableName == "BubbleWand" else "TubeBrush"
		_:
			return "<unknown>"

func _runtime_class_name(brush: BaseBrushScript) -> String:
	if brush is BubbleWandBrush:
		return "BubbleWandBrush"
	if brush is TubeBrush:
		return "TubeBrush"
	if brush is QuadStripBrushStretchUV:
		return "QuadStripBrushStretchUV"
	if brush is QuadStripBrushDistanceUV:
		return "QuadStripBrushDistanceUV"
	if brush is QuadStripUnitizedUVBrush:
		return "QuadStripUnitizedUVBrush"
	if brush is FlatGeometryBrush:
		return "FlatGeometryBrush"
	if brush is ThickGeometryBrush:
		return "ThickGeometryBrush"
	if brush is GeniusParticlesBrush:
		return "GeniusParticlesBrush"
	if brush is SprayBrush:
		return "SprayBrush"
	if brush is MidpointPlusLifetimeSprayBrush:
		return "MidpointPlusLifetimeSprayBrush"
	if brush is ConcaveHullBrush:
		return "ConcaveHullBrush"
	if brush is HullBrush:
		return "HullBrush"
	if brush is Square3DPrintBrush:
		return "Square3DPrintBrush"
	if brush is SquareBrush:
		return "SquareBrush"
	if brush is SliceBrush:
		return "SliceBrush"
	return brush.get_class()

func _check_all_catalog_mesh_metadata_is_applied() -> void:
	var manifest := _load_manifest()
	BrushCatalog.init(manifest)
	BrushRuntimeRegistry.register_supported_brushes(manifest)
	var compatibility := {}
	for brush in manifest.CompatibilityBrushes:
		compatibility[_brush_key(brush)] = true

	var checked_fields := 0
	for desc in manifest.Brushes:
		if desc == null or compatibility.has(_brush_key(desc)):
			continue
		var brush := BrushRuntimeRegistry.create_brush_for_descriptor(desc)
		_expect(brush != null, "%s creates runtime brush" % desc.m_DurableName)
		if brush == null:
			continue
		for field in desc.prefab_fields.keys():
			if _is_non_runtime_prefab_field(field):
				continue
			_check_mesh_metadata_field(desc, brush, String(field))
			checked_fields += 1
		brush.free()
	_expect(checked_fields > 0, "catalog contains mesh metadata fields")

func _check_mesh_metadata_field(desc: BrushDescriptor, brush: BaseBrushScript, field: String) -> void:
	var label := "%s %s" % [desc.m_DurableName, field]
	match field:
		"m_StoreWidthInTexcoord0Z":
			_expect(brush is QuadStripBrushStretchUV, "%s applies to stretch quad strip" % label)
			_expect_property_equal(brush, field, bool(desc.prefab_fields[field]), label)
		"m_uvStyle":
			_expect(brush is FlatGeometryBrush or brush is ThickGeometryBrush or brush is TubeBrush, "%s applies to uv-style runtime brush" % label)
			_expect_property_equal(brush, field, int(desc.prefab_fields[field]), label)
		"m_bOffsetInTexcoord1":
			_expect(brush is FlatGeometryBrush, "%s applies to flat brush" % label)
			_expect_property_equal(brush, field, bool(desc.prefab_fields[field]), label)
		"m_Faceted", "m_TrackInterior":
			_expect(brush is HullBrush or brush is ConcaveHullBrush, "%s applies to hull brush" % label)
			_expect_property_equal(brush, field, bool(desc.prefab_fields[field]), label)
		"m_KnotConversion":
			_expect(brush is HullBrush or brush is ConcaveHullBrush, "%s applies to hull brush" % label)
			_expect_property_equal(brush, field, int(desc.prefab_fields[field]), label)
		"m_Simplification_PS":
			_expect(brush is HullBrush, "%s applies to hull brush" % label)
			_expect_property_equal(brush, field, float(desc.prefab_fields[field]), label)
		"m_SimplifyMode":
			_expect(brush is HullBrush, "%s applies to hull brush" % label)
			_expect_property_equal(brush, field, int(desc.prefab_fields[field]), label)
		"m_KnotsInHull":
			_expect(brush is ConcaveHullBrush, "%s applies to concave hull brush" % label)
			_expect_property_equal(brush, field, int(desc.prefab_fields[field]), label)
		"m_CapAspect", "m_TaperScalar", "m_PetalDisplacementAmt", "m_PetalDisplacementExp", "m_BreakAngleMultiplier":
			_expect(brush is TubeBrush, "%s applies to tube brush" % label)
			_expect_property_equal(brush, field, float(desc.prefab_fields[field]), label)
		"m_PointsInClosedCircle", "m_ShapeModifier":
			_expect(brush is TubeBrush, "%s applies to tube brush" % label)
			_expect_property_equal(brush, field, int(desc.prefab_fields[field]), label)
		"m_EndCaps", "m_HardEdges":
			_expect(brush is TubeBrush, "%s applies to tube brush" % label)
			_expect_property_equal(brush, field, bool(desc.prefab_fields[field]), label)
		_:
			_fail("%s has unclassified mesh metadata field" % label)

func _is_non_runtime_prefab_field(field: Variant) -> bool:
	return ["prefab_name", "prefab_path", "script_guid"].has(String(field))

func _expect_property_equal(brush: BaseBrushScript, field: String, expected: Variant, label: String) -> void:
	var actual: Variant = brush.get(field)
	match typeof(expected):
		TYPE_FLOAT:
			if not is_equal_approx(float(actual), float(expected)):
				_fail("%s expected %s but got %s" % [label, expected, actual])
		TYPE_INT:
			if int(actual) != int(expected):
				_fail("%s expected %s but got %s" % [label, expected, actual])
		TYPE_BOOL:
			if bool(actual) != bool(expected):
				_fail("%s expected %s but got %s" % [label, expected, actual])
		_:
			if actual != expected:
				_fail("%s expected %s but got %s" % [label, expected, actual])

func _create_brush(prefab_name: String, fields: Dictionary, durable_name: String) -> BaseBrushScript:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = durable_name
	desc.prefab_fields = fields.duplicate(true)
	desc.prefab_fields["prefab_name"] = prefab_name
	return BrushRuntimeRegistry.create_brush_for_descriptor(desc)

func _load_manifest() -> TiltBrushManifest:
	var project_path := ProjectSettings.globalize_path("res://")
	var manifest := UnityAssetLoader.load_manifest(project_path.path_join("Manifest.asset"))
	var experimental := UnityAssetLoader.load_manifest(project_path.path_join("Manifest_Experimental.asset"))
	manifest.append_from(experimental)
	return manifest

func _brush_key(brush: BrushDescriptor) -> String:
	return brush.m_Guid.strip_edges().to_lower().replace("-", "") if brush != null else ""

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_REGISTRY_METADATA: %s" % message)
