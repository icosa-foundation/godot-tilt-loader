class_name MinimalXrExample
extends Node3D

@export var BrushSystemPath: NodePath
@export var PointerPath: NodePath
@export var LeftControllerPath: NodePath
@export var RightControllerPath: NodePath
@export var PointerColor := Color(0.2, 0.5, 1.0, 1.0)
@export var PointerSize01 := 0.05
@export var DrawAction := &"trigger_click"
@export var LeftThumbstickAction := &"primary"
@export var RightThumbstickAction := &"primary"
@export var ClearAllAction := &"by_button"
@export var BrushSizeChangeSpeed := 0.3
@export var DefaultBrushSize := 0.05

const THUMBSTICK_DEADZONE := 0.5

var BrushSystem: BrushSystemSetup
var m_Pointer: PointerScript
var m_Canvas: CanvasScript
var _runtimeBrush: BrushDescriptor
var _leftController: XRController3D
var _rightController: XRController3D
var _logFile: FileAccess
var _currentBrushIndex := 0
var _lastLeftThumbstickX := 0.0
var _leftThumbstickTriggered := false
var _debugFrameCounter := 0
var _clearButtonWasPressed := false
var _setup_done := false

func _ready() -> void:
	call_deferred("setup")

func setup() -> void:
	if _setup_done:
		return
	_setup_done = true
	log_debug("XRDEBUG: MinimalXrExample ready")
	log_debug("XRDEBUG: debug log file: %s" % ProjectSettings.globalize_path("user://xr_debug.log"))
	log_debug("XRDEBUG: App.METERS_TO_UNITS = %.3f" % App.METERS_TO_UNITS)
	if BrushSystem == null and not BrushSystemPath.is_empty():
		BrushSystem = get_node_or_null(BrushSystemPath) as BrushSystemSetup
	if m_Pointer == null and not PointerPath.is_empty():
		m_Pointer = get_node_or_null(PointerPath) as PointerScript
	if _leftController == null and not LeftControllerPath.is_empty():
		_leftController = get_node_or_null(LeftControllerPath) as XRController3D
	if _rightController == null and not RightControllerPath.is_empty():
		_rightController = get_node_or_null(RightControllerPath) as XRController3D
	if BrushSystem == null:
		push_error("MinimalXrExample: BrushSystemPath does not point to a BrushSystemSetup")
	if m_Pointer == null:
		push_error("MinimalXrExample: PointerPath does not point to a PointerScript")
	if _rightController == null:
		push_error("MinimalXrExample: RightControllerPath does not point to an XRController3D")
	if BrushSystem != null:
		_runtimeBrush = BrushSystem.get_brush_by_name("Ink")
		if _runtimeBrush == null:
			_runtimeBrush = BrushSystem.get_default_brush()
		if BrushSystem.manifest != null and BrushSystem.manifest.Brushes != null:
			_currentBrushIndex = BrushSystem.manifest.Brushes.find(_runtimeBrush)
			if _currentBrushIndex < 0:
				_currentBrushIndex = 0
	var xr_origin := get_node_or_null("../XROrigin3D") as XROrigin3D
	if xr_origin == null:
		xr_origin = get_parent() as XROrigin3D
	if xr_origin == null:
		push_error("MinimalXrExample: Could not find XROrigin3D")
		return
	m_Canvas = CanvasScript.new()
	m_Canvas.name = "CanvasScript"
	xr_origin.add_child(m_Canvas)
	if m_Pointer != null:
		m_Pointer.Canvas = m_Canvas
		if _runtimeBrush != null:
			m_Pointer.m_CurrentBrush = _runtimeBrush
		m_Pointer.m_CurrentColor = PointerColor
		m_Pointer.BrushSize01 = PointerSize01
		m_Pointer.m_CurrentPressure = 1.0

func _process(delta: float) -> void:
	_debugFrameCounter += 1
	if _debugFrameCounter % 60 == 0:
		if _rightController != null:
			log_debug("XRDEBUG: Right controller active: %s pos: %s" % [_rightController.get_is_active(), _rightController.global_position])
		if _leftController != null:
			log_debug("XRDEBUG: Left controller active: %s pos: %s" % [_leftController.get_is_active(), _leftController.global_position])
	if m_Pointer == null or _rightController == null:
		return
	m_Pointer.global_position = _rightController.global_position
	m_Pointer.global_basis = _rightController.global_basis
	var trigger_pressed := _rightController.is_button_pressed(DrawAction)
	if trigger_pressed != m_Pointer.DrawingEnabled:
		log_debug("XRDEBUG: Trigger %s" % ("PRESSED" if trigger_pressed else "RELEASED"))
	m_Pointer.DrawingEnabled = trigger_pressed
	if _leftController != null:
		var clear_pressed := _leftController.is_button_pressed(ClearAllAction)
		if clear_pressed and not _clearButtonWasPressed:
			clear_canvas()
		_clearButtonWasPressed = clear_pressed
	handle_left_thumbstick()
	handle_right_thumbstick(delta)

func log_debug(message: String) -> void:
	print(message)
	if _logFile == null:
		_logFile = FileAccess.open("user://xr_debug.log", FileAccess.WRITE)
	if _logFile != null:
		_logFile.store_line("[%.2f] %s" % [Time.get_ticks_msec() / 1000.0, message])
		_logFile.flush()

func clear_canvas() -> void:
	if m_Canvas != null:
		m_Canvas.clear_canvas()

func handle_left_thumbstick() -> void:
	if _leftController == null or BrushSystem == null or BrushSystem.manifest == null or BrushSystem.manifest.Brushes.is_empty():
		return
	var left_thumbstick := _leftController.get_vector2(LeftThumbstickAction)
	var thumbstick_x := left_thumbstick.x
	var abs_thumbstick := absf(thumbstick_x)
	if abs_thumbstick >= THUMBSTICK_DEADZONE and not _leftThumbstickTriggered:
		_leftThumbstickTriggered = true
		var brush_count := BrushSystem.manifest.Brushes.size()
		_currentBrushIndex = (_currentBrushIndex + (1 if thumbstick_x > 0.0 else -1) + brush_count) % brush_count
		_runtimeBrush = BrushSystem.manifest.Brushes[_currentBrushIndex]
		m_Pointer.m_CurrentBrush = _runtimeBrush
		m_Pointer.BrushSize01 = DefaultBrushSize
	elif abs_thumbstick < THUMBSTICK_DEADZONE:
		_leftThumbstickTriggered = false
	_lastLeftThumbstickX = thumbstick_x

func handle_right_thumbstick(delta: float) -> void:
	if _rightController == null or m_Pointer == null:
		return
	var right_thumbstick := _rightController.get_vector2(RightThumbstickAction)
	var thumbstick_x := right_thumbstick.x
	if absf(thumbstick_x) > THUMBSTICK_DEADZONE:
		var size_change := thumbstick_x * BrushSizeChangeSpeed * delta
		m_Pointer.BrushSize01 = clampf(m_Pointer.BrushSize01 + size_change, 0.0, 1.0)
