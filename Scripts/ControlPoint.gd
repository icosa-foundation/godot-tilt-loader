class_name ControlPoint
extends RefCounted

var m_Pos: Vector3
var m_Orient: Quaternion
var m_Pressure: float
var m_TimestampMs: int

static func create(position: Vector3, orientation: Quaternion, pressure: float, timestamp_ms: int) -> ControlPoint:
	var point := ControlPoint.new()
	point.m_Pos = position
	point.m_Orient = orientation
	point.m_Pressure = pressure
	point.m_TimestampMs = timestamp_ms
	return point

func duplicate_point() -> ControlPoint:
	return ControlPoint.create(m_Pos, m_Orient, m_Pressure, m_TimestampMs)
