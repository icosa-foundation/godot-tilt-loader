class_name SingleBrushStrokeInspector
extends Node3D

@export var CanvasPath: NodePath
@export var BrushSystemPath: NodePath
@export var LabelPath: NodePath
@export var CameraPath: NodePath
@export var LightPath: NodePath
@export var StrokeColor := Color(0.2, 0.5, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var BrushSize01 := 0.5
@export var StrokeScale := 1.0
@export var StrokeRadius := 4.0
@export var StrokeSegments := 72
@export var SyntheticStrokeAgeSeconds := 2.0
@export var AmbientLightColor := Color(0.35, 0.35, 0.35, 1.0)
@export var BrushNameFilter: PackedStringArray = []
@export var WireframeKey := KEY_F
@export var RotateLeftKey := KEY_Q
@export var RotateRightKey := KEY_E
@export var ResetRotationKey := KEY_R
@export var CullDebugKey := KEY_C
@export var RotationSpeedDegreesPerSecond := 90.0

enum CullDebugMode {
	SHADER,
	FRONT_BACK_CULLED,
	FRONT_BACK_ALL,
	CULL_BACK,
	CULL_FRONT,
	CULL_DISABLED,
	CAPS_ONLY,
}

var Canvas: MinimalExample
var BrushSystem: BrushSystemSetup
var BrushLabel: Label
var Camera: Camera3D
var MainLight: DirectionalLight3D
var _brushes: Array[BrushDescriptor] = []
var _current_index := 0
var _left_was_pressed := false
var _right_was_pressed := false
var _wireframe_was_pressed := false
var _reset_rotation_was_pressed := false
var _cull_debug_was_pressed := false
var _wireframe_enabled := false
var _cull_debug_mode := CullDebugMode.SHADER
var _stroke_yaw_degrees := 0.0
var _wireframe_material: ShaderMaterial
var _front_back_culled_material: ShaderMaterial
var _front_back_all_material: ShaderMaterial
var _cull_back_material: StandardMaterial3D
var _cull_front_material: StandardMaterial3D
var _cull_disabled_material: StandardMaterial3D
var _caps_only_material: ShaderMaterial

func _ready() -> void:
	BrushMaterialResolver.clear_cache()
	_wireframe_material = _create_wireframe_material()
	_front_back_culled_material = _create_front_back_material("cull_back")
	_front_back_all_material = _create_front_back_material("cull_disabled")
	_cull_back_material = _create_cull_debug_material(BaseMaterial3D.CULL_BACK, Color(0.15, 0.75, 1.0, 1.0))
	_cull_front_material = _create_cull_debug_material(BaseMaterial3D.CULL_FRONT, Color(1.0, 0.35, 0.15, 1.0))
	_cull_disabled_material = _create_cull_debug_material(BaseMaterial3D.CULL_DISABLED, Color(0.9, 0.9, 0.9, 1.0))
	_caps_only_material = _create_caps_only_material()
	if not CanvasPath.is_empty():
		Canvas = get_node_or_null(CanvasPath) as MinimalExample
	if not BrushSystemPath.is_empty():
		BrushSystem = get_node_or_null(BrushSystemPath) as BrushSystemSetup
	if not LabelPath.is_empty():
		BrushLabel = get_node_or_null(LabelPath) as Label
	if not CameraPath.is_empty():
		Camera = get_node_or_null(CameraPath) as Camera3D
	if not LightPath.is_empty():
		MainLight = get_node_or_null(LightPath) as DirectionalLight3D
	_load_brushes()
	_select_initial_brush()
	_show_current_brush()

func _process(delta: float) -> void:
	var left_pressed := Input.is_physical_key_pressed(KEY_LEFT)
	var right_pressed := Input.is_physical_key_pressed(KEY_RIGHT)
	var wireframe_pressed := Input.is_physical_key_pressed(WireframeKey)
	var reset_rotation_pressed := Input.is_physical_key_pressed(ResetRotationKey)
	var cull_debug_pressed := Input.is_physical_key_pressed(CullDebugKey)
	if left_pressed and not _left_was_pressed:
		step_brush(-1)
	if right_pressed and not _right_was_pressed:
		step_brush(1)
	if wireframe_pressed and not _wireframe_was_pressed:
		_wireframe_enabled = not _wireframe_enabled
		_apply_wireframe_overlay()
		_update_label()
	if reset_rotation_pressed and not _reset_rotation_was_pressed:
		_stroke_yaw_degrees = 0.0
		_apply_stroke_rotation()
		_update_label()
	if cull_debug_pressed and not _cull_debug_was_pressed:
		_cull_debug_mode = (_cull_debug_mode + 1) % CullDebugMode.size()
		_apply_cull_debug_material()
		_update_label()
	var yaw_delta := 0.0
	if Input.is_physical_key_pressed(RotateLeftKey):
		yaw_delta -= RotationSpeedDegreesPerSecond * delta
	if Input.is_physical_key_pressed(RotateRightKey):
		yaw_delta += RotationSpeedDegreesPerSecond * delta
	if not is_zero_approx(yaw_delta):
		_stroke_yaw_degrees = wrapf(_stroke_yaw_degrees + yaw_delta, -180.0, 180.0)
		_apply_stroke_rotation()
		_update_label()
	_left_was_pressed = left_pressed
	_right_was_pressed = right_pressed
	_wireframe_was_pressed = wireframe_pressed
	_reset_rotation_was_pressed = reset_rotation_pressed
	_cull_debug_was_pressed = cull_debug_pressed

func step_brush(direction: int) -> void:
	if _brushes.is_empty():
		return
	_current_index = (_current_index + direction + _brushes.size()) % _brushes.size()
	_show_current_brush()

func _load_brushes() -> void:
	_brushes.clear()
	if BrushSystem != null and BrushSystem.manifest != null:
		for brush in BrushSystem.manifest.Brushes:
			if brush != null and not BrushRuntimeRegistry.is_compatibility_brush(BrushSystem.manifest, brush):
				_brushes.append(brush)
	else:
		_brushes = BrushCatalog.all_brushes()
	_brushes = _brushes.filter(func(brush: BrushDescriptor) -> bool:
		return brush != null and BrushRuntimeRegistry.is_supported(brush)
	)
	if not BrushNameFilter.is_empty():
		var by_name := {}
		for brush in _brushes:
			by_name[brush.m_DurableName] = brush
		var filtered: Array[BrushDescriptor] = []
		for brush_name in BrushNameFilter:
			var brush: BrushDescriptor = by_name.get(String(brush_name))
			if brush != null:
				filtered.append(brush)
		_brushes = filtered

func _select_initial_brush() -> void:
	if _brushes.is_empty():
		return
	if not BrushNameFilter.is_empty():
		_current_index = 0
		return
	for index in range(_brushes.size()):
		if _brushes[index].m_DurableName == "Ink":
			_current_index = index
			return
	_current_index = 0

func _show_current_brush() -> void:
	if Canvas == null:
		_set_label_text("No canvas")
		return
	if _brushes.is_empty():
		_set_label_text("No runtime brushes")
		return
	var brush := _brushes[_current_index]
	_clear_generated_stroke()
	Canvas.draw_stroke(
		_make_sample_path(),
		brush,
		StrokeColor,
		_brush_size_from_descriptor(brush),
		-int(SyntheticStrokeAgeSeconds * 1000.0)
	)
	_apply_stroke_rotation()
	_apply_scene_light_uniforms()
	_apply_cull_debug_material()
	_apply_wireframe_overlay()
	_update_label()
	_log_render_audit(brush)

func _update_label() -> void:
	if _brushes.is_empty():
		return
	var brush := _brushes[_current_index]
	var wireframe_suffix := "  WIREFRAME" if _wireframe_enabled else ""
	var cull_suffix := ""
	match _cull_debug_mode:
		CullDebugMode.FRONT_BACK_CULLED:
			cull_suffix = "  FRONT_GREEN/BACK_RED_CULLED"
		CullDebugMode.FRONT_BACK_ALL:
			cull_suffix = "  FRONT_GREEN/BACK_RED_ALL"
		CullDebugMode.CULL_BACK:
			cull_suffix = "  CULL_BACK"
		CullDebugMode.CULL_FRONT:
			cull_suffix = "  CULL_FRONT"
		CullDebugMode.CULL_DISABLED:
			cull_suffix = "  CULL_DISABLED"
		CullDebugMode.CAPS_ONLY:
			cull_suffix = "  CAPS_ONLY"
	_set_label_text("%03d / %03d  %s  %s  yaw %.0f%s%s" % [
		_current_index + 1,
		_brushes.size(),
		brush.m_DurableName,
		_prefab_name(brush),
		_stroke_yaw_degrees,
		wireframe_suffix,
		cull_suffix,
	])

func _apply_stroke_rotation() -> void:
	if Canvas == null or Canvas.m_Canvas == null:
		return
	Canvas.m_Canvas.rotation = Vector3(0.0, deg_to_rad(_stroke_yaw_degrees), 0.0)

func _apply_scene_light_uniforms() -> void:
	if Canvas == null or Canvas.m_Canvas == null:
		return
	var camera := Camera
	if camera == null:
		var viewport := get_viewport()
		if viewport != null:
			camera = viewport.get_camera_3d()
	var light := MainLight
	if light == null and is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			light = _find_first_directional_light(tree.root)
	if camera == null or light == null:
		return
	var world_light_dir := (-light.global_transform.basis.z).normalized()
	var view_light_dir := (camera.global_transform.basis.inverse() * world_light_dir).normalized()
	var light_color := light.light_color * light.light_energy
	_apply_scene_light_uniforms_recursive(Canvas.m_Canvas, view_light_dir, light_color)

func _apply_scene_light_uniforms_recursive(node: Node, view_light_dir: Vector3, light_color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh != null:
			for surface in range(mesh.get_surface_count()):
				_apply_scene_light_to_material(mesh.surface_get_material(surface), view_light_dir, light_color)
	for child in node.get_children():
		_apply_scene_light_uniforms_recursive(child, view_light_dir, light_color)

func _apply_scene_light_to_material(material: Material, view_light_dir: Vector3, light_color: Color) -> void:
	if not material is ShaderMaterial:
		return
	var shader_material := material as ShaderMaterial
	var shader := shader_material.shader
	if shader == null:
		return
	var param_names: Array = RenderingServer.get_shader_parameter_list(shader.get_rid()).map(
		func(param): return param["name"])
	if "u_SceneLight_0_direction" in param_names:
		shader_material.set_shader_parameter("u_SceneLight_0_direction", view_light_dir)
	if "u_SceneLight_0_color" in param_names:
		shader_material.set_shader_parameter("u_SceneLight_0_color", light_color)
	if "u_SceneLight_1_direction" in param_names:
		shader_material.set_shader_parameter("u_SceneLight_1_direction", Vector3(-view_light_dir.x, -view_light_dir.y, view_light_dir.z).normalized())
	if "u_SceneLight_1_color" in param_names:
		shader_material.set_shader_parameter("u_SceneLight_1_color", Color(0.25, 0.28, 0.35, 1.0))
	if "u_ambient_light_color" in param_names:
		shader_material.set_shader_parameter("u_ambient_light_color", AmbientLightColor)

func _find_first_directional_light(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D and node.visible:
		return node as DirectionalLight3D
	for child in node.get_children():
		var found := _find_first_directional_light(child)
		if found != null:
			return found
	return null

func _apply_wireframe_overlay() -> void:
	if Canvas == null or Canvas.m_Canvas == null:
		return
	_apply_wireframe_overlay_recursive(Canvas.m_Canvas)

func _apply_wireframe_overlay_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_overlay = _wireframe_material if _wireframe_enabled else null
	for child in node.get_children():
		_apply_wireframe_overlay_recursive(child)

func _apply_cull_debug_material() -> void:
	if Canvas == null or Canvas.m_Canvas == null:
		return
	_apply_cull_debug_material_recursive(Canvas.m_Canvas)

func _apply_cull_debug_material_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		match _cull_debug_mode:
			CullDebugMode.FRONT_BACK_CULLED:
				mesh_instance.material_override = _front_back_culled_material
			CullDebugMode.FRONT_BACK_ALL:
				mesh_instance.material_override = _front_back_all_material
			CullDebugMode.CULL_BACK:
				mesh_instance.material_override = _cull_back_material
			CullDebugMode.CULL_FRONT:
				mesh_instance.material_override = _cull_front_material
			CullDebugMode.CULL_DISABLED:
				mesh_instance.material_override = _cull_disabled_material
			CullDebugMode.CAPS_ONLY:
				mesh_instance.material_override = _caps_only_material
			_:
				mesh_instance.material_override = null
	for child in node.get_children():
		_apply_cull_debug_material_recursive(child)

func _create_cull_debug_material(cull_mode: BaseMaterial3D.CullMode, albedo: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.cull_mode = cull_mode
	material.albedo_color = albedo
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.5
	return material

func _create_caps_only_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

varying float v_Radius;

void vertex() {
	v_Radius = CUSTOM0.z;
}

void fragment() {
	if (abs(v_Radius) > 0.000001) {
		discard;
	}
	ALBEDO = vec3(1.0, 0.0, 0.85);
	ALPHA = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _create_front_back_material(cull_mode: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, %s, depth_draw_opaque;

void fragment() {
	if (FRONT_FACING) {
		ALBEDO = vec3(0.0, 0.85, 0.15);
	} else {
		ALBEDO = vec3(1.0, 0.05, 0.0);
	}
	ALPHA = 1.0;
}
""" % cull_mode
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _log_render_audit(brush: BrushDescriptor) -> void:
	if Canvas == null or Canvas.m_Canvas == null or brush == null:
		return
	var file := FileAccess.open("user://debug.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://debug.log", FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	var prefix := "TUBE_RENDER_AUDIT_20260625"
	file.store_line("%s brush=%s prefab=%s render_backfaces=%s cull_debug=%s" % [
		prefix,
		brush.m_DurableName,
		_prefab_name(brush),
		str(brush.m_RenderBackfaces),
		CullDebugMode.keys()[_cull_debug_mode],
	])
	_log_render_audit_recursive(file, Canvas.m_Canvas, prefix)
	file.close()

func _log_render_audit_recursive(file: FileAccess, node: Node, prefix: String) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		var surface_count := mesh.get_surface_count() if mesh != null else 0
		file.store_line("%s mesh_instance=%s surfaces=%d override=%s overlay=%s" % [
			prefix,
			mesh_instance.name,
			surface_count,
			_material_summary(mesh_instance.material_override),
			_material_summary(mesh_instance.material_overlay),
		])
		if mesh != null:
			for surface in range(surface_count):
				file.store_line("%s surface=%d material=%s" % [
					prefix,
					surface,
					_material_summary(mesh.surface_get_material(surface)),
				])
	for child in node.get_children():
		_log_render_audit_recursive(file, child, prefix)

func _material_summary(material: Material) -> String:
	if material == null:
		return "<null>"
	if material is StandardMaterial3D:
		return "StandardMaterial3D cull=%s name=%s" % [
			str((material as StandardMaterial3D).cull_mode),
			material.resource_name,
		]
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		var shader := shader_material.shader
		var code := shader.code if shader != null else ""
		return "ShaderMaterial name=%s shader=%s render=%s textures=%s" % [
			material.resource_name,
			shader.resource_path if shader != null else "<null>",
			_first_render_mode_line(code),
			_shader_texture_params(shader_material),
		]
	return "%s name=%s" % [material.get_class(), material.resource_name]

func _first_render_mode_line(code: String) -> String:
	for line in code.split("\n"):
		var trimmed := String(line).strip_edges()
		if trimmed.begins_with("render_mode"):
			return trimmed
	return "<no render_mode>"

func _shader_texture_params(material: ShaderMaterial) -> String:
	var shader := material.shader
	if shader == null:
		return "[]"
	var names: Array[String] = []
	for param in RenderingServer.get_shader_parameter_list(shader.get_rid()):
		var name := String(param["name"])
		if material.get_shader_parameter(name) is Texture2D:
			names.append(name)
	return str(names)

func _create_wireframe_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, wireframe, cull_disabled, depth_draw_always;

uniform vec4 u_WireColor : source_color = vec4(0.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = u_WireColor.rgb;
	ALPHA = u_WireColor.a;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("u_WireColor", Color(0.0, 1.0, 1.0, 1.0))
	return material

func _clear_generated_stroke() -> void:
	if Canvas == null or Canvas.m_Canvas == null:
		return
	for index in range(Canvas.m_Canvas.get_child_count() - 1, -1, -1):
		Canvas.m_Canvas.get_child(index).free()

func _make_sample_path() -> Array[TrTransform]:
	var path: Array[TrTransform] = []
	var segments := maxi(StrokeSegments, 2)
	for index in range(segments):
		var t := float(index) / float(segments - 1)
		var x := lerpf(-StrokeRadius, StrokeRadius, t)
		var y := sin(t * TAU * 1.25) * StrokeRadius * 0.35
		var z := cos(t * TAU * 0.75) * StrokeRadius * 0.16
		var position := Vector3(x, y, z)
		var next_t := minf(1.0, t + 1.0 / float(segments - 1))
		var next_position := Vector3(
			lerpf(-StrokeRadius, StrokeRadius, next_t),
			sin(next_t * TAU * 1.25) * StrokeRadius * 0.35,
			cos(next_t * TAU * 0.75) * StrokeRadius * 0.16
		)
		var tangent := (next_position - position).normalized()
		var orientation := _orientation_facing_viewpoint(tangent)
		path.append(TrTransform.trs(position, orientation, StrokeScale))
	return path

func _orientation_facing_viewpoint(tangent: Vector3) -> Quaternion:
	var safe_tangent := tangent.normalized() if tangent.length() > 0.0001 else Vector3.RIGHT
	var pointer_forward := Vector3.BACK
	var pointer_up := safe_tangent - pointer_forward * safe_tangent.dot(pointer_forward)
	if pointer_up.length() < 0.0001:
		pointer_up = Vector3.UP
	pointer_up = pointer_up.normalized()
	var pointer_right := pointer_up.cross(pointer_forward).normalized()
	return Basis(pointer_right, pointer_up, pointer_forward).orthonormalized().get_rotation_quaternion()

func _brush_size_from_descriptor(brush: BrushDescriptor) -> float:
	if brush != null and brush.m_BrushSizeRange.x > 0.0 and brush.m_BrushSizeRange.y >= brush.m_BrushSizeRange.x:
		var min_radius := sqrt(brush.m_BrushSizeRange.x)
		var max_radius := sqrt(brush.m_BrushSizeRange.y)
		var radius := lerpf(min_radius, max_radius, clampf(BrushSize01, 0.0, 1.0))
		return radius * radius
	return 1.0

func _set_label_text(text: String) -> void:
	if BrushLabel != null:
		BrushLabel.text = text

func _prefab_name(brush: BrushDescriptor) -> String:
	if brush == null or brush.prefab_fields == null:
		return ""
	return String(brush.prefab_fields.get("prefab_name", ""))
