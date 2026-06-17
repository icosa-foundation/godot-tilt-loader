extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_pbr_brush_layout()
	_check_environment_brush_layouts()
	if _failures == 0:
		print("GDSCRIPT_PARITY_LAYOUTBRUSHES: all checks passed")

func _check_pbr_brush_layout() -> void:
	var desc := BrushDescriptor.new()
	var brush := PbrBrushScript.new()
	brush.m_BaseSize_PS = 1.0
	brush.init_brush(desc, TrTransform.identity())
	var layout := brush.get_vertex_layout(desc)
	_expect_equal(layout.texcoord0.size, 2, "pbr uv0 size")
	_expect_equal(layout.texcoord0.semantic, GeometryPool.Semantic.XY_IS_UV, "pbr uv0 semantic")
	_expect(layout.bUseNormals, "pbr normals")
	_expect(layout.bUseColors, "pbr colors")
	_expect(not layout.bUseTangents, "pbr no tangents")
	_check_noop_contract(brush, "pbr")
	brush.free()

func _check_environment_brush_layouts() -> void:
	var desc := BrushDescriptor.new()
	var brush := EnvironmentBrushScript.new()
	brush.m_BaseSize_PS = 1.0
	brush.init_brush(desc, TrTransform.identity())

	var layout_one := brush.get_vertex_layout(desc)
	_expect_equal(layout_one.texcoord0.size, 2, "environment one uv0 size")
	_expect_equal(layout_one.texcoord0.semantic, GeometryPool.Semantic.XY_IS_UV, "environment one uv0 semantic")
	_expect_equal(layout_one.texcoord1.size, 0, "environment one uv1 size")
	_expect_equal(layout_one.texcoord1.semantic, GeometryPool.Semantic.XY_IS_UV, "environment one uv1 semantic")
	_expect(layout_one.bUseNormals, "environment one normals")
	_expect(layout_one.bUseColors, "environment one colors")
	_expect(not layout_one.bUseTangents, "environment one no tangents")

	brush.m_UvSetCount = EnvironmentBrushScript.UvSetCount.TWO
	var layout_two := brush.get_vertex_layout(desc)
	_expect_equal(layout_two.texcoord1.size, 2, "environment two uv1 size")
	_expect_equal(layout_two.texcoord1.semantic, GeometryPool.Semantic.XY_IS_UV, "environment two uv1 semantic")
	_check_noop_contract(brush, "environment")
	brush.free()

func _check_noop_contract(brush: BaseBrushScript, label: String) -> void:
	_expect_equal(brush.get_num_used_verts(), 0, "%s used verts" % label)
	_expect_equal(brush.get_spawn_interval(0.5), 0.0, "%s spawn interval" % label)
	_expect(brush.update_position_ls(TrTransform.t(Vector3.RIGHT), 0.5), "%s update returns true" % label)
	brush.apply_changes_to_visuals()
	brush.finalize_solitary_brush()

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_LAYOUTBRUSHES: %s" % message)
