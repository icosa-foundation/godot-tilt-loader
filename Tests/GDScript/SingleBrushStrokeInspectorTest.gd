extends SceneTree

const SingleBrushStrokeInspectorScript := preload("res://Scripts/SingleBrushStrokeInspector.gd")

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	var root := Node3D.new()
	var brush_system := BrushSystemSetup.new()
	brush_system.auto_load_brushes = false
	var manifest := TiltBrushManifest.new()
	var ink := _make_desc("Ink", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "Line")
	var paper := _make_desc("Paper", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "DistanceUV")
	manifest.Brushes = [ink, paper]
	brush_system.manifest = manifest
	BrushCatalog.init(manifest)
	BrushRuntimeRegistry.register_supported_brushes(manifest)

	var canvas := MinimalExample.new()
	var pointer := PointerScript.new()
	var label := Label.new()
	var inspector = SingleBrushStrokeInspectorScript.new()

	root.add_child(brush_system)
	root.add_child(canvas)
	canvas.add_child(pointer)
	root.add_child(label)
	root.add_child(inspector)

	brush_system.name = "BrushSystem"
	canvas.name = "Canvas"
	pointer.name = "Pointer"
	label.name = "BrushName"
	inspector.name = "Inspector"

	canvas.BrushSystem = brush_system
	canvas.m_Pointer = pointer
	canvas._initialize_brush_catalog()
	canvas.m_Canvas = CanvasScript.new()
	canvas.add_child(canvas.m_Canvas)
	pointer.Canvas = canvas.m_Canvas

	inspector.Canvas = canvas
	inspector.BrushSystem = brush_system
	inspector.BrushLabel = label
	inspector._load_brushes()
	inspector._select_initial_brush()
	inspector._show_current_brush()

	_expect_equal(label.text.contains("Ink"), true, "inspector starts on Ink")
	_expect_equal(canvas.m_Canvas.get_child_count(), 1, "inspector creates one stroke")
	inspector.step_brush(1)
	_expect_equal(label.text.contains("Paper"), true, "inspector steps to Paper")
	_expect_equal(canvas.m_Canvas.get_child_count(), 1, "inspector keeps one stroke after step")

	root.free()
	if _failures == 0:
		print("GDSCRIPT_SINGLE_BRUSH_INSPECTOR: all checks passed")

func _make_desc(name: String, guid: String, prefab_name: String) -> BrushDescriptor:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = name
	desc.m_Guid = guid
	desc.m_BrushSizeRange = Vector2(0.1, 10.0)
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_TileRate = 1.0
	desc.m_TextureAtlasV = 1
	desc.prefab_fields = {
		"prefab_name": prefab_name,
		"m_StoreWidthInTexcoord0Z": false,
	}
	return desc

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_SINGLE_BRUSH_INSPECTOR: %s" % message)
