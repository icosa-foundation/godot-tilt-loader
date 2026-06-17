class_name SimpleDrawingController
extends Node3D

@export var PointerPath: NodePath
@export var CameraPath: NodePath
@export var CircleRadius := 2.0
@export var MoveSpeed := 1.0
@export var DrawOnStart := false
@export var DrawingPlaneZ := 0.0

var Pointer: PointerScript
var Camera: Camera3D
var _isDrawing := false
var _moveMode := false
var _time := 0.0
var _colors: Array[Color] = [
	Color.RED,
	Color.GREEN,
	Color(0.2, 0.5, 1.0, 1.0),
	Color.YELLOW,
	Color.WHITE,
]
var _currentColorIndex := 2
var _availableBrushes: Array[BrushDescriptor] = []
var _currentBrushIndex := 0
var _leftArrowWasPressed := false
var _rightArrowWasPressed := false
var _mKeyWasPressed := false
var _cKeyWasPressed := false

func _ready() -> void:
	if not PointerPath.is_empty:
		Pointer = get_node_or_null(PointerPath) as PointerScript
	if not CameraPath.is_empty:
		Camera = get_node_or_null(CameraPath) as Camera3D
	if Camera == null and get_viewport() != null:
		Camera = get_viewport().get_camera_3d()
	_availableBrushes = BrushCatalog.all_brushes()
	if not _availableBrushes.is_empty() and Pointer != null and Pointer.m_CurrentBrush != null:
		_currentBrushIndex = _availableBrushes.find(Pointer.m_CurrentBrush)
		if _currentBrushIndex < 0:
			_currentBrushIndex = 0
	if DrawOnStart and Pointer != null:
		start_drawing()

func _process(delta: float) -> void:
	if Pointer == null:
		return
	var space_pressed := Input.is_physical_key_pressed(KEY_SPACE)
	var m_pressed := Input.is_physical_key_pressed(KEY_M)
	var c_pressed := Input.is_physical_key_pressed(KEY_C)
	var r_pressed := Input.is_physical_key_pressed(KEY_R)
	if space_pressed and not _isDrawing:
		start_drawing()
	elif not space_pressed and _isDrawing:
		stop_drawing()
	if m_pressed and not _mKeyWasPressed:
		_moveMode = not _moveMode
		if _moveMode:
			_time = 0.0
	_mKeyWasPressed = m_pressed
	if Camera != null:
		var mouse_position := get_mouse_world_position()
		if _moveMode:
			_time += delta * MoveSpeed * 0.125
			var p := 3.0
			var q := 2.0
			var major_radius := CircleRadius * 0.5
			var minor_radius := CircleRadius * 0.5 * 0.4
			var t := _time
			mouse_position += Vector3(
				(major_radius + minor_radius * cos(q * t)) * cos(p * t),
				(major_radius + minor_radius * cos(q * t)) * sin(p * t),
				minor_radius * sin(q * t)
			)
		Pointer.global_position = mouse_position
	for index in range(_colors.size()):
		if Input.is_physical_key_pressed(KEY_1 + index) and index != _currentColorIndex:
			_currentColorIndex = index
			Pointer.m_CurrentColor = _colors[index]
	var left_pressed := Input.is_physical_key_pressed(KEY_LEFT)
	var right_pressed := Input.is_physical_key_pressed(KEY_RIGHT)
	if left_pressed and not _leftArrowWasPressed:
		cycle_brush(-1)
	if right_pressed and not _rightArrowWasPressed:
		cycle_brush(1)
	_leftArrowWasPressed = left_pressed
	_rightArrowWasPressed = right_pressed
	if c_pressed and not _cKeyWasPressed:
		clear_canvas()
	_cKeyWasPressed = c_pressed
	if r_pressed:
		reset()

func get_mouse_world_position() -> Vector3:
	if Camera == null or get_viewport() == null:
		return Vector3.ZERO
	var mouse_pos := get_viewport().get_mouse_position()
	var from := Camera.project_ray_origin(mouse_pos)
	var direction := Camera.project_ray_normal(mouse_pos)
	if absf(direction.z) > 0.0001:
		var t := (DrawingPlaneZ - from.z) / direction.z
		return from + direction * t
	return Vector3.ZERO

func start_drawing() -> void:
	if Pointer == null:
		return
	_isDrawing = true
	Pointer.DrawingEnabled = true

func stop_drawing() -> void:
	if Pointer == null:
		return
	_isDrawing = false
	Pointer.DrawingEnabled = false

func clear_canvas() -> void:
	if Pointer != null and Pointer.Canvas != null:
		Pointer.Canvas.clear_canvas()
	else:
		push_warning("Cannot clear canvas: Pointer or Canvas is null")

func reset() -> void:
	_isDrawing = false
	_moveMode = false
	_time = 0.0
	if Pointer != null:
		Pointer.DrawingEnabled = false
		Pointer.position = Vector3.ZERO

func cycle_brush(direction: int) -> void:
	if Pointer == null or _availableBrushes.is_empty():
		return
	_currentBrushIndex = (_currentBrushIndex + direction + _availableBrushes.size()) % _availableBrushes.size()
	Pointer.m_CurrentBrush = _availableBrushes[_currentBrushIndex]
