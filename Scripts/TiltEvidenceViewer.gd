class_name TiltEvidenceViewer
extends Node3D

@export var TiltFilePath := "res://Resources/Fixtures/brush_cafe_experimental.tilt"
@export var RenderOutputPath := "user://tilt_accurate_render.png"
@export var ThumbnailOutputPath := "user://tilt_reference_thumbnail.png"
@export var LogPath := "user://tilt_accurate_render.log"
@export_enum("runtime_rebuild", "imported_packed_scene") var SceneLoadMode := 0
@export var CameraMode := "cafe"
@export var AutoOrbit := true
@export var EnableFlyCamera := true
@export var FlyMoveSpeed := 5.0
@export var FlyFastMultiplier := 4.0
@export var MouseLookSensitivity := 0.003
@export var OrthographicZoomStep := 0.9
@export var CameraNear := 0.005
@export var OnlyBrushes := PackedStringArray()
@export var ForceDoubleSided := false
@export var NormalizeOpaqueHullMaterials := true

const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"
const TILT_SCENE_BUILDER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_scene_builder.gd"
const LOAD_MODE_RUNTIME_REBUILD := 0
const LOAD_MODE_IMPORTED_PACKED_SCENE := 1
const OPAQUE_HULL_MATERIALS := {
	"MatteHull": true,
	"ConcaveHull": true,
}
const OPAQUE_HULL_SHADER_CODE := """
shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 u_Color : source_color = vec4(1.0);
uniform float u_Cutoff = 0.5;

void fragment() {
	vec4 color = u_Color * COLOR;
	if (color.a < u_Cutoff) {
		discard;
	}

	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;
}
"""

var _scene_root: Node3D = null
var _quit_after_screenshot := false
var _camera: Camera3D = null
var _camera_target := Vector3.ZERO
var _camera_distance := 10.0
var _orbit_angle := 0.0
var _fly_camera_active := false
var _camera_yaw := 0.0
var _camera_pitch := 0.0

func _ready() -> void:
	_apply_command_line_args()
	_reset_log()
	_log("TILT_EVIDENCE: loading %s" % TiltFilePath)

	var reader_script := load(TILT_READER_PATH)
	if reader_script == null:
		_fail("TILT_EVIDENCE: missing reader at %s" % TILT_READER_PATH)
		return

	var tilt_data: Dictionary = reader_script.new().load_tilt(TiltFilePath)
	var reader_error := String(tilt_data.get("error", ""))
	if not reader_error.is_empty():
		_fail("TILT_EVIDENCE: reader error: %s" % reader_error)
		return
	_save_thumbnail(tilt_data.get("thumbnail", PackedByteArray()))

	_scene_root = _load_tilt_scene(tilt_data)
	if _scene_root == null:
		_fail("TILT_EVIDENCE: scene load returned null")
		return

	_scene_root.name = "TiltSceneRuntimeRebuild" if SceneLoadMode == LOAD_MODE_RUNTIME_REBUILD else "TiltSceneImportedPackedScene"
	add_child(_scene_root)
	_apply_brush_filter(_scene_root)
	if NormalizeOpaqueHullMaterials:
		_normalize_opaque_hull_materials(_scene_root)
	if ForceDoubleSided:
		_force_double_sided(_scene_root)

	var stats := _collect_scene_stats(_scene_root)
	if stats.mesh_instances == 0 or stats.vertices == 0:
		_fail("TILT_EVIDENCE: imported scene had no renderable mesh")
		return

	_add_camera(stats.bounds)
	_add_world()
	_log("TILT_EVIDENCE: scene strokes=%d mesh_instances=%d vertices=%d triangles=%d materials=%s bounds_min=%s bounds_max=%s" % [
		tilt_data.get("strokes", []).size(),
		stats.mesh_instances,
		stats.vertices,
		stats.triangles,
		", ".join(stats.materials),
		stats.bounds.min,
		stats.bounds.max,
	])

	await _save_render_after_frames()

	if _quit_after_screenshot:
		get_tree().quit(0)

func _load_tilt_scene(tilt_data: Dictionary) -> Node3D:
	if SceneLoadMode == LOAD_MODE_IMPORTED_PACKED_SCENE:
		_log("TILT_EVIDENCE: load_mode=imported_packed_scene path=%s" % TiltFilePath)
		return _load_imported_packed_scene()

	_log("TILT_EVIDENCE: load_mode=runtime_rebuild path=%s" % TiltFilePath)
	var builder_script := load(TILT_SCENE_BUILDER_PATH)
	if builder_script == null:
		_fail("TILT_EVIDENCE: missing scene builder at %s" % TILT_SCENE_BUILDER_PATH)
		return null
	var builder = builder_script.new()
	return builder.build_scene(tilt_data)

func _load_imported_packed_scene() -> Node3D:
	var imported := load(TiltFilePath)
	if not imported is PackedScene:
		_fail("TILT_EVIDENCE: %s did not load as an imported PackedScene; run Godot import first" % TiltFilePath)
		return null
	var scene := (imported as PackedScene).instantiate()
	if not scene is Node3D:
		_fail("TILT_EVIDENCE: imported PackedScene root is not Node3D")
		return null
	return scene as Node3D

func _save_render_after_frames() -> void:
	for _frame in range(5):
		await get_tree().process_frame
	_save_render()

func _process(delta: float) -> void:
	if _camera == null:
		return
	if EnableFlyCamera and _has_fly_camera_movement():
		AutoOrbit = false
		_process_fly_camera(delta)
		return
	if not AutoOrbit:
		return
	_orbit_angle += delta * 0.18
	var direction := Vector3(sin(_orbit_angle) * 0.65, 0.38, cos(_orbit_angle)).normalized()
	_camera.position = _camera_target + direction * _camera_distance
	_camera.look_at(_camera_target, Vector3.UP)
	_capture_camera_angles()

func _unhandled_input(event: InputEvent) -> void:
	if not EnableFlyCamera or _camera == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_fly_camera_active = event.pressed
			AutoOrbit = false
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _fly_camera_active else Input.MOUSE_MODE_VISIBLE)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(OrthographicZoomStep)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 / OrthographicZoomStep)
	elif event is InputEventMouseMotion and _fly_camera_active:
		_camera_yaw -= event.relative.x * MouseLookSensitivity
		_camera_pitch -= event.relative.y * MouseLookSensitivity
		_camera_pitch = clampf(_camera_pitch, -1.45, 1.45)
		_apply_fly_camera_rotation()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_fly_camera_active = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _apply_command_line_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--quit-after-screenshot":
			_quit_after_screenshot = true
		elif arg.begins_with("--tilt-file="):
			TiltFilePath = arg.trim_prefix("--tilt-file=")
		elif arg.begins_with("--render-output="):
			RenderOutputPath = arg.trim_prefix("--render-output=")
		elif arg.begins_with("--thumbnail-output="):
			ThumbnailOutputPath = arg.trim_prefix("--thumbnail-output=")
		elif arg.begins_with("--log-output="):
			LogPath = arg.trim_prefix("--log-output=")
		elif arg.begins_with("--load-mode="):
			_set_load_mode(arg.trim_prefix("--load-mode="))
		elif arg == "--runtime-rebuild":
			SceneLoadMode = LOAD_MODE_RUNTIME_REBUILD
		elif arg == "--imported-packed-scene":
			SceneLoadMode = LOAD_MODE_IMPORTED_PACKED_SCENE
		elif arg.begins_with("--camera-mode="):
			CameraMode = arg.trim_prefix("--camera-mode=")
		elif arg.begins_with("--camera-near="):
			CameraNear = maxf(float(arg.trim_prefix("--camera-near=")), 0.0001)
		elif arg == "--no-orbit":
			AutoOrbit = false
		elif arg == "--no-fly-camera":
			EnableFlyCamera = false
		elif arg.begins_with("--only-brushes="):
			OnlyBrushes = PackedStringArray()
			for brush_name in arg.trim_prefix("--only-brushes=").split(",", false):
				OnlyBrushes.append(brush_name.strip_edges())
		elif arg == "--force-double-sided":
			ForceDoubleSided = true
		elif arg == "--no-normalize-hull-materials":
			NormalizeOpaqueHullMaterials = false

func _set_load_mode(value: String) -> void:
	match value:
		"runtime_rebuild":
			SceneLoadMode = LOAD_MODE_RUNTIME_REBUILD
		"imported_packed_scene":
			SceneLoadMode = LOAD_MODE_IMPORTED_PACKED_SCENE
		_:
			_fail("TILT_EVIDENCE: unknown load mode '%s'; expected runtime_rebuild or imported_packed_scene" % value)

func _apply_brush_filter(root: Node) -> void:
	if OnlyBrushes.is_empty():
		return
	_apply_brush_filter_recursive(root)
	_log("TILT_EVIDENCE: brush filter=%s" % ", ".join(OnlyBrushes))

func _apply_brush_filter_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		node.visible = OnlyBrushes.has(node.name)
	for child in node.get_children():
		_apply_brush_filter_recursive(child)

func _force_double_sided(root: Node) -> void:
	_force_double_sided_recursive(root)
	_log("TILT_EVIDENCE: forced StandardMaterial3D cull disabled")

func _force_double_sided_recursive(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		for surface_index in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface_index)
			if material is BaseMaterial3D:
				var copy := material.duplicate()
				copy.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.surface_set_material(surface_index, copy)
	for child in node.get_children():
		_force_double_sided_recursive(child)

func _normalize_opaque_hull_materials(root: Node) -> void:
	var normalized := _normalize_opaque_hull_materials_recursive(root)
	if normalized > 0:
		_log("TILT_EVIDENCE: normalized opaque hull materials=%d" % normalized)

func _normalize_opaque_hull_materials_recursive(node: Node) -> int:
	var normalized := 0
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		for surface_index in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface_index)
			if material == null or not OPAQUE_HULL_MATERIALS.has(material.resource_name):
				continue
			mesh.surface_set_material(surface_index, _opaque_hull_material_from(material))
			normalized += 1
	for child in node.get_children():
		normalized += _normalize_opaque_hull_materials_recursive(child)
	return normalized

func _opaque_hull_material_from(source: Material) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = OPAQUE_HULL_SHADER_CODE
	var material := ShaderMaterial.new()
	material.resource_name = source.resource_name
	material.shader = shader
	if source is ShaderMaterial:
		var color = source.get_shader_parameter("u_Color")
		if color is Color:
			material.set_shader_parameter("u_Color", color)
		var cutoff = source.get_shader_parameter("u_Cutoff")
		if cutoff is float:
			material.set_shader_parameter("u_Cutoff", cutoff)
	return material

func _save_thumbnail(bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		_log("TILT_EVIDENCE: no embedded thumbnail found")
		return
	var file := FileAccess.open(ThumbnailOutputPath, FileAccess.WRITE)
	if file == null:
		_log("TILT_EVIDENCE: failed to save thumbnail to %s error=%d" % [ThumbnailOutputPath, FileAccess.get_open_error()])
		return
	file.store_buffer(bytes)
	file.close()
	_log("TILT_EVIDENCE: saved embedded thumbnail to %s bytes=%d" % [ProjectSettings.globalize_path(ThumbnailOutputPath), bytes.size()])

func _collect_scene_stats(root: Node) -> Dictionary:
	var stats := {
		"mesh_instances": 0,
		"vertices": 0,
		"triangles": 0,
		"materials": PackedStringArray(),
		"bounds": {"valid": false, "min": Vector3.ZERO, "max": Vector3.ZERO},
	}
	_collect_scene_stats_recursive(root, stats)
	return stats

func _collect_scene_stats_recursive(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		if not node.visible:
			return
		stats.mesh_instances += 1
		var mesh: Mesh = node.mesh
		for surface_index in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			stats.vertices += vertices.size()
			stats.triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
			var material := mesh.surface_get_material(surface_index)
			if material != null and not stats.materials.has(material.resource_name):
				stats.materials.append(material.resource_name)
		_expand_bounds(stats.bounds, node)

	for child in node.get_children():
		_collect_scene_stats_recursive(child, stats)

func _expand_bounds(bounds: Dictionary, mesh_instance: MeshInstance3D) -> void:
	var aabb := mesh_instance.get_aabb()
	var corners := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	for corner in corners:
		var point: Vector3 = mesh_instance.global_transform * corner
		if not bounds.valid:
			bounds.valid = true
			bounds.min = point
			bounds.max = point
		else:
			bounds.min = bounds.min.min(point)
			bounds.max = bounds.max.max(point)

func _add_camera(bounds: Dictionary) -> void:
	var min_point: Vector3 = bounds.min
	var max_point: Vector3 = bounds.max
	var center := (min_point + max_point) * 0.5
	var size := max_point - min_point
	var max_span := maxf(maxf(size.x, size.y), size.z)

	var camera := Camera3D.new()
	camera.name = "EvidenceCamera"
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = CameraNear
	var effective_mode := CameraMode
	if effective_mode == "auto":
		effective_mode = "overview" if not OnlyBrushes.is_empty() else "detail"
	var camera_direction := Vector3(0.7, 0.45, 1.0).normalized()
	if effective_mode == "detail":
		_camera_target = Vector3(-7.0, 0.8, -2.0)
		camera.size = 7.0
		_camera_distance = 11.0
		camera_direction = Vector3(0.55, 0.85, 0.8).normalized()
	elif effective_mode == "cafe":
		_camera_target = Vector3(-9.5, 0.5, -1.6)
		camera.size = 10.0
		_camera_distance = 14.0
		camera_direction = Vector3(0.55, 0.9, 0.8).normalized()
	else:
		_camera_target = center
		camera.size = maxf(max_span * 1.2, 1.0)
		_camera_distance = maxf(max_span * 2.0, 2.0)
	camera.position = _camera_target + camera_direction * _camera_distance
	add_child(camera)
	camera.look_at(_camera_target, Vector3.UP)
	_camera = camera
	_capture_camera_angles()

func _has_fly_camera_movement() -> bool:
	return _fly_camera_active \
		or Input.is_key_pressed(KEY_W) \
		or Input.is_key_pressed(KEY_A) \
		or Input.is_key_pressed(KEY_S) \
		or Input.is_key_pressed(KEY_D) \
		or Input.is_key_pressed(KEY_Q) \
		or Input.is_key_pressed(KEY_E) \
		or Input.is_key_pressed(KEY_SPACE) \
		or Input.is_key_pressed(KEY_CTRL)

func _process_fly_camera(delta: float) -> void:
	var basis := _camera.global_transform.basis
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction -= basis.z
	if Input.is_key_pressed(KEY_S):
		direction += basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= basis.x
	if Input.is_key_pressed(KEY_D):
		direction += basis.x
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		direction -= Vector3.UP
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		direction += Vector3.UP
	if direction == Vector3.ZERO:
		return
	var speed := FlyMoveSpeed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= FlyFastMultiplier
	_camera.global_position += direction.normalized() * speed * delta

func _capture_camera_angles() -> void:
	if _camera == null:
		return
	var forward := -_camera.global_transform.basis.z.normalized()
	_camera_pitch = asin(clampf(forward.y, -1.0, 1.0))
	_camera_yaw = atan2(-forward.x, -forward.z)

func _apply_fly_camera_rotation() -> void:
	if _camera == null:
		return
	_camera.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)

func _zoom_camera(factor: float) -> void:
	if _camera == null:
		return
	AutoOrbit = false
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = clampf(_camera.size * factor, 0.05, 200.0)
	else:
		_camera.global_position -= _camera.global_transform.basis.z * FlyMoveSpeed * (1.0 - factor)

func _add_world() -> void:
	var world := WorldEnvironment.new()
	world.name = "EvidenceWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.035, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	environment.ambient_light_energy = 1.2
	world.environment = environment
	add_child(world)

func _save_render() -> void:
	var texture := get_viewport().get_texture()
	if texture == null:
		_fail("TILT_EVIDENCE: viewport texture is null; run with a real display driver for screenshot capture")
		return
	var image := texture.get_image()
	if image == null:
		_fail("TILT_EVIDENCE: viewport image is null; run with a real display driver for screenshot capture")
		return
	var err := image.save_png(RenderOutputPath)
	if err != OK:
		_fail("TILT_EVIDENCE: failed to save render to %s error=%d" % [RenderOutputPath, err])
		return
	var pixel_stats := _count_visible_pixels(image)
	_log("TILT_EVIDENCE: saved render to %s size=%dx%d non_background_pixels=%d" % [
		ProjectSettings.globalize_path(RenderOutputPath),
		image.get_width(),
		image.get_height(),
		pixel_stats.non_background_pixels,
	])

func _count_visible_pixels(image: Image) -> Dictionary:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r > 0.08 or color.g > 0.08 or color.b > 0.08:
				count += 1
	return {"non_background_pixels": count}

func _log(message: String) -> void:
	var file := FileAccess.open(LogPath, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LogPath, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(message)
	file.close()

func _reset_log() -> void:
	var file := FileAccess.open(LogPath, FileAccess.WRITE)
	if file != null:
		file.close()

func _fail(message: String) -> void:
	_log(message)
	push_error(message)
	if _quit_after_screenshot:
		get_tree().quit(1)
