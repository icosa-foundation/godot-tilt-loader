class_name SingleBrushStrokeInspector
extends Node3D

@export var CanvasPath: NodePath
@export var BrushSystemPath: NodePath
@export var LabelPath: NodePath
@export var StrokeColor := Color(0.2, 0.5, 1.0, 1.0)
@export var StrokeSize := 1.5
@export var StrokeRadius := 4.0
@export var StrokeSegments := 72

var Canvas: MinimalExample
var BrushSystem: BrushSystemSetup
var BrushLabel: Label
var _brushes: Array[BrushDescriptor] = []
var _current_index := 0
var _left_was_pressed := false
var _right_was_pressed := false

func _ready() -> void:
	if not CanvasPath.is_empty():
		Canvas = get_node_or_null(CanvasPath) as MinimalExample
	if not BrushSystemPath.is_empty():
		BrushSystem = get_node_or_null(BrushSystemPath) as BrushSystemSetup
	if not LabelPath.is_empty():
		BrushLabel = get_node_or_null(LabelPath) as Label
	_load_brushes()
	_select_initial_brush()
	_show_current_brush()

func _process(_delta: float) -> void:
	var left_pressed := Input.is_physical_key_pressed(KEY_LEFT)
	var right_pressed := Input.is_physical_key_pressed(KEY_RIGHT)
	if left_pressed and not _left_was_pressed:
		step_brush(-1)
	if right_pressed and not _right_was_pressed:
		step_brush(1)
	_left_was_pressed = left_pressed
	_right_was_pressed = right_pressed

func step_brush(direction: int) -> void:
	if _brushes.is_empty():
		return
	_current_index = (_current_index + direction + _brushes.size()) % _brushes.size()
	_show_current_brush()

func _load_brushes() -> void:
	_brushes.clear()
	if BrushSystem != null and BrushSystem.manifest != null:
		for brush in BrushSystem.manifest.Brushes:
			if brush != null and not BrushRuntimeRegistry.is_compatibility_brush(BrushSystem.manifest, brush):
				_brushes.append(brush)
	else:
		_brushes = BrushCatalog.all_brushes()
	_brushes = _brushes.filter(func(brush: BrushDescriptor) -> bool:
		return brush != null and BrushRuntimeRegistry.is_supported(brush)
	)

func _select_initial_brush() -> void:
	if _brushes.is_empty():
		return
	for index in range(_brushes.size()):
		if _brushes[index].m_DurableName == "Ink":
			_current_index = index
			return
	_current_index = 0

func _show_current_brush() -> void:
	if Canvas == null:
		_set_label_text("No canvas")
		return
	if _brushes.is_empty():
		_set_label_text("No runtime brushes")
		return
	var brush := _brushes[_current_index]
	_clear_generated_stroke()
	Canvas.draw_stroke(_make_sample_path(), brush, StrokeColor)
	_set_label_text("%03d / %03d  %s  %s" % [
		_current_index + 1,
		_brushes.size(),
		brush.m_DurableName,
		_prefab_name(brush),
	])

func _clear_generated_stroke() -> void:
	if Canvas == null or Canvas.m_Canvas == null:
		return
	for index in range(Canvas.m_Canvas.get_child_count() - 1, -1, -1):
		Canvas.m_Canvas.get_child(index).free()

func _make_sample_path() -> Array[TrTransform]:
	var path: Array[TrTransform] = []
	var segments := maxi(StrokeSegments, 2)
	for index in range(segments):
		var t := float(index) / float(segments - 1)
		var x := lerpf(-StrokeRadius, StrokeRadius, t)
		var y := sin(t * TAU * 1.25) * StrokeRadius * 0.35
		var z := cos(t * TAU * 0.75) * StrokeRadius * 0.16
		var position := Vector3(x, y, z)
		var next_t := minf(1.0, t + 1.0 / float(segments - 1))
		var next_position := Vector3(
			lerpf(-StrokeRadius, StrokeRadius, next_t),
			sin(next_t * TAU * 1.25) * StrokeRadius * 0.35,
			cos(next_t * TAU * 0.75) * StrokeRadius * 0.16
		)
		var tangent := (next_position - position).normalized()
		var orientation := Basis.looking_at(tangent if tangent.length() > 0.0001 else Vector3.RIGHT, Vector3.UP).get_rotation_quaternion()
		path.append(TrTransform.trs(position, orientation, StrokeSize))
	return path

func _set_label_text(text: String) -> void:
	if BrushLabel != null:
		BrushLabel.text = text

func _prefab_name(brush: BrushDescriptor) -> String:
	if brush == null or brush.prefab_fields == null:
		return ""
	return String(brush.prefab_fields.get("prefab_name", ""))
