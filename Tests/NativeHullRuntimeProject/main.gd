extends Node

const MARKER := "OBH_RUNTIME: native_extension_loaded=true ok=true"


func _ready() -> void:
	load("res://native/open_brush_hull/open_brush_hull.gdextension")
	if not ClassDB.class_exists("NativeConvexHullUtil"):
		_fail("native class is not registered")
		return

	var util = ClassDB.instantiate("NativeConvexHullUtil")
	if util == null:
		_fail("native class could not be instantiated")
		return

	var tetrahedron := PackedVector3Array([
		Vector3(1.0, 1.0, 1.0),
		Vector3(-1.0, -1.0, 1.0),
		Vector3(-1.0, 1.0, -1.0),
		Vector3(1.0, -1.0, -1.0),
	])
	var result: Dictionary = util.call("create", tetrahedron, 1e-5)
	if not bool(result.get("ok", false)):
		_fail("native tetrahedron hull failed")
		return
	if result.get("points", []).size() != 4 or result.get("faces", []).size() != 4:
		_fail("native tetrahedron hull returned unexpected topology")
		return

	print(MARKER)
	_write_result(MARKER)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"document.documentElement.setAttribute('data-obh-native', 'true');",
			true,
		)
	else:
		get_tree().quit(0)


func _fail(reason: String) -> void:
	var message := "OBH_RUNTIME: native_extension_loaded=false ok=false reason=%s" % reason
	printerr(message)
	_write_result(message)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"document.documentElement.setAttribute('data-obh-native', 'false');",
			true,
		)
	else:
		get_tree().quit(1)


func _write_result(message: String) -> void:
	var result_file := FileAccess.open("user://obh_runtime_result.txt", FileAccess.WRITE)
	if result_file != null:
		result_file.store_line(message)
		result_file.close()
