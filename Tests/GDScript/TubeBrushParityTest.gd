extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_default_soft_tube()
	_check_hard_edge_radius_uv_layout()
	_check_distance_uv_atlas_branch()
	_check_stretch_uvs()
	_check_shape_modifier_updates_vertices()
	if _failures == 0:
		print("GDSCRIPT_PARITY_TUBEBRUSH: all checks passed")

func _check_default_soft_tube() -> void:
	var brush := _make_tube_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "tube first update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "tube knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 34, "tube default vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 96, "tube default triangle index count")
	_expect_equal(brush.m_knots[1].nVert, 34, "tube first knot verts")
	_expect_equal(brush.m_knots[1].nTri, 32, "tube first knot tris")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 12), [0, 8, 9, 1, 9, 10, 2, 10, 11, 3, 11, 12], "tube first cap tris")
	_expect_vec3_close(brush.m_geometry.m_Vertices[8], brush.m_geometry.m_Vertices[16], "tube back circle closed seam")
	_expect_vec3_close(brush.m_geometry.m_Vertices[17], brush.m_geometry.m_Vertices[25], "tube front circle closed seam")
	_expect_close(brush.m_geometry.m_Vertices[8].distance_to(Vector3.ZERO), 0.5, "tube back radius")
	_expect_close(brush.m_geometry.m_Vertices[17].distance_to(Vector3.RIGHT), 0.5, "tube front radius")
	_expect_close(brush.m_geometry.m_Normals[8].length(), 1.0, "tube normal length")
	_expect_close(brush.m_geometry.m_Tangents[8].w, -1.0, "tube reflected tangent handedness")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[8].y, 0.0, "tube uv v0")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[16].y, 1.0, "tube uv v1")
	_expect_color_close(brush.m_geometry.m_Colors[8], _color32(Color(0.2, 0.6, 0.9, 1.0)), "tube color32 color")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 34, "tube finalized vertex count")
	_expect(brush.m_geometry == null, "tube releases geometry")
	brush.free()

func _check_hard_edge_radius_uv_layout() -> void:
	var brush := _make_tube_brush(true, false, false, true, 6)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "tube hard update keeps")
	brush.apply_changes_to_visuals()

	_expect_equal(brush.m_geometry.get_layout().texcoord0.size, 3, "tube radius uv layout")
	_expect_equal(brush.m_geometry.num_verts(), 24, "tube hard vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 36, "tube hard triangle index count")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[0].z, 0.5, "tube radius uv z")
	_expect_vec3_close(brush.m_geometry.m_Vertices[0], brush.m_geometry.m_Vertices[1], "tube hard duplicate edge")
	_expect_vec3_close(brush.m_geometry.m_Vertices[12], brush.m_geometry.m_Vertices[13], "tube hard front duplicate edge")
	brush.free()

func _check_distance_uv_atlas_branch() -> void:
	var brush := _make_tube_brush(false, true, false, false, 8, 4)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "tube atlas update keeps")
	brush.apply_changes_to_visuals()

	var random01 := brush.m_rng.in01(brush.m_knots[1].iVert - 1)
	var atlas := int(random01 * 3331.0) % brush.m_Desc.m_TextureAtlasV
	var v0 := atlas / float(brush.m_Desc.m_TextureAtlasV)
	var v1 := (atlas + 1.0) / float(brush.m_Desc.m_TextureAtlasV)
	_expect_close(brush.m_geometry.m_Texcoord0.v2[8].x, random01, "tube atlas u")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[8].y, v0, "tube atlas v0")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[16].y, v1, "tube atlas v1")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uvs() -> void:
	var brush := _make_tube_brush(false, true, true)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "tube stretch first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "tube stretch second update keeps")
	brush.apply_changes_to_visuals()

	_expect_close(brush.m_geometry.m_Texcoord0.v2[0].x, 0.0, "tube stretch first knot u")
	_expect_close(brush.m_geometry.m_Texcoord0.v2[34].x, 0.5, "tube stretch second knot u")
	brush.free()

func _check_shape_modifier_updates_vertices() -> void:
	var plain := _make_tube_brush()
	_expect(plain.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "tube plain first update keeps")
	_expect(plain.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "tube plain second update keeps")
	plain.apply_changes_to_visuals()
	var plain_vertex := plain.m_geometry.m_Vertices[17]

	var shaped := _make_tube_brush()
	shaped.m_ShapeModifier = TubeBrush.ShapeModifier.SIN
	shaped.m_Displacements.clear()
	_expect(shaped.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "tube shaped first update keeps")
	_expect(shaped.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "tube shaped second update keeps")
	shaped.apply_changes_to_visuals()

	_expect(shaped.m_Displacements.size() >= shaped.m_geometry.num_verts(), "tube stores displacement directions")
	_expect(shaped.m_geometry.m_Vertices[17].distance_to(plain_vertex) > 0.001, "tube modifier changes vertex")
	plain.free()
	shaped.free()

func _make_tube_brush(hard_edges: bool = false, end_caps: bool = true, stretch_uvs: bool = false, radius_in_uv0_z: bool = false, points_in_closed_circle: int = 8, texture_atlas_v: int = 1) -> TubeBrush:
	var desc := BrushDescriptor.new()
	desc.name = "LightWire"
	desc.m_Guid = "4391aaaa-df81-4396-9e33-31e4e4930b27"
	desc.m_DurableName = "LightWire"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = texture_atlas_v
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0
	desc.m_SolidMinLengthMeters_PS = 0.002
	desc.m_TubeStoreRadiusInTexcoord0Z = radius_in_uv0_z

	var brush := TubeBrush.new()
	brush.m_HardEdges = hard_edges
	brush.m_EndCaps = end_caps
	brush.m_PointsInClosedCircle = points_in_closed_circle
	brush.m_uvStyle = TubeBrush.UVStyle.STRETCH if stretch_uvs else TubeBrush.UVStyle.DISTANCE
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.2, 0.6, 0.9, 1.0)
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
	if absf(actual - expected) > 1e-5:
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
	push_error("GDSCRIPT_PARITY_TUBEBRUSH: %s" % message)
