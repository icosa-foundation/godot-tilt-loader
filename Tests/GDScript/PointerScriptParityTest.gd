extends SceneTree

class PointerTestBrush:
	extends GeometryBrush

	func _init() -> void:
		setup_geometry_brush(true, 3, false, true)

	func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
		return GeometryPool.VertexLayout.create(GeometryPool.TexcoordInfo.create(), null, null, false, false, false)

	func get_spawn_interval(_pressure01: float) -> float:
		return 0.25

	func control_points_changed(knot_index: int) -> void:
		var knot := m_knots[knot_index]
		knot.iVert = 0
		knot.nVert = 3
		knot.iTri = 0
		knot.nTri = 1
		m_knots[knot_index] = knot
		var tail := m_knots[m_knots.size() - 1]
		tail.iVert = 0
		tail.nVert = 3
		tail.iTri = 0
		tail.nTri = 1
		m_knots[m_knots.size() - 1] = tail
		resize_geometry()
		m_geometry.m_Vertices[0] = Vector3.ZERO
		m_geometry.m_Vertices[1] = Vector3.RIGHT
		m_geometry.m_Vertices[2] = Vector3.UP
		m_geometry.m_Tris[0] = 0
		m_geometry.m_Tris[1] = 1
		m_geometry.m_Tris[2] = 2

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	BaseBrushScript.register_brush_type("PointerTest", func(_desc: BrushDescriptor) -> BaseBrushScript: return PointerTestBrush.new())
	_check_brush_size_mapping()
	_check_control_point_replacement()
	_check_line_lifecycle()
	_check_recreate_line_from_memory()
	BaseBrushScript.clear_brush_types()
	if _failures == 0:
		print("GDSCRIPT_PARITY_POINTERSCRIPT: all checks passed")

func _check_brush_size_mapping() -> void:
	var pointer := PointerScript.new()
	pointer.m_BrushSizeRange = Vector2(0.1, 0.2)
	pointer.BrushSize01 = 0.0
	_expect_close(pointer.BrushSizeAbsolute, 0.1, "pointer size min")
	pointer.BrushSize01 = 1.0
	_expect_close(pointer.BrushSizeAbsolute, 0.2, "pointer size max")
	pointer.BrushSizeAbsolute = 9.0
	_expect_close(pointer.BrushSizeAbsolute, 0.2, "pointer absolute clamp max")
	pointer.BrushSizeAbsolute = 0.0
	_expect_close(pointer.BrushSizeAbsolute, 0.1, "pointer absolute clamp min")
	pointer.free()

func _check_control_point_replacement() -> void:
	var pointer := PointerScript.new()
	pointer.m_CurrentPressure = 0.5
	pointer.set_control_point(TrTransform.trs(Vector3.ZERO, Quaternion.IDENTITY, 1.0), false)
	pointer.set_control_point(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), false)
	_expect_equal(pointer.m_ControlPoints.size(), 1, "pointer non-keeper replaces point")
	_expect_vec3_close(pointer.m_ControlPoints[0].m_Pos, Vector3.RIGHT, "pointer replaced point position")
	pointer.set_control_point(TrTransform.trs(Vector3.UP, Quaternion.IDENTITY, 1.0), true)
	pointer.set_control_point(TrTransform.trs(Vector3.BACK, Quaternion.IDENTITY, 1.0), false)
	_expect_equal(pointer.m_ControlPoints.size(), 2, "pointer keeper appends next point")
	_expect_vec3_close(pointer.m_ControlPoints[1].m_Pos, Vector3.BACK, "pointer appended replacement position")
	pointer.free()

func _check_line_lifecycle() -> void:
	var canvas := CanvasScript.new()
	var pointer := PointerScript.new()
	pointer.Canvas = canvas
	pointer.m_CurrentBrush = _make_desc()
	pointer.m_CurrentColor = Color(0.2, 0.4, 0.8, 1.0)
	pointer.m_CurrentBrushSize = 1.0
	pointer.m_CurrentPressure = 1.0
	pointer.create_new_line(canvas, TrTransform.identity())
	_expect(pointer.m_CurrentLine != null, "pointer creates line")
	_expect_equal(canvas.get_child_count(), 1, "pointer line parented to canvas")
	pointer.position = Vector3.RIGHT
	pointer.update_line_from_object()
	_expect_equal(pointer.m_ControlPoints.size(), 1, "pointer update records control point")
	_expect(pointer.m_CurrentLine.mesh_data.vertices.size() == 3, "pointer update applies visuals")
	pointer.detach_line(false)
	_expect(pointer.m_CurrentLine == null, "pointer detach clears current line")
	_expect_equal(canvas.get_child_count(), 1, "pointer finalize keeps line node")
	canvas.free()
	pointer.free()

func _check_recreate_line_from_memory() -> void:
	var canvas := CanvasScript.new()
	var pointer := PointerScript.new()
	var desc := _make_desc()
	var manifest := TiltBrushManifest.new()
	manifest.Brushes = [desc]
	BrushCatalog.init(manifest)

	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_IntendedCanvas = canvas
	stroke.m_BrushGuid = desc.m_Guid
	stroke.m_BrushSize = 1.0
	stroke.m_BrushScale = 1.0
	stroke.m_Color = Color(1.0, 0.0, 0.0, 1.0)
	stroke.m_Seed = 123
	stroke.m_ControlPoints = [
		ControlPoint.create(Vector3.ZERO, Quaternion.IDENTITY, 1.0, 0),
		ControlPoint.create(Vector3.RIGHT, Quaternion.IDENTITY, 1.0, 1),
	]
	stroke.m_ControlPointsToDrop = [false, false]

	pointer.recreate_line_from_memory(stroke)
	_expect_equal(stroke.m_Type, Stroke.Type.BRUSH_STROKE, "pointer recreate stroke type")
	_expect(stroke.m_Object != null, "pointer recreate stroke object")
	_expect_equal(stroke.m_Object.mesh_data.vertices.size(), 3, "pointer recreate finalized mesh")
	_expect(pointer.m_CurrentLine == null, "pointer recreate clears current line")
	canvas.free()
	pointer.free()

func _make_desc() -> BrushDescriptor:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "PointerTest"
	desc.m_Guid = "11111111-1111-4111-8111-111111111111"
	desc.m_RenderBackfaces = false
	desc.m_M11Compatibility = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0
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
	push_error("GDSCRIPT_PARITY_POINTERSCRIPT: %s" % message)
