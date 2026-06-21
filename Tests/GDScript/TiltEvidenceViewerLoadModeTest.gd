extends SceneTree

const TiltEvidenceViewerScript := preload("res://Scripts/TiltEvidenceViewer.gd")

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	var viewer: TiltEvidenceViewer = TiltEvidenceViewerScript.new()
	_expect_equal(viewer.SceneLoadMode, TiltEvidenceViewer.LOAD_MODE_RUNTIME_REBUILD, "default load mode")
	viewer._set_load_mode("imported_packed_scene")
	_expect_equal(viewer.SceneLoadMode, TiltEvidenceViewer.LOAD_MODE_IMPORTED_PACKED_SCENE, "imported packed scene load mode")
	viewer._set_load_mode("runtime_rebuild")
	_expect_equal(viewer.SceneLoadMode, TiltEvidenceViewer.LOAD_MODE_RUNTIME_REBUILD, "runtime rebuild load mode")
	viewer.free()
	if _failures == 0:
		print("GDSCRIPT_TILT_EVIDENCE_LOAD_MODE: all checks passed")

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_TILT_EVIDENCE_LOAD_MODE: %s" % message)
