class_name MinimalExample
extends Node3D

const TiltSceneBuilderScript := preload("res://addons/open_brush_stroke_integration/open_brush_tilt_scene_builder.gd")
const TiltReaderScript := preload("res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd")
const OpenBrushScript := preload("res://addons/icosa/open_brush/open_brush.gd")

@export var BrushSystemPath: NodePath
@export var PointerPath: NodePath
@export var m_ManifestStandard: TiltBrushManifest
@export var m_ManifestExperimental: TiltBrushManifest
@export var m_DefaultBrush: BrushDescriptor
@export var ShowTiltPathReference := false
@export var TiltPathReferenceFile := "res://Temp/TiltEvidence/brush_cafe_experimental.tilt"
@export var TiltPathReferenceBrush := "Ink"
@export var TiltPathReferenceStrokeIndex := 0
@export var TiltPathReferenceOffset := Vector3(-4.0, -3.0, 0.0)
@export var TiltPathReferenceVisualScale := 4.0

var BrushSystem: BrushSystemSetup
var m_Pointer: PointerScript
var m_Canvas: CanvasScript
var _runtimeBrush: BrushDescriptor

func _ready() -> void:
	if not BrushSystemPath.is_empty():
		BrushSystem = get_node_or_null(BrushSystemPath) as BrushSystemSetup
		if BrushSystem == null:
			push_error("MinimalExample: BrushSystemPath does not point to a BrushSystemSetup")
	if not PointerPath.is_empty():
		m_Pointer = get_node_or_null(PointerPath) as PointerScript
		if m_Pointer == null:
			push_error("MinimalExample: PointerPath does not point to a PointerScript")
	_initialize_brush_catalog()
	m_Canvas = CanvasScript.new()
	m_Canvas.name = "CanvasScript"
	add_child(m_Canvas)
	if m_Pointer != null:
		m_Pointer.Canvas = m_Canvas
		if _runtimeBrush != null:
			m_Pointer.m_CurrentBrush = _runtimeBrush
			_apply_pointer_brush_size_range(_runtimeBrush)
			m_Pointer.m_CurrentColor = Color(0.2, 0.5, 1.0, 1.0)
			m_Pointer.BrushSize01 = 0.5
			m_Pointer.m_CurrentPressure = 1.0
		else:
			push_error("No brush available for pointer")
	else:
		push_warning("No Pointer assigned to MinimalExample")
	if ShowTiltPathReference:
		add_tilt_path_reference_stroke()

func _initialize_brush_catalog() -> void:
	if BrushSystem != null:
		_runtimeBrush = BrushSystem.get_brush_by_name("Ink")
		if _runtimeBrush == null:
			_runtimeBrush = BrushSystem.get_default_brush()
	elif m_ManifestStandard != null:
		var merged_manifest := TiltBrushManifest.new()
		merged_manifest.Brushes = m_ManifestStandard.Brushes.duplicate()
		merged_manifest.CompatibilityBrushes = m_ManifestStandard.CompatibilityBrushes.duplicate()
		if m_ManifestExperimental != null:
			merged_manifest.append_from(m_ManifestExperimental)
		BrushCatalog.init(merged_manifest)
		_runtimeBrush = m_DefaultBrush
	else:
		var project_path := ProjectSettings.globalize_path("res://")
		var manifest_path := project_path.path_join("Manifest.asset")
		var manifest := UnityAssetLoader.load_manifest(manifest_path)
		if manifest != null:
			var experimental_path := project_path.path_join("Manifest_Experimental.asset")
			var experimental_manifest := UnityAssetLoader.load_manifest(experimental_path)
			manifest.append_from(experimental_manifest)
			BrushCatalog.init(manifest)
			_runtimeBrush = manifest.Brushes[0] if not manifest.Brushes.is_empty() else null

func draw_torus_knot() -> void:
	var path: Array[TrTransform] = []
	var p := 3.0
	var q := 2.0
	var major_radius := 1.0
	var minor_radius := 0.4
	var segments := 120
	for index in range(segments):
		var t := index * 2.0 * PI / segments
		var position := Vector3(
			(major_radius + minor_radius * cos(q * t)) * cos(p * t),
			(major_radius + minor_radius * cos(q * t)) * sin(p * t),
			minor_radius * sin(q * t)
		)
		path.append(TrTransform.trs(position, Quaternion.IDENTITY, 1.0))
	draw_stroke(path, _runtimeBrush if _runtimeBrush != null else m_DefaultBrush, Color.BLUE)

func draw_circle() -> void:
	var path: Array[TrTransform] = []
	var segments := 32
	var radius := 1.5
	for index in range(segments):
		var angle := index * 2.0 * PI / segments
		path.append(TrTransform.trs(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0), Quaternion.IDENTITY, 1.0))
	draw_stroke(path, _runtimeBrush if _runtimeBrush != null else m_DefaultBrush, Color.BLUE)

func add_tilt_path_reference_stroke() -> Node3D:
	var tilt_data := _single_tilt_reference_stroke_data()
	if tilt_data.is_empty():
		push_error("MinimalExample: cannot create Tilt-path reference from %s" % TiltPathReferenceFile)
		return null
	var builder := TiltSceneBuilderScript.new()
	var scene := builder.build_scene(tilt_data)
	scene.name = "TiltPathReferenceStroke"
	scene.position = TiltPathReferenceOffset
	scene.scale = Vector3.ONE * TiltPathReferenceVisualScale
	add_child(scene)
	return scene

func _single_tilt_reference_stroke_data() -> Dictionary:
	var reader := TiltReaderScript.new()
	var tilt_data: Dictionary = reader.load_tilt(TiltPathReferenceFile)
	var error := String(tilt_data.get("error", ""))
	if not error.is_empty():
		push_error("MinimalExample: Tilt reference reader error: %s" % error)
		return {}
	var source_stroke := _find_tilt_reference_stroke(tilt_data)
	if source_stroke.is_empty():
		push_error("MinimalExample: no %s stroke found in %s" % [TiltPathReferenceBrush, TiltPathReferenceFile])
		return {}
	return {
		"metadata": tilt_data.get("metadata", {}),
		"strokes": [source_stroke],
	}

func _find_tilt_reference_stroke(tilt_data: Dictionary) -> Dictionary:
	var ob = OpenBrushScript.new()
	ob.ensure_loaded()
	var matches: Array[Dictionary] = []
	for stroke in tilt_data.get("strokes", []):
		if not stroke is Dictionary:
			continue
		var brush_name: String = ob.resolve_brush_name(String(stroke.get("brush_guid", "")))
		if brush_name == TiltPathReferenceBrush:
			matches.append(stroke)
	if matches.is_empty():
		return {}
	var index := clampi(TiltPathReferenceStrokeIndex, 0, matches.size() - 1)
	return matches[index]

func draw_stroke(path: Array[TrTransform], brush: BrushDescriptor, color: Color) -> Stroke:
	if brush == null or m_Canvas == null or m_Pointer == null:
		push_error("MinimalExample: cannot draw stroke without brush, canvas, and pointer")
		return null
	var smoothing := 0.0
	var control_points: Array[ControlPoint] = []
	var time := 0
	for vertex_index in range(path.size()):
		var xf := path[vertex_index]
		var next_position := path[(vertex_index + 1) % path.size()].translation
		_add_control_point(control_points, xf.translation, xf.rotation, xf.scale, time)
		time += 1
		if smoothing > 0.0:
			_add_control_point(control_points, xf.translation, xf.rotation, xf.scale, time)
			time += 1
			_add_control_point(control_points, xf.translation + (next_position - xf.translation) * smoothing, xf.rotation, xf.scale, time)
			time += 1
			_add_control_point(control_points, xf.translation + (next_position - xf.translation) * 0.5, xf.rotation, xf.scale, time)
			time += 1
			_add_control_point(control_points, xf.translation + (next_position - xf.translation) * (1.0 - smoothing), xf.rotation, xf.scale, time)
			time += 1
	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_IntendedCanvas = m_Canvas
	stroke.m_BrushGuid = brush.m_Guid
	stroke.m_BrushScale = 1.0
	stroke.m_BrushSize = 1.0
	stroke.m_Color = color
	stroke.m_Seed = 0
	stroke.m_ControlPoints = control_points
	stroke.m_ControlPointsToDrop = []
	for _index in range(control_points.size()):
		stroke.m_ControlPointsToDrop.append(false)
	m_Pointer.recreate_line_from_memory(stroke)
	return stroke

func _add_control_point(output: Array[ControlPoint], position: Vector3, orientation: Quaternion, pressure: float, timestamp: int) -> void:
	output.append(ControlPoint.create(position, orientation, pressure, timestamp))

func _apply_pointer_brush_size_range(brush: BrushDescriptor) -> void:
	if m_Pointer == null or brush == null:
		return
	if brush.m_BrushSizeRange.x > 0.0 and brush.m_BrushSizeRange.y >= brush.m_BrushSizeRange.x:
		m_Pointer.m_BrushSizeRange = brush.m_BrushSizeRange
