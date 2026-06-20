extends SceneTree

class MinimalTestBrush:
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
	BaseBrushScript.register_brush_type("MinimalTest", func(_desc: BrushDescriptor) -> BaseBrushScript: return MinimalTestBrush.new())
	_check_minimal_example_setup_and_draw()
	_check_minimal_xr_setup_without_runtime()
	BaseBrushScript.clear_brush_types()
	if _failures == 0:
		print("GDSCRIPT_PARITY_MINIMALEXAMPLES: all checks passed")

func _check_minimal_example_setup_and_draw() -> void:
	var desc := _make_desc()
	var manifest := TiltBrushManifest.new()
	manifest.Brushes = [desc]
	var pointer := PointerScript.new()
	var example := MinimalExample.new()
	example.m_ManifestStandard = manifest
	example.m_DefaultBrush = desc
	example.m_Pointer = pointer
	example._ready()
	_expect(example.m_Canvas != null, "minimal creates canvas")
	_expect_equal(pointer.Canvas, example.m_Canvas, "minimal assigns pointer canvas")
	_expect_equal(pointer.m_CurrentBrush, desc, "minimal assigns brush")
	var stroke := example.draw_stroke([
		TrTransform.trs(Vector3.ZERO, Quaternion.IDENTITY, 1.0),
		TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0),
	], desc, Color.BLUE)
	_expect(stroke != null, "minimal draw stroke returns stroke")
	_expect_equal(stroke.m_Type, Stroke.Type.BRUSH_STROKE, "minimal recreates stroke")
	_expect(stroke.m_Object != null, "minimal stroke object exists")
	_expect_equal(stroke.m_Object.mesh_data.vertices.size(), 3, "minimal stroke mesh finalized")
	pointer.free()
	example.free()

func _check_minimal_xr_setup_without_runtime() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var origin := XROrigin3D.new()
	origin.name = "XROrigin3D"
	var brush_system := BrushSystemSetup.new()
	brush_system.name = "BrushSystem"
	brush_system.auto_load_brushes = false
	var desc := _make_desc()
	brush_system.manifest = TiltBrushManifest.new()
	brush_system.manifest.Brushes = [desc]
	var pointer := PointerScript.new()
	pointer.name = "Pointer"
	var right := XRController3D.new()
	right.name = "RightController"
	root.add_child(origin)
	root.add_child(brush_system)
	root.add_child(pointer)
	root.add_child(right)
	var example := MinimalXrExample.new()
	example.name = "MinimalXrExample"
	example.BrushSystem = brush_system
	example.m_Pointer = pointer
	example._rightController = right
	origin.add_child(example)
	example.setup()
	_expect(example.m_Canvas != null, "minimal xr creates canvas")
	_expect_equal(pointer.Canvas, example.m_Canvas, "minimal xr assigns canvas")
	_expect_equal(pointer.m_CurrentBrush, desc, "minimal xr assigns brush")
	_expect_close(pointer.BrushSize01, example.PointerSize01, "minimal xr pointer size")
	example.clear_canvas()
	root.queue_free()

func _make_desc() -> BrushDescriptor:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "MinimalTest"
	desc.m_Guid = "22222222-2222-4222-8222-222222222222"
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

func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_MINIMALEXAMPLES: %s" % message)
