extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_distance_uv_geometry()
	_check_unitized_uv_geometry()
	if _failures == 0:
		print("GDSCRIPT_PARITY_TETRABRUSH: all checks passed")

func _check_distance_uv_geometry() -> void:
	var brush := _make_tetra_brush(TetraBrush.UVStyle.DISTANCE)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "tetra first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "tetra second update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "tetra knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 10, "tetra vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 30, "tetra triangle index count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 15), [0, 4, 1, 1, 4, 2, 2, 4, 3, 0, 1, 2, 2, 3, 0], "tetra first tris")
	_expect_equal(brush.m_knots[1].nVert, 5, "tetra first knot verts")
	_expect_equal(brush.m_knots[1].nTri, 5, "tetra first knot tris")
	_expect_equal(brush.m_knots[2].iVert, 5, "tetra second knot vertex start")

	_expect_vec3_close(brush.m_geometry.m_Vertices[0], brush.m_geometry.m_Vertices[3], "tetra closed circle")
	_expect_close(brush.m_geometry.m_Vertices[0].distance_to(Vector3.ZERO), 0.5, "tetra circle radius")
	_expect_vec3_close(brush.m_geometry.m_Vertices[4], Vector3.RIGHT, "tetra first front point")
	_expect_vec3_close(brush.m_geometry.m_Vertices[9], Vector3(2.0, 0.0, 0.0), "tetra second front point")
	_expect_close(brush.m_geometry.m_Normals[0].length(), 1.0, "tetra circle normal length")
	_expect_close(brush.m_geometry.m_Tangents[0].length(), sqrt(2.0), "tetra tangent length includes handedness")
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.3, 0.2, 0.8, 1.0)), "tetra color32 color")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[0].y, 0.0, "tetra uv y0")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[1].y, 1.0 / 3.0, "tetra uv y1")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[3].y, 1.0, "tetra uv y3")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 10, "tetra finalized vertex count")
	_expect(brush.m_geometry == null, "tetra releases geometry")
	brush.free()

func _check_unitized_uv_geometry() -> void:
	var brush := _make_tetra_brush(TetraBrush.UVStyle.UNITIZED)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "tetra unitized update keeps")
	brush.apply_changes_to_visuals()
	_expect_equal(brush.m_geometry.num_verts(), 5, "tetra unitized vertex count")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[0], Vector2(0.0, 0.0), "tetra unitized uv0")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[1], Vector2(0.0, 1.0), "tetra unitized uv1")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[3], Vector2(0.0, 3.0), "tetra unitized uv3")
	brush.finalize_solitary_brush()
	brush.free()

func _make_tetra_brush(uv_style: int) -> TetraBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Tetra"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := TetraBrush.new()
	brush.m_uvStyle = uv_style
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.3, 0.2, 0.8, 1.0)
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
	push_error("GDSCRIPT_PARITY_TETRABRUSH: %s" % message)
