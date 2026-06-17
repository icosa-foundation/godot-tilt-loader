class_name SimpleStrokeDemo
extends Node3D

@export var Canvas: CanvasScript
@export var Pointer: PointerScript
@export var DrawOnStart := false
@export var MoveSpeed := 1.0

var _time := 0.0
var _isDrawing := false

func _ready() -> void:
	if Canvas == null:
		Canvas = get_node_or_null("Canvas") as CanvasScript
	if Pointer == null:
		Pointer = get_node_or_null("Pointer") as PointerScript
	if Canvas == null:
		push_error("SimpleStrokeDemo: No Canvas found. Assign a CanvasScript in the inspector.")
	if Pointer == null:
		push_error("SimpleStrokeDemo: No Pointer found. Assign a PointerScript in the inspector.")
	if Pointer != null and Canvas != null:
		Pointer.Canvas = Canvas
		Pointer.m_CurrentColor = Color.RED
		Pointer.BrushSize01 = 0.5
		Pointer.m_CurrentPressure = 1.0
		if DrawOnStart:
			_isDrawing = true
			Pointer.DrawingEnabled = true

func _process(delta: float) -> void:
	if Pointer == null:
		return
	if Input.is_key_pressed(KEY_SPACE) and not _isDrawing:
		_isDrawing = true
		Pointer.DrawingEnabled = true
	elif not Input.is_key_pressed(KEY_SPACE) and _isDrawing:
		_isDrawing = false
		Pointer.DrawingEnabled = false
	if _isDrawing:
		_time += delta * MoveSpeed
		var radius := 2.0
		Pointer.position = Vector3(cos(_time) * radius, sin(_time * 2.0) * 0.5, sin(_time) * radius)
	if Input.is_key_pressed(KEY_R):
		reset_demo()

func reset_demo() -> void:
	_isDrawing = false
	_time = 0.0
	if Pointer != null:
		Pointer.DrawingEnabled = false
		Pointer.position = Vector3.ZERO
