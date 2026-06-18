class_name Stroke
extends StrokeData

enum Type {
	NOT_CREATED,
	BRUSH_STROKE,
	BATCHED_BRUSH_STROKE,
}

var m_Type := Type.NOT_CREATED
var m_IntendedCanvas: CanvasScript
var m_Object: Node3D
var m_ControlPointsToDrop: Array[bool] = []
var _copy_for_save_thread: StrokeData

func _init(existing: Stroke = null) -> void:
	m_Guid = _new_guid_string()
	if existing != null:
		copy_from(existing)
		m_ControlPointsToDrop = existing.m_ControlPointsToDrop.duplicate()
		m_Type = Type.NOT_CREATED
		m_IntendedCanvas = existing.canvas()
		m_Object = null
		m_Guid = _new_guid_string()

func canvas() -> CanvasScript:
	if m_Type == Type.NOT_CREATED:
		return m_IntendedCanvas
	if m_Type == Type.BRUSH_STROKE and m_Object != null:
		var current := m_Object
		while current != null:
			if current is CanvasScript:
				return current as CanvasScript
			current = current.get_parent() as Node3D
		return null
	push_error("Stroke canvas is not available for type %s" % [m_Type])
	return null

func invalidate_copy() -> void:
	_copy_for_save_thread = null

func uncreate() -> void:
	m_IntendedCanvas = canvas()
	if m_Object != null:
		m_Object.queue_free()
		m_Object = null
	m_Type = Type.NOT_CREATED

func set_parent(canvas_node: CanvasScript) -> void:
	var previous_canvas := canvas()
	if previous_canvas == canvas_node:
		return
	if m_Type == Type.BRUSH_STROKE and m_Object != null:
		canvas_node.add_child(m_Object)
	elif m_Type == Type.NOT_CREATED:
		m_IntendedCanvas = canvas_node

func left_transform_control_points(left_transform: TrTransform, absolute_scale: bool = false) -> void:
	for index in range(m_ControlPoints.size()):
		var point := m_ControlPoints[index]
		var old_xf := TrTransform.from_translation_rotation(point.m_Pos, point.m_Orient)
		var new_xf := left_transform.multiplied(old_xf)
		point.m_Pos = new_xf.translation
		point.m_Orient = new_xf.rotation
		m_ControlPoints[index] = point
	m_BrushScale *= abs(left_transform.scale) if absolute_scale else left_transform.scale
	invalidate_copy()

func hide(hidden: bool) -> void:
	if m_Type == Type.BRUSH_STROKE and m_Object != null:
		m_Object.visible = not hidden
	elif m_Type == Type.NOT_CREATED:
		push_error("Unexpected: NotCreated stroke")

static func _new_guid_string() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x-%04x-%04x-%04x-%012x" % [
		rng.randi(),
		rng.randi() & 0xffff,
		(rng.randi() & 0x0fff) | 0x4000,
		(rng.randi() & 0x3fff) | 0x8000,
		(rng.randi() << 32) | rng.randi()
	]
