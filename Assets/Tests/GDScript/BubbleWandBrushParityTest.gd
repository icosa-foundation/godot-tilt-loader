extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_bubble_geometry_and_uvws()
	_check_finalize_smooths_and_preserves_original_positions()
	if _failures == 0:
		print("GDSCRIPT_PARITY_BUBBLEWAND: all checks passed")

func _check_bubble_geometry_and_uvws() -> void:
	var brush := _make_bubble_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "bubble first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "bubble second update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "bubble knot invariants")
	_expect_equal(brush.m_geometry.get_layout().texcoord0.size, 3, "bubble uv0 size")
	_expect_equal(brush.m_geometry.get_layout().texcoord1.size, 4, "bubble uv1 size")
	_expect(not brush.m_geometry.get_layout().bUseTangents, "bubble layout omits tangents")
	_expect_equal(brush.m_geometry.num_verts(), 43, "bubble vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 144, "bubble triangle index count")
	_expect_equal(brush.m_geometry.m_Texcoord0.v3.size(), 43, "bubble uvw count")
	_expect_equal(brush.m_geometry.m_Texcoord1.v4.size(), 43, "bubble uv1 count")
	_expect_equal(brush.m_geometry.m_Tangents.size(), 0, "bubble tangent count")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[0].x, 0.0, "bubble uvw first u")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[7].y, 1.0, "bubble uvw first cap v")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[8].y, 0.0, "bubble uvw first ring v")
	_expect(brush.m_geometry.m_Texcoord0.v3[8].z > 0.0, "bubble moving verts get timestamp")
	_expect(brush.bubble_radius > 0.0, "bubble computed radius")
	_expect(brush.bubble_center.distance_to(Vector3(1.0, 0.0, 0.0)) < 0.25, "bubble computed center")
	brush.free()

func _check_finalize_smooths_and_preserves_original_positions() -> void:
	var brush := _make_bubble_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "bubble finalize first update keeps")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "bubble finalize second update keeps")
	brush.apply_changes_to_visuals()
	var original_first_vertex := brush.m_geometry.m_Vertices[0]
	var original_mid_vertex := brush.m_geometry.m_Vertices[17]
	brush.finalize_solitary_brush()

	_expect(brush.m_geometry == null, "bubble releases geometry")
	_expect_equal(brush.mesh_data.vertices.size(), 43, "bubble finalized vertex count")
	_expect_equal(brush.mesh_data.uv1_v4.size(), 43, "bubble finalized uv1 count")
	_expect_vec4_close(brush.mesh_data.uv1_v4[0], Vector4(original_first_vertex.x, original_first_vertex.y, original_first_vertex.z, 0.0), "bubble stores original first vertex")
	_expect_vec4_close(brush.mesh_data.uv1_v4[17], Vector4(original_mid_vertex.x, original_mid_vertex.y, original_mid_vertex.z, 0.0), "bubble stores original mid vertex")
	_expect(brush.mesh_data.vertices[0].distance_to(original_first_vertex) > 0.001, "bubble finalize smooths first cap")
	_expect(brush.release_time > 0.0, "bubble release time")
	brush.free()

func _make_bubble_brush() -> BubbleWandBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "BubbleWand"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0
	desc.m_SolidMinLengthMeters_PS = 0.002
	desc.m_TubeStoreRadiusInTexcoord0Z = true

	var brush := BubbleWandBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.4, 0.8, 1.0, 1.0)
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

func _expect_vec4_close(actual: Vector4, expected: Vector4, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)
	_expect_close(actual.z, expected.z, "%s z" % label)
	_expect_close(actual.w, expected.w, "%s w" % label)

func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_BUBBLEWAND: %s" % message)
