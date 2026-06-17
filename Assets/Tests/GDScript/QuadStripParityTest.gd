extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_position_and_fuse_helpers()
	_check_unitized_uv_brush()
	_check_stretch_uv_brush()
	_check_distance_uv_brush()
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

func _check_distance_uv_brush() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.flush_tangent_request()
	_expect_equal(brush.m_Geometry.m_UVs[0].x, brush.m_Geometry.m_UVs[2].x, "distance trailing u")
	_expect_close(brush.m_Geometry.m_UVs[1].x - brush.m_Geometry.m_UVs[0].x, 1.0, "distance first tile length")
	_expect_close(brush.m_Geometry.m_Colors[0].a, 0.0, "distance trailing start alpha")
	_expect_close(brush.m_Geometry.m_Colors[1].a, 1.0, "distance leading alpha")
	_expect_close(brush.m_Geometry.m_Tangents[0].length(), sqrt(2.0), "distance tangent length includes handedness")
	brush.finalize_solitary_brush()
	brush.free()

func _make_quad_brush(brush: QuadStripBrush, backfaces: bool) -> QuadStripBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "TestQuad"
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

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_QUADSTRIP: %s" % message)
