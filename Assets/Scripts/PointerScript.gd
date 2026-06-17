class_name PointerScript
extends Node3D

var DrawingEnabled := false
var m_WasDrawingEnabled := false
var Canvas: CanvasScript:
	get:
		return m_Canvas
	set(value):
		m_Canvas = value

var m_Canvas: CanvasScript
var m_CurrentColor := Color(0.2, 0.5, 1.0, 1.0)
var m_CurrentBrush: BrushDescriptor
var m_CurrentBrushSize := 0.1
var m_BrushSizeRange := Vector2(0.1, 0.2)
var m_CurrentPressure := 1.0
var m_CurrentLine: BaseBrushScript
var m_ControlPoints: Array[ControlPoint] = []
var m_LastControlPointIsKeeper := false

var BrushSize01: float:
	get:
		var min_radius := _from_radius(m_BrushSizeRange.x)
		var max_radius := _from_radius(m_BrushSizeRange.y)
		return _inverse_lerp(min_radius, max_radius, _from_radius(BrushSizeAbsolute))
	set(value):
		var min_radius := _from_radius(m_BrushSizeRange.x)
		var max_radius := _from_radius(m_BrushSizeRange.y)
		BrushSizeAbsolute = _to_radius(lerpf(min_radius, max_radius, clampf(value, 0.0, 1.0)))

var BrushSizeAbsolute: float:
	get:
		return m_CurrentBrushSize
	set(value):
		_set_brush_size_absolute(clampf(value, m_BrushSizeRange.x, m_BrushSizeRange.y))

func _ready() -> void:
	if m_ControlPoints == null:
		m_ControlPoints = []

func _process(_delta: float) -> void:
	if DrawingEnabled and not m_WasDrawingEnabled:
		create_new_line(m_Canvas, Coords.as_local(self))
	elif DrawingEnabled and m_WasDrawingEnabled:
		if m_CurrentLine != null and m_CurrentLine.is_inside_tree():
			update_line_from_object()
	elif not DrawingEnabled and m_WasDrawingEnabled:
		detach_line(false)
	m_WasDrawingEnabled = DrawingEnabled

func _from_radius(value: float) -> float:
	return sqrt(value)

func _to_radius(value: float) -> float:
	return value * value

func get_transform_for_line(line: Node3D, room_xf: TrTransform) -> TrTransform:
	var room_from_line := Coords.as_room(line) if line.is_inside_tree() else Coords.as_local(line)
	var xf := TrTransform.trs(room_xf.translation, room_xf.rotation, room_xf.scale)
	xf.translation -= xf.forward() * App.UNITS_TO_METERS
	xf.scale = 1.0
	return room_from_line.inverse().multiplied(xf)

func update_line_from_object() -> void:
	if m_CurrentLine == null:
		return
	var xf_rs := Coords.as_room(self) if is_inside_tree() else Coords.as_local(self)
	var xf_ls := get_transform_for_line(m_CurrentLine, xf_rs)
	var created := m_CurrentLine.update_position_ls(xf_ls, m_CurrentPressure)
	set_control_point(xf_ls, created)
	update_line_visuals()

func update_line_from_control_point(control_point: ControlPoint) -> void:
	if m_CurrentLine == null:
		return
	var scale := m_CurrentLine.stroke_scale()
	m_CurrentLine.update_position_ls(TrTransform.trs(control_point.m_Pos, control_point.m_Orient, scale), control_point.m_Pressure)

func update_line_from_stroke(stroke: Stroke) -> void:
	if m_CurrentLine == null:
		return
	var scale := m_CurrentLine.stroke_scale()
	for index in range(stroke.m_ControlPoints.size()):
		if index < stroke.m_ControlPointsToDrop.size() and stroke.m_ControlPointsToDrop[index]:
			continue
		var point := stroke.m_ControlPoints[index]
		m_CurrentLine.update_position_ls(TrTransform.trs(point.m_Pos, point.m_Orient, scale), point.m_Pressure)

func update_line_visuals() -> void:
	if m_CurrentLine != null:
		m_CurrentLine.apply_changes_to_visuals()

func create_new_line(canvas: CanvasScript, xf_cs: TrTransform, override_desc: BrushDescriptor = null) -> void:
	var desc := override_desc if override_desc != null else m_CurrentBrush
	if canvas == null:
		push_error("CreateNewLine: canvas is null")
		return
	if desc == null:
		push_error("CreateNewLine: brush descriptor is null")
		return
	m_CurrentLine = BaseBrushScript.create_brush(canvas, xf_cs, desc, m_CurrentColor, m_CurrentBrushSize)

func recreate_line_from_memory(stroke: Stroke) -> void:
	if stroke.m_Type != Stroke.Type.NOT_CREATED:
		push_error("Unexpected stroke state recreating line")
		return
	if begin_line_from_memory(stroke, stroke.canvas()) == null:
		push_error("Unexpected error recreating line")
		return
	update_line_from_stroke(stroke)
	m_CurrentLine.apply_changes_to_visuals()
	m_CurrentLine.finalize_solitary_brush()
	stroke.m_Type = Stroke.Type.BRUSH_STROKE
	stroke.m_IntendedCanvas = null
	stroke.m_Object = m_CurrentLine
	m_CurrentLine.stroke = stroke
	m_CurrentLine = null

func begin_line_from_memory(stroke: Stroke, canvas: CanvasScript) -> Node3D:
	var brush := BrushCatalog.get_brush(stroke.m_BrushGuid)
	if brush == null:
		return null
	if stroke.m_ControlPoints.is_empty() or canvas == null:
		return null
	var cp0 := stroke.m_ControlPoints[0]
	var xf_cs := TrTransform.trs(cp0.m_Pos, cp0.m_Orient, stroke.m_BrushScale)
	var canvas_pose := canvas.pose() if canvas.is_inside_tree() else Coords.as_local(canvas)
	var xf_rs := canvas_pose.multiplied(xf_cs)
	Coords.apply_local(self, xf_rs)
	m_CurrentBrush = brush
	m_CurrentBrushSize = stroke.m_BrushSize
	m_CurrentColor = stroke.m_Color
	create_new_line(canvas, xf_cs)
	if m_CurrentLine == null:
		return null
	m_CurrentLine.set_is_loading()
	m_CurrentLine.set_random_seed(stroke.m_Seed)
	return m_CurrentLine

func set_control_point(last_spawn_xf_ls: TrTransform, is_keeper: bool) -> void:
	var control_point := ControlPoint.create(
		last_spawn_xf_ls.translation,
		last_spawn_xf_ls.rotation,
		m_CurrentPressure,
		int(App.current_sketch_time() * 1000.0)
	)
	if m_ControlPoints.is_empty() or m_LastControlPointIsKeeper:
		m_ControlPoints.append(control_point)
	else:
		m_ControlPoints[m_ControlPoints.size() - 1] = control_point
	m_LastControlPointIsKeeper = is_keeper

func detach_line(discard: bool) -> void:
	if m_CurrentLine == null:
		return
	if discard:
		m_CurrentLine.destroy_mesh()
		m_CurrentLine.queue_free()
	else:
		m_CurrentLine.finalize_solitary_brush()
	m_CurrentLine = null

func _set_brush_size_absolute(value: float) -> void:
	m_CurrentBrushSize = value

static func _inverse_lerp(a: float, b: float, value: float) -> float:
	if absf(b - a) < 0.000001:
		return 0.0
	return (value - a) / (b - a)
