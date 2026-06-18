extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_convex_hull_helper_tetrahedron()
	_check_convex_hull_helper_cube()
	_check_hull_brush_tetrahedron_conversion()
	_check_hull_brush_double_sided_geometry()
	if _failures == 0:
		print("GDSCRIPT_PARITY_HULLBRUSH: all checks passed")

func _check_convex_hull_helper_tetrahedron() -> void:
	var hull := ConvexHullUtil.create([
		Vector3(1.0, 1.0, 1.0),
		Vector3(-1.0, -1.0, 1.0),
		Vector3(-1.0, 1.0, -1.0),
		Vector3(1.0, -1.0, -1.0),
	])
	_expect(hull.ok, "convex helper creates tetra hull")
	_expect_equal(hull.points.size(), 4, "convex helper tetra point count")
	_expect_equal(hull.faces.size(), 4, "convex helper tetra face count")
	for face in hull.faces:
		_expect_equal(face.indices.size(), 3, "convex helper tetra triangular face")
		_expect_close(face.normal.length(), 1.0, "convex helper normal length")

func _check_convex_hull_helper_cube() -> void:
	var input: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				input.append(Vector3(x, y, z))
	input.append(Vector3.ZERO)

	var hull := ConvexHullUtil.create(input)
	_expect(hull.ok, "convex helper creates cube hull")
	_expect_equal(hull.points.size(), 8, "convex helper cube hull point count")
	_expect_equal(hull.faces.size(), 12, "convex helper cube triangular face count")
	for face in hull.faces:
		_expect_equal(face.indices.size(), 3, "convex helper cube triangular face")
		_expect_close(face.normal.length(), 1.0, "convex helper cube normal length")

func _check_hull_brush_tetrahedron_conversion() -> void:
	var brush := _make_hull_brush(false)
	brush.m_KnotConversion = HullBrush.KnotConversion.TETRAHEDRON
	brush.init_brush(_make_desc(false), TrTransform.identity())
	brush.set_random_seed(0)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "hull first update keeps")
	brush.apply_changes_to_visuals()

	_expect_equal(brush.m_AllVertices.size(), 12, "hull converted vertices include active duplicate")
	_expect_equal(brush.m_geometry.get_layout().texcoord0.size, 3, "hull uv0 radius layout")
	_expect(brush.m_geometry.num_verts() >= 4, "hull vertex count")
	_expect(brush.m_geometry.num_tri_indices() >= 12, "hull triangle count")
	_expect_equal(brush.m_geometry.m_Normals.size(), brush.m_geometry.num_verts(), "hull normal count")
	_expect_equal(brush.m_geometry.m_Texcoord0.v3.size(), brush.m_geometry.num_verts(), "hull uv count")
	_expect_close(brush.m_geometry.m_Texcoord0.v3[0].z, 1.0, "hull uv stores base size")
	_expect_close(brush.m_geometry.m_Normals[0].length(), 1.0, "hull smoothed normal length")
	brush.finalize_solitary_brush()
	_expect(brush.m_geometry == null, "hull releases geometry")
	_expect(brush.mesh_data.vertices.size() >= 4, "hull finalized vertices")
	brush.free()

func _check_hull_brush_double_sided_geometry() -> void:
	var brush := _make_hull_brush(true)
	brush.m_KnotConversion = HullBrush.KnotConversion.TETRAHEDRON
	brush.init_brush(_make_desc(true), TrTransform.identity())
	brush.set_random_seed(0)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "hull double-sided update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.m_bDoubleSided, "hull double-sided enabled")
	_expect_equal(brush.NS, 2, "hull double-sided stride")
	_expect_equal(brush.m_geometry.num_verts() % 2, 0, "hull double-sided vertex pairs")
	_expect_equal(brush.m_geometry.num_tri_indices() % 6, 0, "hull double-sided triangle pairs")
	_expect_vec3_close(brush.m_geometry.m_Vertices[0], brush.m_geometry.m_Vertices[1], "hull doubled vertex position")
	_expect_vec3_close(brush.m_geometry.m_Normals[0], -brush.m_geometry.m_Normals[1], "hull doubled normal")
	brush.free()

func _make_hull_brush(_render_backfaces: bool) -> HullBrush:
	var brush := HullBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.7, 0.4, 0.9, 1.0)
	brush.set_random_seed(0)
	return brush

func _make_desc(render_backfaces: bool) -> BrushDescriptor:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "MatteHull"
	desc.m_RenderBackfaces = render_backfaces
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0
	desc.m_SolidMinLengthMeters_PS = 0.002
	return desc

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

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_HULLBRUSH: %s" % message)
