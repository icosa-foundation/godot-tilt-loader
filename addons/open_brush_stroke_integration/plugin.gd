@tool
extends EditorPlugin

var tilt_scene_importer: OpenBrushTiltSceneImporter

func _enter_tree() -> void:
	tilt_scene_importer = OpenBrushTiltSceneImporter.new()
	add_scene_format_importer_plugin(tilt_scene_importer)

func _exit_tree() -> void:
	if tilt_scene_importer != null:
		remove_scene_format_importer_plugin(tilt_scene_importer)
		tilt_scene_importer = null
