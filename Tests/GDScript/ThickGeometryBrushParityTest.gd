extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_distance_uv_geometry()
	_check_distance_uv_atlas_branch()
	_check_stretch_uv_geometry()
	_check_stretch_uv_atlas_branch()
	if _failures == 0:
		print("GDSCRIPT_PARITY_THICKBRUSH: all checks passed")

func _check_distance_uv_geometry() -> void:
	var brush := _make_thick_brush(ThickGeometryBrush.UVStyle.DISTANCE)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "thick distance first update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "thick distance invariants")
	_expect_equal(brush.m_geometry.num_verts(), 12, "thick distance vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 24, "thick distance tri index count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 2, 8, 0, 8, 6], "thick first top-right tris")
	_expect_vec3_close(brush.m_geometry.m_Vertices[ThickGeometryBrush.BRT], Vector3(0.0, 0.5, 0.0), "thick back right top")
	_expect_vec3_close(brush.m_geometry.m_Vertices[ThickGeometryBrush.BMT], Vector3.ZERO, "thick back middle top")
	_expect_vec3_close(brush.m_geometry.m_Vertices[ThickGeometryBrush.BLT], Vector3(0.0, -0.5, 0.0), "thick back left top")
	_expect_vec3_close(brush.m_geometry.m_Vertices[ThickGeometryBrush.FMT], Vector3.RIGHT, "thick front pinched middle")
	_expect_vec3_close(brush.m_geometry.m_Normals[ThickGeometryBrush.BRT], Vector3.BACK, "thick back top normal")
	_expect_vec3_close(brush.m_geometry.m_Normals[ThickGeometryBrush.BRB], -Vector3.BACK, "thick back bottom normal")
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.2, 0.7, 0.4, 0.75)), "thick color32 color")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BLT].y, 0.1, "thick uv left chop")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BRT].y, 0.9, "thick uv right chop")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.FLT].x - brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BLT].x, 1.0, "thick distance u delta")
	_expect_close(brush.m_geometry.m_Tangents[0].length(), sqrt(2.0), "thick tangent length includes handedness")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 12, "thick finalized vertex count")
	_expect(brush.m_geometry == null, "thick releases geometry")
	brush.free()

func _check_distance_uv_atlas_branch() -> void:
	var brush := _make_thick_brush(ThickGeometryBrush.UVStyle.DISTANCE, 4)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "thick distance atlas update keeps")
	brush.apply_changes_to_visuals()

	var random01 := brush.m_rng.in01(brush.m_knots[1].iVert - 1)
	var atlas := int(random01 * 3331.0) % brush.m_Desc.m_TextureAtlasV
	var v0 := (atlas + brush.m_TextureEdgeChop) / float(brush.m_Desc.m_TextureAtlasV)
	var v1 := (atlas + 1.0 - brush.m_TextureEdgeChop) / float(brush.m_Desc.m_TextureAtlasV)
	var vmid := (v0 + v1) * 0.5
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BLT].x, random01, "thick distance atlas initial u")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BLT].y, v0, "thick distance atlas left y")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BRT].y, v1, "thick distance atlas right y")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BMT].y, vmid, "thick distance atlas middle y")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_geometry() -> void:
	var brush := _make_thick_brush(ThickGeometryBrush.UVStyle.STRETCH)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "thick stretch first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "thick stretch second update keeps")
	brush.apply_changes_to_visuals()

	_expect_equal(brush.m_geometry.num_verts(), 18, "thick stretch shared vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 48, "thick stretch tri index count")
	_expect_equal(brush.m_knots[1].iVert, 0, "thick first knot vertex start")
	_expect_equal(brush.m_knots[2].iVert, 6, "thick second knot shared start")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BLT].x, 0.0, "thick stretch start x")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.FLT].x, 0.5, "thick stretch first end x")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[6 + ThickGeometryBrush.FLT].x, 1.0, "thick stretch second end x")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_atlas_branch() -> void:
	var brush := _make_thick_brush(ThickGeometryBrush.UVStyle.STRETCH, 4)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "thick stretch atlas first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "thick stretch atlas second update keeps")
	brush.apply_changes_to_visuals()

	var random01 := brush.m_rng.in01(brush.m_knots[1].iVert - 1)
	var atlas := int(random01 * 3331.0) % brush.m_Desc.m_TextureAtlasV
	var v0 := (atlas + brush.m_TextureEdgeChop) / float(brush.m_Desc.m_TextureAtlasV)
	var v1 := (atlas + 1.0 - brush.m_TextureEdgeChop) / float(brush.m_Desc.m_TextureAtlasV)
	var vmid := (v0 + v1) * 0.5
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BLT].y, v0, "thick stretch atlas left y")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BRT].y, v1, "thick stretch atlas right y")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[ThickGeometryBrush.BMT].y, vmid, "thick stretch atlas middle y")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[6 + ThickGeometryBrush.FLT].y, v0, "thick stretch atlas second left y")
	brush.finalize_solitary_brush()
	brush.free()

func _make_thick_brush(uv_style: int, texture_atlas_v: int = 1) -> ThickGeometryBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Thick"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = true
	desc.m_TextureAtlasV = texture_atlas_v
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 0.75
	desc.m_SizeVariance = 0.0

	var brush := ThickGeometryBrush.new()
	brush.m_uvStyle = uv_style
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.2, 0.7, 0.4, 1.0)
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

func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_THICKBRUSH: %s" % message)
