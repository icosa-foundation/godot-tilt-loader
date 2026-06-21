extends SceneTree

const DEFAULT_TILT_PATH := "C:/Users/andyb/Documents/Open Brush/Sketches/allbrushes.tilt"
const OUTPUT_IMAGE := "user://tilt_file_render_validation.png"
const OUTPUT_LOG := "user://tilt_file_render_validation.log"
const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"

var _log_file: FileAccess

func _init() -> void:
	_log_file = FileAccess.open(OUTPUT_LOG, FileAccess.WRITE)
	var tilt_path := _tilt_path_from_args()
	_log("TILT_RENDER_VALIDATION: tilt_path=%s" % tilt_path)

	var reader_script := load(TILT_READER_PATH)
	if reader_script == null:
		_fail("TILT_RENDER_VALIDATION: missing tilt reader at %s" % TILT_READER_PATH)
		return

	var tilt_data: Dictionary = reader_script.new().load_tilt(tilt_path)
	var error := String(tilt_data.get("error", ""))
	if not error.is_empty():
		_fail("TILT_RENDER_VALIDATION: reader error: %s" % error)
		return

	var strokes: Array = tilt_data.get("strokes", [])
	if strokes.is_empty():
		_fail("TILT_RENDER_VALIDATION: reader returned no strokes")
		return

	var root := Node3D.new()
	root.name = "TiltFileRenderValidation"
	get_root().add_child(root)

	var bounds := _stroke_bounds(strokes)
	if not bounds.valid:
		_fail("TILT_RENDER_VALIDATION: no renderable control point bounds")
		return

	var line_mesh := _build_line_mesh(strokes)
	if line_mesh.get_surface_count() == 0:
		_fail("TILT_RENDER_VALIDATION: no line geometry generated")
		return

	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.vertex_color_use_as_albedo = true
	line_material.no_depth_test = false

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TiltStrokeLines"
	mesh_instance.mesh = line_mesh
	mesh_instance.material_override = line_material
	root.add_child(mesh_instance)

	var camera := Camera3D.new()
	camera.name = "ValidationCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	_position_camera(camera, bounds)
	root.add_child(camera)

	var light := DirectionalLight3D.new()
	light.name = "ValidationLight"
	light.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	root.add_child(light)

	get_root().size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	await process_frame

	var image := get_root().get_texture().get_image()
	var output_path := ProjectSettings.globalize_path(OUTPUT_IMAGE)
	var save_error := image.save_png(output_path)
	if save_error != OK:
		_fail("TILT_RENDER_VALIDATION: failed to save screenshot %s error=%d" % [output_path, save_error])
		return

	var colored_pixels := _count_colored_pixels(image)
	_log("TILT_RENDER_VALIDATION: strokes=%d" % strokes.size())
	_log("TILT_RENDER_VALIDATION: line_segments=%d" % _count_line_segments(strokes))
	_log("TILT_RENDER_VALIDATION: bounds_min=%s bounds_max=%s" % [bounds.min, bounds.max])
	_log("TILT_RENDER_VALIDATION: screenshot=%s" % output_path)
	_log("TILT_RENDER_VALIDATION: colored_pixels=%d" % colored_pixels)
	if colored_pixels < 100:
		_fail("TILT_RENDER_VALIDATION: screenshot has too few colored stroke pixels")
		return

	_log("TILT_RENDER_VALIDATION: rendered tilt file successfully")
	if _has_arg("--hold"):
		_log("TILT_RENDER_VALIDATION: holding window open")
		_close_log()
		return
	_close_log()
	quit(0)

func _tilt_path_from_args() -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == "--tilt" and index + 1 < args.size():
			return args[index + 1]
	return DEFAULT_TILT_PATH

func _has_arg(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)

func _build_line_mesh(strokes: Array) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for stroke_data in strokes:
		if not stroke_data is Dictionary:
			continue
		var control_points: Array = stroke_data.get("control_points", [])
		if control_points.size() < 2:
			continue
		var color: Color = stroke_data.get("color", Color.WHITE)
		mesh.surface_set_color(color)
		for index in range(control_points.size() - 1):
			var a = control_points[index]
			var b = control_points[index + 1]
			if a is Dictionary and b is Dictionary:
				mesh.surface_add_vertex(a.get("position", Vector3.ZERO))
				mesh.surface_add_vertex(b.get("position", Vector3.ZERO))
	mesh.surface_end()
	return mesh

func _stroke_bounds(strokes: Array) -> Dictionary:
	var valid := false
	var min_point := Vector3.ZERO
	var max_point := Vector3.ZERO
	for stroke_data in strokes:
		if not stroke_data is Dictionary:
			continue
		for point_data in stroke_data.get("control_points", []):
			if not point_data is Dictionary:
				continue
			var position: Vector3 = point_data.get("position", Vector3.ZERO)
			if not valid:
				min_point = position
				max_point = position
				valid = true
			else:
				min_point = min_point.min(position)
				max_point = max_point.max(position)
	return {"valid": valid, "min": min_point, "max": max_point}

func _position_camera(camera: Camera3D, bounds: Dictionary) -> void:
	var min_point: Vector3 = bounds.min
	var max_point: Vector3 = bounds.max
	var center := (min_point + max_point) * 0.5
	var size := max_point - min_point
	var max_span := maxf(maxf(size.x, size.y), size.z)
	camera.size = maxf(max_span * 1.25, 1.0)
	var view_axis := Vector3.FORWARD
	var up_axis := Vector3.UP
	if size.y <= size.x and size.y <= size.z:
		view_axis = Vector3.UP
		up_axis = Vector3.FORWARD
	elif size.x <= size.y and size.x <= size.z:
		view_axis = Vector3.RIGHT
		up_axis = Vector3.UP
	camera.look_at_from_position(center + view_axis * (max_span * 2.0 + 5.0), center, up_axis)

func _count_line_segments(strokes: Array) -> int:
	var count := 0
	for stroke_data in strokes:
		if stroke_data is Dictionary:
			count += maxi(0, stroke_data.get("control_points", []).size() - 1)
	return count

func _count_colored_pixels(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			var max_channel := maxf(maxf(pixel.r, pixel.g), pixel.b)
			var min_channel := minf(minf(pixel.r, pixel.g), pixel.b)
			if max_channel - min_channel > 0.05:
				count += 1
	return count

func _log(message: String) -> void:
	print(message)
	if _log_file != null:
		_log_file.store_line(message)
		_log_file.flush()

func _fail(message: String) -> void:
	_log(message)
	_close_log()
	push_error(message)
	quit(1)

func _close_log() -> void:
	if _log_file != null:
		_log_file.close()
		_log_file = null
