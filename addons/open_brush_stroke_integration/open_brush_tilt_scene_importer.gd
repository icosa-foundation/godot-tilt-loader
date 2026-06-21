@tool
class_name OpenBrushTiltSceneImporter
extends EditorSceneFormatImporter

## EditorSceneFormatImporter for Open Brush / Tilt Brush .tilt assets.
## GLTF/GLB import remains owned by the Icosa addon.

const _TiltReader := preload("res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd")
const _TiltSceneBuilder := preload("res://addons/open_brush_stroke_integration/open_brush_tilt_scene_builder.gd")

const IMPORT_LOG_PREFIX := "TILT_RUNTIME_IMPORT"

func _get_importer_name() -> String:
	return "icosa_open_brush"


func _get_extensions() -> PackedStringArray:
	return ["tilt"]


func _patch_tilt_import_file(path: String) -> void:
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return
	var file := FileAccess.open(import_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	if "meshes/generate_lods=false" in content and "meshes/create_shadow_meshes=false" in content:
		return
	var patched := content
	patched = patched.replace("meshes/generate_lods=true", "meshes/generate_lods=false")
	patched = patched.replace("meshes/create_shadow_meshes=true", "meshes/create_shadow_meshes=false")
	var out := FileAccess.open(import_path, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(patched)
	out.close()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().reimport_files([path])


func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	_patch_tilt_import_file(path)
	var start_ms := Time.get_ticks_msec()
	var reader := _TiltReader.new()
	var result: Dictionary = reader.load_tilt(path)
	if not result["error"].is_empty():
		_log_import_error("reader failed for %s: %s" % [path, result["error"]])
		return null
	var scene: Node3D = _TiltSceneBuilder.new().build_scene(result)
	if ProjectSettings.get_setting("icosa/debug/print_import_time", false):
		var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
		print("[%s] Import took %.2f s - %s" % [IMPORT_LOG_PREFIX, elapsed, path.get_file()])
	return scene


func _log_import_error(message: String) -> void:
	var line := "%s ERROR %s" % [IMPORT_LOG_PREFIX, message]
	push_error(line)
	var file := FileAccess.open("user://debug.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://debug.log", FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	file.close()
