extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_spray_geometry()
	_check_preview_decay_bookkeeping()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SPRAYBRUSH: all checks passed")

func _check_spray_geometry() -> void:
	var brush := _make_spray_brush(true)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "spray update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "spray knot invariants")
	_expect_equal(brush.NS, 2, "spray double-sided stride")
	_expect_equal(brush.m_knots[1].nVert, 16, "spray spawned two double-sided quads")
	_expect_equal(brush.m_geometry.num_verts(), 16, "spray vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 24, "spray tri index count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 2, 6, 7, 3, 1], "spray double-sided first tri")

	_expect_vec3_close(brush.m_geometry.m_Vertices[SprayBrush.BR * brush.NS], Vector3(-0.5, 0.5, 0.0), "spray first br")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SprayBrush.BL * brush.NS], Vector3(-0.5, -0.5, 0.0), "spray first bl")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SprayBrush.FR * brush.NS], Vector3(0.5, 0.5, 0.0), "spray first fr")
	_expect_vec3_close(brush.m_geometry.m_Vertices[8 + SprayBrush.BR * brush.NS], Vector3(0.5, 0.5, 0.0), "spray second br")
	_expect_vec3_close(brush.m_geometry.m_Vertices[8 + SprayBrush.FR * brush.NS], Vector3(1.5, 0.5, 0.0), "spray second fr")
	_expect_vec3_close(brush.m_geometry.m_Normals[0], Vector3.BACK, "spray normal")
	_expect_vec3_close(brush.m_geometry.m_Normals[1], -Vector3.BACK, "spray backface normal")
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.9, 0.4, 0.1, 1.0)), "spray color32 color")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[SprayBrush.BL * brush.NS], Vector2(0.0, 0.0), "spray uv bl")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[SprayBrush.FR * brush.NS], Vector2(1.0, 1.0), "spray uv fr")
	_expect_close(brush.m_geometry.m_Tangents[0].length(), sqrt(2.0), "spray tangent length includes handedness")
	_expect_close(brush.m_geometry.m_Tangents[1].w, -1.0, "spray backface tangent handedness")
	_expect(brush.needs_straight_edge_proxy(), "spray straight edge proxy")
	_expect(not brush.always_rebuild_preview_brush(), "spray no preview rebuild")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 16, "spray finalized vertex count")
	_expect(brush.m_geometry == null, "spray releases geometry")
	brush.free()

func _check_preview_decay_bookkeeping() -> void:
	var brush := _make_spray_brush(true)
	brush.set_preview_mode()
	brush.reset_brush_for_preview(TrTransform.identity())
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "spray preview update keeps")
	_expect_equal(brush.m_DecayTimers.size(), 1, "spray preview decay timer")
	brush.free()

func _make_spray_brush(backfaces: bool) -> SprayBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Spray"
	desc.m_RenderBackfaces = backfaces
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = 1
	desc.m_SprayRateMultiplier = 1.0
	desc.m_RotationVariance = 0.0
	desc.m_PositionVariance = 0.0
	desc.m_SizeRatio = Vector2(1.0, 1.0)
	desc.m_RandomizeAlpha = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := SprayBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.9, 0.4, 0.1, 1.0)
	brush.set_random_seed(0)
	brush.init_brush(desc, TrTransform.identity())
	brush.set_random_seed(0)
	return brush

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
	push_error("GDSCRIPT_PARITY_SPRAYBRUSH: %s" % message)
