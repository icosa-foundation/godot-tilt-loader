extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_position_and_fuse_helpers()
	_check_unitized_uv_brush()
	_check_unitized_uv_backfaces()
	_check_stretch_uv_brush()
	_check_stretch_uv_live_preview_preserves_width_uv()
	_check_distance_uv_brush()
	_check_distance_uv_color32_alpha_quantization()
	_check_distance_uv_backfaces()
	_check_backface_append_color_pattern()
	_check_backface_append_hue_shift()
	_check_sharp_bend_shrinks_quad_strip()
	_check_double_back_creates_strip_break()
	_check_backfaces_follow_fused_front_quads()
	_check_batched_finalization_welds_single_sided_strip()
	if _failures == 0:
		print("GDSCRIPT_PARITY_QUADSTRIP: all checks passed")

func _check_position_and_fuse_helpers() -> void:
	var verts: Array[Vector3] = []
	verts.resize(12)
	var brush := QuadStripBrush.new()
	brush.position_quad(verts, 0, Vector3(2.0, 3.0, 4.0), Vector3.RIGHT, Vector3.UP)
	_expect_vec3_close(verts[0], Vector3(1.0, 2.0, 4.0), "position quad 0")
	_expect_vec3_close(verts[1], Vector3(3.0, 2.0, 4.0), "position quad 1")
	_expect_vec3_close(verts[5], Vector3(3.0, 4.0, 4.0), "position quad 5")

	var normals: Array[Vector3] = []
	normals.resize(12)
	for index in range(normals.size()):
		normals[index] = Vector3.BACK
	brush.fuse_quads(verts, normals, 0, 6, true)
	_expect_vec3_close(verts[1], verts[6], "fuse top")
	_expect_vec3_close(verts[5], verts[8], "fuse bottom")
	brush.free()

func _check_unitized_uv_brush() -> void:
	var brush := _make_quad_brush(QuadStripUnitizedUVBrush.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	_expect_equal(brush.m_Geometry.m_UVs[0], Vector2(0.0, 1.0), "unitized uv 0")
	_expect_equal(brush.m_Geometry.m_UVs[1], Vector2(1.0, 1.0), "unitized uv 1")
	_expect_equal(brush.m_Geometry.m_UVs[5], Vector2(1.0, 0.0), "unitized uv 5")
	_expect_close(brush.m_Geometry.m_Tangents[0].length(), sqrt(2.0), "unitized tangent length includes handedness")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 12, "unitized finalize vertex count")
	_expect(brush.m_Geometry == null, "unitized releases geometry")
	brush.free()

func _check_unitized_uv_backfaces() -> void:
	var brush := _make_quad_brush(QuadStripUnitizedUVBrush.new(), true)
	_seed_two_double_sided_solids(brush)
	brush.update_uvs(0, 4, 1.0)
	_expect_backface_uvs_match_front(brush, 0)
	_expect_backface_uvs_match_front(brush, 12)
	_expect_backface_tangents_match_front(brush, 0)
	_expect_backface_tangents_match_front(brush, 12)
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_brush() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.flush_update_uv_request()
	_expect_equal(brush.m_Geometry.m_UVs[0].x, 0.0, "stretch first x")
	_expect_close(brush.m_Geometry.m_UVs[1].x, 0.5, "stretch first end x")
	_expect_close(brush.m_Geometry.m_UVs[7].x, 1.0, "stretch second end x")
	_expect_equal(brush.m_QuadLengths.slice(0, 2), [1.0, 1.0], "stretch quad lengths")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_live_preview_preserves_width_uv() -> void:
	var stretch_brush := QuadStripBrushStretchUV.new()
	stretch_brush.m_StoreWidthInTexcoord0Z = true
	var brush := _make_quad_brush(stretch_brush, false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.apply_changes_to_visuals()
	_expect_equal(brush.mesh_data.uv0_v2.size(), 0, "stretch preview does not export competing uv0 v2")
	_expect_equal(brush.mesh_data.uv0_v3.size(), 12, "stretch preview exports uv0 v3")
	_expect_close(brush.mesh_data.uv0_v3[0].z, 1.0, "stretch preview exports width in uv0 z")
	var arrays := brush.mesh_data.to_mesh_arrays()
	_expect(arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array, "stretch preview exports uv0 z custom data")
	brush.finalize_solitary_brush()
	brush.free()

func _check_distance_uv_brush() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), false)
	_seed_two_quads(brush)
	brush.m_Geometry.m_Colors[5].a = 0.25
	brush.update_uvs(0, 2, 1.0)
	brush.flush_tangent_request()
	_expect_equal(brush.m_Geometry.m_UVs[0].x, brush.m_Geometry.m_UVs[2].x, "distance trailing u")
	_expect_close(brush.m_Geometry.m_UVs[1].x - brush.m_Geometry.m_UVs[0].x, 1.0, "distance first tile length")
	_expect_close(brush.m_Geometry.m_Colors[0].a, 0.0, "distance trailing start alpha")
	_expect_close(brush.m_Geometry.m_Colors[1].a, 1.0, "distance leading alpha")
	_expect_close(brush.m_Geometry.m_Tangents[0].length(), sqrt(2.0), "distance tangent length includes handedness")
	brush.finalize_solitary_brush()
	brush.free()

func _check_distance_uv_color32_alpha_quantization() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), false)
	_seed_two_short_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	var expected_alpha := 122.0 / 255.0
	_expect_close(brush.m_Geometry.m_Colors[6].a, expected_alpha, "distance fade alpha quantizes to Color32")
	_expect_close(brush.m_Geometry.m_Colors[8].a, expected_alpha, "distance fade mirrored trailing alpha quantizes to Color32")
	_expect_close(brush.m_Geometry.m_Colors[7].a, 0.0, "distance leading tip alpha remains zero")
	brush.finalize_solitary_brush()
	brush.free()

func _check_distance_uv_backfaces() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), true)
	_seed_two_double_sided_solids(brush)
	brush.update_uvs(0, 4, 1.0)
	brush.flush_tangent_request()
	_expect_backface_uvs_match_front(brush, 0)
	_expect_backface_uvs_match_front(brush, 12)
	_expect_backface_colors_match_front(brush, 0)
	_expect_backface_colors_match_front(brush, 12)
	_expect_backface_tangents_match_front(brush, 0)
	_expect_backface_tangents_match_front(brush, 12)
	brush.finalize_solitary_brush()
	brush.free()

func _check_backface_append_color_pattern() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	brush.m_Color = Color(0.2, 0.5, 1.0, 0.8)
	brush.append_leading_quad(true, 0.25, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var expected := Color(0.2, 0.5, 1.0, 0.25)
	var colors := brush.m_Geometry.m_Colors
	_expect_color_close(colors[6], expected, "backface append color 0")
	_expect_color_close(colors[7], expected, "backface append color 1")
	_expect_color_close(colors[8], expected, "backface append color 2")
	_expect_color_close(colors[9], expected, "backface append color 3")
	_expect_color_close(colors[10], expected, "backface append color 4")
	_expect_color_close(colors[11], expected, "backface append color 5")
	brush.append_leading_quad(true, 0.75, Vector3.RIGHT, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var next_expected := Color(0.2, 0.5, 1.0, 0.75)
	_expect_color_close(colors[18], expected, "backface second append color 0")
	_expect_color_close(colors[19], expected, "backface second append color 1")
	_expect_color_close(colors[20], next_expected, "backface second append color 2")
	_expect_color_close(colors[21], expected, "backface second append color 3")
	_expect_color_close(colors[22], next_expected, "backface second append color 4")
	_expect_color_close(colors[23], next_expected, "backface second append color 5")
	brush.finalize_solitary_brush()
	brush.free()

func _check_backface_append_hue_shift() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	brush.m_Color = Color(1.0, 0.0, 0.0, 0.8)
	brush.m_Desc.m_BackfaceHueShift = 120.0
	brush.append_leading_quad(true, 0.25, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var shifted := HSLColor.from_color(brush.m_Color)
	shifted.set_hue_degrees(shifted.get_hue_degrees() + brush.m_Desc.m_BackfaceHueShift)
	var expected := shifted.to_color()
	var colors := brush.m_Geometry.m_Colors
	_expect_color_close(colors[6], expected, "backface hue color 0")
	_expect_color_close(colors[7], expected, "backface hue color 1")
	_expect_color_close(colors[8], expected, "backface hue color 2")
	_expect_color_close(colors[9], expected, "backface hue color 3")
	_expect_color_close(colors[10], expected, "backface hue color 4")
	_expect_color_close(colors[11], expected, "backface hue color 5")
	brush.finalize_solitary_brush()
	brush.free()

func _check_sharp_bend_shrinks_quad_strip() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	brush.m_Desc.m_BackIsInvisible = true
	brush.m_BaseSize_PS = 2.0
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(1.5, 1.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	_expect(brush.m_LastSizeShrink > 0.0, "sharp bend records size shrink")
	_expect(brush.m_LastQuadRight.length() < 1.0, "sharp bend narrows leading quad")
	brush.finalize_solitary_brush()
	brush.free()

func _check_double_back_creates_strip_break() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	brush.m_Desc.m_BackIsInvisible = true
	brush.m_BaseSize_PS = 2.0
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 1.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	_expect_equal(brush.m_InitialQuadIndex, 1, "double-back starts new strip segment")
	_expect_equal(brush.m_LastSegmentLengthSolids, 1, "double-back segment length starts at one")
	_expect_close(brush.m_LastSizeShrink, 0.0, "double-back does not record shrink")
	brush.finalize_solitary_brush()
	brush.free()

func _check_backfaces_follow_fused_front_quads() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	brush.m_Desc.m_BackIsInvisible = true
	brush.m_BaseSize_PS = 0.5
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(3.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	for front_quad in range(0, brush.m_LeadingQuadIndex, 2):
		_expect_backface_matches_front(brush, front_quad * 6)
	brush.finalize_solitary_brush()
	brush.free()

func _check_batched_finalization_welds_single_sided_strip() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.flush_update_uv_request()
	brush.finalize_batched_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 6, "batched weld vertex count")
	_expect_equal(brush.mesh_data.triangles.size(), 12, "batched weld triangle index count")
	_expect_equal(brush.mesh_data.uv0_v2.size(), 6, "batched weld uv count")
	_expect_vec3_close(brush.mesh_data.vertices[0], Vector3(0.0, 0.5, 0.0), "batched weld first BR")
	_expect_vec3_close(brush.mesh_data.vertices[1], Vector3(0.0, -0.5, 0.0), "batched weld first BL")
	_expect_vec3_close(brush.mesh_data.vertices[2], Vector3(1.0, 0.5, 0.0), "batched weld first FR")
	_expect_vec3_close(brush.mesh_data.vertices[3], Vector3(1.0, -0.5, 0.0), "batched weld first FL")
	_expect_equal(brush.mesh_data.triangles.slice(0, 6), [0, 1, 3, 0, 3, 2], "batched weld first quad indices")
	_expect_equal(brush.mesh_data.triangles.slice(6, 12), [2, 3, 5, 2, 5, 4], "batched weld second quad indices")
	brush.free()

func _make_quad_brush(brush: QuadStripBrush, backfaces: bool) -> QuadStripBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Ink"
	desc.m_Guid = "c0012095-3ffd-4040-8ee1-fc180d346eaa"
	desc.m_RenderBackfaces = backfaces
	desc.m_BackIsInvisible = false
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color.WHITE
	brush.init_brush(desc, TrTransform.identity())
	return brush

func _seed_two_quads(brush: QuadStripBrush) -> void:
	brush.m_LeadingQuadIndex = 2
	brush.m_InitialQuadIndex = 0
	for index in range(12):
		brush.m_Geometry.m_Normals[index] = Vector3.BACK
		brush.m_Geometry.m_Colors[index] = Color.WHITE
		brush.m_Geometry.m_Tangents[index] = Vector4.ZERO
	brush.position_quad(brush.m_Geometry.m_Vertices, 0, Vector3(0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))
	brush.position_quad(brush.m_Geometry.m_Vertices, 6, Vector3(1.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))

func _seed_two_short_quads(brush: QuadStripBrush) -> void:
	brush.m_LeadingQuadIndex = 2
	brush.m_InitialQuadIndex = 0
	for index in range(12):
		brush.m_Geometry.m_Normals[index] = Vector3.BACK
		brush.m_Geometry.m_Colors[index] = Color.WHITE
		brush.m_Geometry.m_Tangents[index] = Vector4.ZERO
	brush.position_quad(brush.m_Geometry.m_Vertices, 0, Vector3(0.06, 0.0, 0.0), Vector3(0.06, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))
	brush.position_quad(brush.m_Geometry.m_Vertices, 6, Vector3(0.18, 0.0, 0.0), Vector3(0.06, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))

func _seed_two_double_sided_solids(brush: QuadStripBrush) -> void:
	brush.m_LeadingQuadIndex = 4
	brush.m_InitialQuadIndex = 0
	for index in range(24):
		brush.m_Geometry.m_Normals[index] = Vector3.BACK
		brush.m_Geometry.m_Colors[index] = Color.WHITE
		brush.m_Geometry.m_Tangents[index] = Vector4.ZERO
	brush.position_quad(brush.m_Geometry.m_Vertices, 0, Vector3(0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))
	BaseBrushScript.create_duplicate_quad(brush.m_Geometry.m_Vertices, brush.m_Geometry.m_Normals, 1, Vector3.BACK)
	brush.position_quad(brush.m_Geometry.m_Vertices, 12, Vector3(1.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))
	BaseBrushScript.create_duplicate_quad(brush.m_Geometry.m_Vertices, brush.m_Geometry.m_Normals, 3, Vector3.BACK)

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

func _expect_vec2_close(actual: Vector2, expected: Vector2, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)

func _expect_vec4_close(actual: Vector4, expected: Vector4, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)
	_expect_close(actual.z, expected.z, "%s z" % label)
	_expect_close(actual.w, expected.w, "%s w" % label)

func _expect_color_close(actual: Color, expected: Color, label: String) -> void:
	_expect_close(actual.r, expected.r, "%s r" % label)
	_expect_close(actual.g, expected.g, "%s g" % label)
	_expect_close(actual.b, expected.b, "%s b" % label)
	_expect_close(actual.a, expected.a, "%s a" % label)

func _expect_backface_matches_front(brush: QuadStripBrush, front_vert: int) -> void:
	var verts := brush.m_Geometry.m_Vertices
	var norms := brush.m_Geometry.m_Normals
	var back_vert := front_vert + 6
	_expect_vec3_close(verts[back_vert], verts[front_vert], "backface %d vertex 0" % front_vert)
	_expect_vec3_close(verts[back_vert + 1], verts[front_vert + 2], "backface %d vertex 1" % front_vert)
	_expect_vec3_close(verts[back_vert + 2], verts[front_vert + 1], "backface %d vertex 2" % front_vert)
	_expect_vec3_close(verts[back_vert + 3], verts[front_vert + 3], "backface %d vertex 3" % front_vert)
	_expect_vec3_close(verts[back_vert + 4], verts[front_vert + 5], "backface %d vertex 4" % front_vert)
	_expect_vec3_close(verts[back_vert + 5], verts[front_vert + 4], "backface %d vertex 5" % front_vert)
	_expect_vec3_close(norms[back_vert], -norms[front_vert], "backface %d normal 0" % front_vert)
	_expect_vec3_close(norms[back_vert + 1], -norms[front_vert + 2], "backface %d normal 1" % front_vert)
	_expect_vec3_close(norms[back_vert + 2], -norms[front_vert + 1], "backface %d normal 2" % front_vert)
	_expect_vec3_close(norms[back_vert + 3], -norms[front_vert + 3], "backface %d normal 3" % front_vert)
	_expect_vec3_close(norms[back_vert + 4], -norms[front_vert + 5], "backface %d normal 4" % front_vert)
	_expect_vec3_close(norms[back_vert + 5], -norms[front_vert + 4], "backface %d normal 5" % front_vert)

func _expect_backface_uvs_match_front(brush: QuadStripBrush, front_vert: int) -> void:
	var uvs := brush.m_Geometry.m_UVs
	var back_vert := front_vert + 6
	_expect_vec2_close(uvs[back_vert], uvs[front_vert], "backface %d uv 0" % front_vert)
	_expect_vec2_close(uvs[back_vert + 1], uvs[front_vert + 2], "backface %d uv 1" % front_vert)
	_expect_vec2_close(uvs[back_vert + 2], uvs[front_vert + 1], "backface %d uv 2" % front_vert)
	_expect_vec2_close(uvs[back_vert + 3], uvs[front_vert + 3], "backface %d uv 3" % front_vert)
	_expect_vec2_close(uvs[back_vert + 4], uvs[front_vert + 5], "backface %d uv 4" % front_vert)
	_expect_vec2_close(uvs[back_vert + 5], uvs[front_vert + 4], "backface %d uv 5" % front_vert)

func _expect_backface_colors_match_front(brush: QuadStripBrush, front_vert: int) -> void:
	var colors := brush.m_Geometry.m_Colors
	var back_vert := front_vert + 6
	_expect_color_close(colors[back_vert], colors[front_vert], "backface %d color 0" % front_vert)
	_expect_color_close(colors[back_vert + 1], colors[front_vert + 2], "backface %d color 1" % front_vert)
	_expect_color_close(colors[back_vert + 2], colors[front_vert + 1], "backface %d color 2" % front_vert)
	_expect_color_close(colors[back_vert + 3], colors[front_vert + 3], "backface %d color 3" % front_vert)
	_expect_color_close(colors[back_vert + 4], colors[front_vert + 5], "backface %d color 4" % front_vert)
	_expect_color_close(colors[back_vert + 5], colors[front_vert + 4], "backface %d color 5" % front_vert)

func _expect_backface_tangents_match_front(brush: QuadStripBrush, front_vert: int) -> void:
	var tangents := brush.m_Geometry.m_Tangents
	var back_vert := front_vert + 6
	_expect_vec4_close(tangents[back_vert], _mirrored_tangent(tangents[front_vert]), "backface %d tangent 0" % front_vert)
	_expect_vec4_close(tangents[back_vert + 1], _mirrored_tangent(tangents[front_vert + 2]), "backface %d tangent 1" % front_vert)
	_expect_vec4_close(tangents[back_vert + 2], _mirrored_tangent(tangents[front_vert + 1]), "backface %d tangent 2" % front_vert)
	_expect_vec4_close(tangents[back_vert + 3], _mirrored_tangent(tangents[front_vert + 3]), "backface %d tangent 3" % front_vert)
	_expect_vec4_close(tangents[back_vert + 4], _mirrored_tangent(tangents[front_vert + 5]), "backface %d tangent 4" % front_vert)
	_expect_vec4_close(tangents[back_vert + 5], _mirrored_tangent(tangents[front_vert + 4]), "backface %d tangent 5" % front_vert)

func _mirrored_tangent(value: Vector4) -> Vector4:
	return Vector4(value.x, value.y, value.z, -value.w)

func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_QUADSTRIP: %s" % message)
