extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_printable_brush_geometry()
	if _failures == 0:
		print("GDSCRIPT_PARITY_PRINTABLEBRUSH: all checks passed")

func _check_printable_brush_geometry() -> void:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Printable"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := PrintableBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.6, 0.4, 0.2, 0.1)
	brush.init_brush(desc, TrTransform.identity())
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "printable update keeps one solid")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "printable knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 8, "printable vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 36, "printable triangle index count")
	_expect_equal(brush.m_knots[1].nTri, 12, "printable knot triangle count with caps")
	_expect_close(brush.m_knots[0].qFrame.x, 0.8, "printable initial envelope")
	_expect_close(brush.m_knots[1].qFrame.x, 1.0, "printable front envelope")

	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [2, 1, 6, 6, 1, 5], "printable top tris")
	_expect_equal(brush.m_geometry.m_Tris.slice(24, 30), [2, 0, 1, 1, 0, 3], "printable start cap tris")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.BR], Vector3(0.0, 0.4, 0.0), "printable back right envelope")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.BT], Vector3(0.0, 0.0, 0.15), "printable back top envelope")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.FR], Vector3(1.0, 0.5, 0.0), "printable front right")
	_expect_vec3_close(brush.m_geometry.m_Vertices[PrintableBrush.FT], Vector3(1.0, 0.0, 0.1875), "printable front top")
	_expect_vec3_close(brush.m_geometry.m_Normals[PrintableBrush.FL], Vector3.DOWN, "printable left normal")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[PrintableBrush.FB], Vector2(0.5, 0.5), "printable default uv")
	_expect_color_close(brush.m_geometry.m_Colors[PrintableBrush.FB], _color32(Color(0.6, 0.4, 0.2, 1.0)), "printable color32 alpha forced opaque")

	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 8, "printable finalized vertex count")
	_expect(brush.m_geometry == null, "printable releases geometry")
	brush.free()

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _expect_vec3_close(actual: Vector3, expected: Vector3, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)
	_expect_close(actual.z, expected.z, "%s z" % label)

func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _expect_color_close(actual: Color, expected: Color, label: String) -> void:
	_expect_close(actual.r, expected.r, "%s r" % label)
	_expect_close(actual.g, expected.g, "%s g" % label)
	_expect_close(actual.b, expected.b, "%s b" % label)
	_expect_close(actual.a, expected.a, "%s a" % label)

func _color32_channel(value: float) -> float:
	return float(int(clamp(value, 0.0, 1.0) * 255.0)) / 255.0

func _color32(value: Color) -> Color:
	return Color(
		_color32_channel(value.r),
		_color32_channel(value.g),
		_color32_channel(value.b),
		_color32_channel(value.a)
	)

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_PRINTABLEBRUSH: %s" % message)
