class_name BrushStrokeReplay
extends RefCounted

static func create_brush_for_stroke(stroke: Stroke, canvas: CanvasScript = null) -> BaseBrushScript:
	if stroke == null:
		push_error("BrushStrokeReplay: stroke is null")
		return null
	if stroke.m_Type != Stroke.Type.NOT_CREATED:
		push_error("BrushStrokeReplay: expected NOT_CREATED stroke")
		return null
	if stroke.m_ControlPoints.size() < 2:
		push_error("BrushStrokeReplay: stroke has fewer than two control points")
		return null
	var desc := BrushCatalog.get_brush(stroke.m_BrushGuid)
	if desc == null:
		push_error("BrushStrokeReplay: unknown brush guid %s" % stroke.m_BrushGuid)
		return null

	var target_canvas := canvas if canvas != null else stroke.canvas()
	var first := stroke.m_ControlPoints[0]
	var first_xf := TrTransform.trs(first.m_Pos, first.m_Orient, stroke.m_BrushScale)
	var brush: BaseBrushScript
	if target_canvas != null:
		brush = BaseBrushScript.create_brush(target_canvas, first_xf, desc, stroke.m_Color, stroke.m_BrushSize)
	else:
		var registry := load("res://Scripts/Brushes/BrushRuntimeRegistry.gd")
		brush = registry.create_brush_for_descriptor(desc)
		if brush != null:
			brush.m_Color = stroke.m_Color
			brush.m_BaseSize_PS = stroke.m_BrushSize
			brush.init_brush(desc, first_xf)
	if brush == null:
		push_error("BrushStrokeReplay: failed to create brush for %s" % desc.m_DurableName)
		return null

	brush.set_is_loading()
	brush.set_random_seed(stroke.m_Seed)
	for index in range(1, stroke.m_ControlPoints.size()):
		if index < stroke.m_ControlPointsToDrop.size() and stroke.m_ControlPointsToDrop[index]:
			continue
		var point := stroke.m_ControlPoints[index]
		brush.update_position_ls(TrTransform.trs(point.m_Pos, point.m_Orient, stroke.m_BrushScale), point.m_Pressure)
	brush.apply_changes_to_visuals()
	brush.finalize_for_runtime()
	return brush

static func build_mesh_data_for_stroke(stroke: Stroke) -> MeshData:
	var brush := create_brush_for_stroke(stroke)
	if brush == null:
		return null
	var result := MeshData.new()
	result.copy_from(brush.mesh_data)
	brush.free()
	return result

static func attach_brush_to_stroke(stroke: Stroke, canvas: CanvasScript = null) -> bool:
	var brush := create_brush_for_stroke(stroke, canvas)
	if brush == null:
		return false
	stroke.m_Type = Stroke.Type.BRUSH_STROKE
	stroke.m_IntendedCanvas = null
	stroke.m_Object = brush
	brush.stroke = stroke
	return true
