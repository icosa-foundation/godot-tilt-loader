class_name StrokeData
extends RefCounted

var m_Color := Color.WHITE
var m_BrushGuid := ""
var m_BrushSize := 0.0
var m_BrushScale := 1.0
var m_ControlPoints: Array[ControlPoint] = []
var m_Seed := 0
var m_Guid := ""

func copy_from(existing: StrokeData) -> void:
	m_Color = existing.m_Color
	m_BrushGuid = existing.m_BrushGuid
	m_BrushSize = existing.m_BrushSize
	m_BrushScale = existing.m_BrushScale
	m_Seed = existing.m_Seed
	m_Guid = existing.m_Guid
	m_ControlPoints = []
	for point in existing.m_ControlPoints:
		m_ControlPoints.append(point.duplicate_point())
