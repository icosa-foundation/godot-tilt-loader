class_name PointerScript
extends Node3D

const BrushStrokeReplayScript := preload("res://Scripts/Brushes/BrushStrokeReplay.gd")

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
var EnableLiveStrokeDiagnostics := true
var _liveStrokeSerial := 0
var _liveStrokeUpdateCount := 0
var _liveStrokeKeeperCount := 0

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
		var xf_cs := get_transform_for_canvas(m_Canvas, Coords.as_room(self)) if m_Canvas != null else Coords.as_local(self)
		create_new_line(m_Canvas, xf_cs)
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
	xf.scale = 1.0
	return room_from_line.inverse().multiplied(xf)

func get_transform_for_canvas(canvas: CanvasScript, room_xf: TrTransform) -> TrTransform:
	if canvas == null:
		return room_xf
	var room_from_canvas := Coords.as_room(canvas) if canvas.is_inside_tree() else Coords.as_local(canvas)
	var xf := TrTransform.trs(room_xf.translation, room_xf.rotation, room_xf.scale)
	var canvas_from_pointer := room_from_canvas.inverse().multiplied(xf)
	canvas_from_pointer.scale = 1.0
	return canvas_from_pointer

func update_line_from_object() -> void:
	if m_CurrentLine == null:
		return
	var xf_rs := Coords.as_room(self) if is_inside_tree() else Coords.as_local(self)
	var canvas := m_CurrentLine.canvas()
	var xf_ls := get_transform_for_canvas(canvas, xf_rs) if canvas != null else get_transform_for_line(m_CurrentLine, xf_rs)
	var created := m_CurrentLine.update_position_ls(xf_ls, m_CurrentPressure)
	set_control_point(xf_ls, created)
	update_line_visuals()

func update_line_from_control_point(control_point: ControlPoint) -> void:
	if m_CurrentLine == null:
		return
	var scale := m_CurrentLine.stroke_scale()
	m_CurrentLine.update_position_ls(TrTransform.trs(control_point.m_Pos, control_point.m_Orient, scale), control_point.m_Pressure)

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
	_apply_brush_size_range(desc)
	m_ControlPoints.clear()
	m_LastControlPointIsKeeper = false
	_liveStrokeSerial += 1
	_liveStrokeUpdateCount = 0
	_liveStrokeKeeperCount = 0
	m_CurrentLine = BaseBrushScript.create_brush(canvas, xf_cs, desc, m_CurrentColor, m_CurrentBrushSize)
	if m_CurrentLine != null:
		_log_live_stroke("BEGIN serial=%d brush=%s guid=%s size=%.6f scale=%.6f pos=%s rot=%s canvas_children=%d" % [
			_liveStrokeSerial,
			desc.m_DurableName,
			desc.m_Guid,
			m_CurrentBrushSize,
			xf_cs.scale,
			_fmt_vec3(xf_cs.translation),
			_fmt_quat(xf_cs.rotation),
			canvas.get_child_count(),
		])

func recreate_line_from_memory(stroke: Stroke) -> void:
	var canvas := stroke.canvas()
	if not BrushStrokeReplayScript.attach_brush_to_stroke(stroke, canvas):
		push_error("Unexpected error recreating line")
		return
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
	_liveStrokeUpdateCount += 1
	if is_keeper:
		_liveStrokeKeeperCount += 1
	if _liveStrokeUpdateCount <= 8 or is_keeper:
		_log_live_stroke("POINT serial=%d update=%d keeper=%s cp_count=%d pos=%s rot=%s pressure=%.4f" % [
			_liveStrokeSerial,
			_liveStrokeUpdateCount,
			is_keeper,
			m_ControlPoints.size(),
			_fmt_vec3(last_spawn_xf_ls.translation),
			_fmt_quat(last_spawn_xf_ls.rotation),
			m_CurrentPressure,
		])

func detach_line(discard: bool) -> void:
	if m_CurrentLine == null:
		return
	_log_live_stroke_summary("PRE_FINALIZE", m_CurrentLine)
	if discard:
		m_CurrentLine.destroy_mesh()
		m_CurrentLine.queue_free()
	else:
		m_CurrentLine.finalize_for_runtime()
		_log_live_stroke_summary("FINAL", m_CurrentLine)
		_compare_live_stroke_to_recorded_replay(m_CurrentLine)
	m_CurrentLine = null

func _compare_live_stroke_to_recorded_replay(live_brush: BaseBrushScript) -> void:
	if not EnableLiveStrokeDiagnostics or DisplayServer.get_name() == "headless":
		return
	if live_brush == null or m_CurrentBrush == null or m_ControlPoints.size() < 2:
		return
	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_BrushGuid = m_CurrentBrush.m_Guid
	stroke.m_BrushScale = live_brush.stroke_scale()
	stroke.m_BrushSize = m_CurrentBrushSize
	stroke.m_Color = m_CurrentColor
	stroke.m_Seed = live_brush.random_seed()
	stroke.m_ControlPoints = m_ControlPoints.duplicate()
	stroke.m_ControlPointsToDrop = []
	for _index in range(stroke.m_ControlPoints.size()):
		stroke.m_ControlPointsToDrop.append(false)
	var replay := BrushStrokeReplayScript.build_mesh_data_for_stroke(stroke)
	if replay == null:
		_log_live_stroke("REPLAY serial=%d failed cp_count=%d" % [_liveStrokeSerial, m_ControlPoints.size()])
		return
	var comparison := _compare_mesh_data(live_brush.mesh_data, replay)
	_log_live_stroke("REPLAY_COMPARE serial=%d live_verts=%d replay_verts=%d live_uv0=%d replay_uv0=%d max_vertex_delta=%.8f max_uv_delta=%.8f" % [
		_liveStrokeSerial,
		comparison.live_vertices,
		comparison.replay_vertices,
		comparison.live_uv0,
		comparison.replay_uv0,
		comparison.max_vertex_delta,
		comparison.max_uv_delta,
	])

func _compare_mesh_data(live_mesh: MeshData, replay_mesh: MeshData) -> Dictionary:
	var result := {
		"live_vertices": live_mesh.vertices.size(),
		"replay_vertices": replay_mesh.vertices.size(),
		"live_uv0": _primary_uv_count(live_mesh),
		"replay_uv0": _primary_uv_count(replay_mesh),
		"max_vertex_delta": INF,
		"max_uv_delta": INF,
	}
	if live_mesh.vertices.size() == replay_mesh.vertices.size():
		var max_vertex_delta := 0.0
		for index in range(live_mesh.vertices.size()):
			max_vertex_delta = maxf(max_vertex_delta, live_mesh.vertices[index].distance_to(replay_mesh.vertices[index]))
		result.max_vertex_delta = max_vertex_delta
	var live_uvs := _primary_uv2(live_mesh)
	var replay_uvs := _primary_uv2(replay_mesh)
	if live_uvs.size() == replay_uvs.size():
		var max_uv_delta := 0.0
		for index in range(live_uvs.size()):
			max_uv_delta = maxf(max_uv_delta, live_uvs[index].distance_to(replay_uvs[index]))
		result.max_uv_delta = max_uv_delta
	return result

func _log_live_stroke_summary(stage: String, brush: BaseBrushScript) -> void:
	if brush == null:
		return
	var mesh := brush.mesh_data
	var material_info := _live_material_info(brush)
	var bounds := _mesh_bounds(mesh)
	var brush_position := brush.global_position if brush.is_inside_tree() else brush.position
	_log_live_stroke("%s serial=%d brush=%s updates=%d keepers=%d cp_count=%d verts=%d tris=%d uv0_v2=%d uv0_v3=%d uv0_v4=%d colors=%d tangents=%d scale=%.6f brush_global_pos=%s mesh_bounds_min=%s mesh_bounds_max=%s material=%s" % [
		stage,
		_liveStrokeSerial,
		brush.m_Desc.m_DurableName if brush.m_Desc != null else "<null>",
		_liveStrokeUpdateCount,
		_liveStrokeKeeperCount,
		m_ControlPoints.size(),
		mesh.vertices.size(),
		mesh.triangles.size() / 3,
		mesh.uv0_v2.size(),
		mesh.uv0_v3.size(),
		mesh.uv0_v4.size(),
		mesh.colors.size(),
		mesh.tangents.size(),
		brush.stroke_scale(),
		_fmt_vec3(brush_position),
		_fmt_vec3(bounds["min"]),
		_fmt_vec3(bounds["max"]),
		material_info,
	])

func _live_material_info(brush: BaseBrushScript) -> String:
	var mesh_instance := brush.get_node_or_null("GeneratedMesh") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return "<none>"
	var material := mesh_instance.mesh.surface_get_material(0)
	if material == null:
		return "<null>"
	var info := "%s:%s" % [material.get_class(), material.resource_path]
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		info += ":shader=%s" % (shader.resource_path if shader != null else "<null>")
	elif material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		info += ":cull=%d:transparency=%d:albedo=%s:texture=%s" % [
			base.cull_mode,
			base.transparency,
			base.albedo_color,
			base.albedo_texture.resource_path if base.albedo_texture != null else "<null>",
		]
	return info

func _mesh_bounds(mesh: MeshData) -> Dictionary:
	if mesh == null or mesh.vertices.is_empty():
		return {"min": Vector3.ZERO, "max": Vector3.ZERO}
	var min_value := mesh.vertices[0]
	var max_value := mesh.vertices[0]
	for vertex in mesh.vertices:
		min_value.x = minf(min_value.x, vertex.x)
		min_value.y = minf(min_value.y, vertex.y)
		min_value.z = minf(min_value.z, vertex.z)
		max_value.x = maxf(max_value.x, vertex.x)
		max_value.y = maxf(max_value.y, vertex.y)
		max_value.z = maxf(max_value.z, vertex.z)
	return {"min": min_value, "max": max_value}

func _primary_uv_count(mesh: MeshData) -> int:
	return _primary_uv2(mesh).size()

func _primary_uv2(mesh: MeshData) -> Array[Vector2]:
	if mesh.uv0_v2.size() == mesh.vertices.size():
		return mesh.uv0_v2
	if mesh.uv0_v3.size() == mesh.vertices.size():
		var values: Array[Vector2] = []
		for uv in mesh.uv0_v3:
			values.append(Vector2(uv.x, uv.y))
		return values
	if mesh.uv0_v4.size() == mesh.vertices.size():
		var values: Array[Vector2] = []
		for uv in mesh.uv0_v4:
			values.append(Vector2(uv.x, uv.y))
		return values
	return []

func _log_live_stroke(message: String) -> void:
	if not EnableLiveStrokeDiagnostics or DisplayServer.get_name() == "headless":
		return
	var file := FileAccess.open("user://xr_debug.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://xr_debug.log", FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("[%.2f] LIVE_STROKE_TRACE %s" % [Time.get_ticks_msec() / 1000.0, message])
	file.flush()

func _fmt_vec3(value: Vector3) -> String:
	return "(%.5f,%.5f,%.5f)" % [value.x, value.y, value.z]

func _fmt_quat(value: Quaternion) -> String:
	return "(%.5f,%.5f,%.5f,%.5f)" % [value.x, value.y, value.z, value.w]

func _set_brush_size_absolute(value: float) -> void:
	m_CurrentBrushSize = value

func _apply_brush_size_range(desc: BrushDescriptor) -> void:
	if desc == null:
		return
	if desc.m_BrushSizeRange.x > 0.0 and desc.m_BrushSizeRange.y >= desc.m_BrushSizeRange.x:
		m_BrushSizeRange = desc.m_BrushSizeRange

static func _inverse_lerp(a: float, b: float, value: float) -> float:
	if absf(b - a) < 0.000001:
		return 0.0
	return (value - a) / (b - a)
