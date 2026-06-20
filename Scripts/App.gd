class_name App
extends Node3D

const METERS_TO_UNITS := 10.0
const UNITS_TO_METERS := 0.1

@export var EnableXR := false

static var m_sketch_time_base := 0.0

static func current_sketch_time() -> float:
	return Time.get_ticks_msec() / 1000.0 - m_sketch_time_base

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not _should_enable_xr():
		get_viewport().use_xr = false
		return
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface != null and xr_interface.initialize():
		print("App: XR Interface initialized successfully")
		get_viewport().use_xr = true
	else:
		push_warning("App: OpenXR interface is not available")

func _should_enable_xr() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--disable-xr":
			return false
		if arg == "--enable-xr":
			return true
	return EnableXR
