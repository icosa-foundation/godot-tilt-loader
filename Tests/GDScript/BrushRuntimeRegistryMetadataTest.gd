extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_quad_strip_width_metadata()
	_check_flat_uv_metadata()
	_check_midpoint_plus_offset_metadata()
	_check_thick_uv_metadata()
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

func _create_brush(prefab_name: String, fields: Dictionary, durable_name: String) -> BaseBrushScript:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = durable_name
	desc.prefab_fields = fields.duplicate(true)
	desc.prefab_fields["prefab_name"] = prefab_name
	return BrushRuntimeRegistry.create_brush_for_descriptor(desc)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_REGISTRY_METADATA: %s" % message)
