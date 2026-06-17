extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_square_brush_geometry()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SQUAREBRUSH: all checks passed")

func _check_square_brush_geometry() -> void:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Square"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := SquareBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.25, 0.5, 0.75, 0.2)
	brush.init_brush(desc, TrTransform.identity())

	var kept := brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0)
	_expect(kept, "square update keeps one solid")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "square knot invariants")
	_expect_equal(brush.m_geometry.num_verts(), 16, "square vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 36, "square triangle index count")
	_expect_equal(brush.m_knots[1].nVert, 16, "square knot vertex count")
	_expect_equal(brush.m_knots[1].nTri, 12, "square knot triangle count with end caps")
	_expect(brush.m_knots[1].startsGeometry, "square starts geometry")
	_expect(brush.m_knots[1].endsGeometry, "square ends geometry")

	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [4, 2, 12, 12, 2, 10], "square top tris")
	_expect_equal(brush.m_geometry.m_Tris.slice(24, 30), [5, 1, 3, 3, 1, 7], "square start cap tris")

	_expect_vec3_close(brush.m_geometry.m_Vertices[SquareBrush.BBR_B], Vector3(0.0, 0.5, -0.1875), "square back bottom right")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SquareBrush.BTL_T], Vector3(0.0, -0.5, 0.1875), "square back top left")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SquareBrush.FTR_T], Vector3(1.0, 0.5, 0.1875), "square front top right")
	_expect_vec3_close(brush.m_geometry.m_Normals[SquareBrush.FBR_R], Vector3.UP, "square right normal")
	_expect_vec3_close(brush.m_geometry.m_Normals[SquareBrush.FTL_T], Vector3.BACK, "square top normal")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[SquareBrush.FBL_L], Vector2(0.5, 0.5), "square default uv")
	_expect_equal(brush.m_geometry.m_Colors[SquareBrush.FBL_L], Color(0.25, 0.5, 0.75, 1.0), "square color alpha forced opaque")

	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 16, "square finalized vertex count")
	_expect(brush.m_geometry == null, "square releases geometry")
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

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_SQUAREBRUSH: %s" % message)
