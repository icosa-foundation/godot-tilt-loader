extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_simple_stroke_demo_setup_and_reset()
	_check_simple_drawing_controller_controls()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SIMPLECONTROLLERS: all checks passed")

func _check_simple_stroke_demo_setup_and_reset() -> void:
	var canvas := CanvasScript.new()
	var pointer := PointerScript.new()
	var demo := SimpleStrokeDemo.new()
	demo.Canvas = canvas
	demo.Pointer = pointer
	demo.DrawOnStart = true
	demo._ready()
	_expect_equal(pointer.Canvas, canvas, "stroke demo assigns canvas")
	_expect(pointer.DrawingEnabled, "stroke demo draw on start")
	_expect_close(pointer.BrushSize01, 0.5, "stroke demo brush size")
	demo.reset_demo()
	_expect(not pointer.DrawingEnabled, "stroke demo reset stops drawing")
	_expect_vec3_close(pointer.position, Vector3.ZERO, "stroke demo reset position")
	demo.free()
	canvas.free()
	pointer.free()

func _check_simple_drawing_controller_controls() -> void:
	var manifest := TiltBrushManifest.new()
	var first := _make_desc("ControllerA", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
	var second := _make_desc("ControllerB", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
	manifest.Brushes = [first, second]
	BrushCatalog.init(manifest)

	var canvas := CanvasScript.new()
	var pointer := PointerScript.new()
	pointer.Canvas = canvas
	pointer.m_CurrentBrush = first
	var controller := SimpleDrawingController.new()
	controller.Pointer = pointer
	controller._availableBrushes = BrushCatalog.all_brushes()
	controller._currentBrushIndex = 0
	controller.start_drawing()
	_expect(pointer.DrawingEnabled, "drawing controller starts pointer")
	controller.stop_drawing()
	_expect(not pointer.DrawingEnabled, "drawing controller stops pointer")
	controller.cycle_brush(1)
	_expect_equal(pointer.m_CurrentBrush, second, "drawing controller cycles brush forward")
	controller.cycle_brush(-1)
	_expect_equal(pointer.m_CurrentBrush, first, "drawing controller cycles brush backward")
	var child := Node3D.new()
	canvas.add_child(child)
	controller.clear_canvas()
	_expect_equal(canvas.get_child_count(), 1, "drawing controller queues clear child")
	controller.reset()
	_expect(not pointer.DrawingEnabled, "drawing controller reset stops pointer")
	_expect_vec3_close(pointer.position, Vector3.ZERO, "drawing controller reset position")
	controller.free()
	canvas.free()
	pointer.free()

func _make_desc(name: String, guid: String) -> BrushDescriptor:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = name
	desc.m_Guid = guid
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
	push_error("GDSCRIPT_PARITY_SIMPLECONTROLLERS: %s" % message)
