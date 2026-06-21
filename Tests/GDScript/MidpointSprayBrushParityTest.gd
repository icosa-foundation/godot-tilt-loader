extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	App.force_deterministic_birth_time_for_export = true
	_check_midpoint_geometry_and_uv1()
	_check_finalize_preserves_generated_particles()
	App.force_deterministic_birth_time_for_export = false
	_check_midpoint_birth_time_in_uv1()
	if _failures == 0:
		print("GDSCRIPT_PARITY_MIDPOINTSPRAY: all checks passed")

func _check_midpoint_geometry_and_uv1() -> void:
	var brush := _make_midpoint_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "midpoint update keeps")
	brush.apply_changes_to_visuals()

	var layout := brush.get_vertex_layout(brush.m_Desc)
	_expect_equal(layout.texcoord1.size, 4, "midpoint uv1 size")
	_expect_equal(layout.texcoord1.semantic, GeometryPool.Semantic.VECTOR, "midpoint uv1 semantic")
	_expect_equal(brush.NS, 1, "midpoint single-sided stride")
	_expect_equal(brush.m_geometry.num_verts(), 8, "midpoint vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 12, "midpoint tri count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 1, 3, 0, 3, 2], "midpoint first tris")

	_expect_vec3_close(brush.m_geometry.m_Vertices[MidpointPlusLifetimeSprayBrush.BR], Vector3(-0.5, 0.5, 0.0), "midpoint first br")
	_expect_vec3_close(brush.m_geometry.m_Vertices[MidpointPlusLifetimeSprayBrush.FL], Vector3(0.5, -0.5, 0.0), "midpoint first fl")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[MidpointPlusLifetimeSprayBrush.BL], Vector2(0.0, 0.0), "midpoint uv0 bl")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[MidpointPlusLifetimeSprayBrush.FR], Vector2(1.0, 1.0), "midpoint uv0 fr")
	_expect_equal(brush.m_geometry.m_Texcoord1.v4[MidpointPlusLifetimeSprayBrush.BR], Vector4(-0.5, 0.5, 0.0, 0.0), "midpoint uv1 br")
	_expect_equal(brush.m_geometry.m_Texcoord1.v4[MidpointPlusLifetimeSprayBrush.FL], Vector4(0.5, -0.5, 0.0, 0.0), "midpoint uv1 fl")
	_expect_close(brush.m_geometry.m_Tangents[0].length(), sqrt(2.0), "midpoint tangent length includes handedness")
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.45, 0.8, 0.2, 1.0)), "midpoint color32 color")
	brush.free()

func _check_finalize_preserves_generated_particles() -> void:
	var brush := _make_midpoint_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "midpoint finalize update keeps")
	brush.apply_changes_to_visuals()
	var expected_vertices := brush.m_geometry.m_Vertices.duplicate()
	var expected_uv1 := brush.m_geometry.m_Texcoord1.v4.duplicate()
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), expected_vertices.size(), "midpoint finalize keeps generated particles")
	_expect_equal(brush.mesh_data.triangles.size(), 12, "midpoint finalize tri count")
	_expect_vec3_close(brush.mesh_data.vertices[4], expected_vertices[4], "midpoint finalize preserves second particle br")
	_expect_vec4_close(brush.mesh_data.uv1_v4[4], expected_uv1[4], "midpoint finalize preserves second particle uv1")
	_expect(brush.m_geometry == null, "midpoint releases geometry")
	brush.free()

func _check_midpoint_birth_time_in_uv1() -> void:
	var brush := _make_midpoint_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "midpoint birth time update keeps")
	brush.apply_changes_to_visuals()
	_expect(brush.m_geometry.m_Texcoord1.v4[MidpointPlusLifetimeSprayBrush.BR].w > 0.0, "midpoint uv1 birth time is positive")
	brush.free()

func _make_midpoint_brush() -> MidpointPlusLifetimeSprayBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "MidpointSpray"
	desc.m_RenderBackfaces = false
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

	var brush := MidpointPlusLifetimeSprayBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.45, 0.8, 0.2, 1.0)
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

func _expect_vec4_close(actual: Vector4, expected: Vector4, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)
	_expect_close(actual.z, expected.z, "%s z" % label)
	_expect_close(actual.w, expected.w, "%s w" % label)

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
	push_error("GDSCRIPT_PARITY_MIDPOINTSPRAY: %s" % message)
