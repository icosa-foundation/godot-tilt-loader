class_name BrushMaterialResolver
extends RefCounted

const ICOSA_OPEN_BRUSH_PATH := "res://addons/icosa/open_brush/open_brush.gd"
const SOURCE_LIVE_RUNTIME := "LIVE_RUNTIME"
const SOURCE_GLTF_LEGACY_OPEN_BRUSH := "GLTF_LEGACY_OPEN_BRUSH"
const SOURCE_GLTF_NEW_UNITYGLTF := "GLTF_NEW_UNITYGLTF"
const LIVE_DEPTH_MODE_OPAQUE := "opaque"

static var _open_brush
static var _material_cache := {}

static func clear_cache() -> void:
	_material_cache.clear()

static func find_material(desc: BrushDescriptor) -> Material:
	return find_material_for_descriptor(desc, SOURCE_LIVE_RUNTIME)

static func find_material_for_descriptor(desc: BrushDescriptor, source_mode: String = SOURCE_LIVE_RUNTIME) -> Material:
	if desc == null:
		return null

	var brush_key := desc.m_Guid.strip_edges()
	if brush_key.is_empty():
		brush_key = desc.m_DurableName
	var cache_key := "%s:%s" % [source_mode, brush_key]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]

	var open_brush: Variant = _get_open_brush()
	if open_brush == null:
		_material_cache[cache_key] = null
		return null

	open_brush.ensure_loaded()
	var desc_guid := desc.m_Guid.strip_edges()
	if desc_guid.is_empty() and not _has_known_material(open_brush, desc.m_DurableName):
		_material_cache[cache_key] = null
		return null
	var brush_name: String = desc.m_DurableName if desc_guid.is_empty() else open_brush.resolve_brush_name(desc_guid)
	if brush_name == desc_guid and not _has_known_material(open_brush, desc.m_DurableName):
		_material_cache[cache_key] = null
		return null
	if brush_name == desc_guid and _has_known_material(open_brush, desc.m_DurableName):
		brush_name = desc.m_DurableName

	var material: Material = open_brush.find_matching_brush_material(brush_name)
	if material == null and brush_name != desc.m_DurableName and _has_known_material(open_brush, desc.m_DurableName):
		material = open_brush.find_matching_brush_material(desc.m_DurableName)
	if material != null:
		material = _prepare_material(material, desc, source_mode)
		_apply_generated_geometry_render_state(material, desc, source_mode)

	_material_cache[cache_key] = material
	return material

static func find_material_for_guid(guid: String, source_mode: String = SOURCE_LIVE_RUNTIME) -> Material:
	var open_brush: Variant = _get_open_brush()
	if open_brush == null:
		return null
	open_brush.ensure_loaded()
	var brush_name: String = open_brush.resolve_brush_name(guid)
	return find_material_for_name(brush_name, source_mode)

static func find_material_for_name(brush_name: String, source_mode: String = SOURCE_LIVE_RUNTIME) -> Material:
	if brush_name.is_empty():
		return null
	var cache_key := "%s:name:%s" % [source_mode, brush_name.to_lower()]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var open_brush: Variant = _get_open_brush()
	if open_brush == null:
		_material_cache[cache_key] = null
		return null
	open_brush.ensure_loaded()
	var material: Material = open_brush.find_matching_brush_material(brush_name)
	if material != null:
		material = _prepare_material(material, null, source_mode)
	_material_cache[cache_key] = material
	return material

static func _get_open_brush() -> Variant:
	if _open_brush != null:
		return _open_brush
	var script: Resource = load(ICOSA_OPEN_BRUSH_PATH)
	if script == null:
		push_warning("BrushMaterialResolver: missing Icosa Open Brush helper at %s" % ICOSA_OPEN_BRUSH_PATH)
		return null
	_open_brush = script.new()
	return _open_brush

static func _has_known_material(open_brush: Variant, material_name: String) -> bool:
	if material_name.is_empty():
		return false
	if open_brush.brush_materials.has(material_name):
		return true
	var lower := material_name.to_lower()
	for brush_name in open_brush.brush_materials.keys():
		if String(brush_name).to_lower() == lower:
			return true
	return false

static func _prepare_material(source: Material, desc: BrushDescriptor, source_mode: String) -> Material:
	var material: Material = source.duplicate()
	if material is ShaderMaterial:
		if source_mode == SOURCE_LIVE_RUNTIME:
			_apply_particle_rotation_channel(material as ShaderMaterial, desc)
		_apply_mesh_source_params(material as ShaderMaterial, source_mode)
		_apply_default_light_params(material as ShaderMaterial)
	return material

static func _apply_particle_rotation_channel(material: ShaderMaterial, desc: BrushDescriptor) -> void:
	if desc == null or String(desc.prefab_fields.get("prefab_name", "")) != "GeniusParticle":
		return
	var source_shader := material.shader
	if source_shader == null:
		return
	var code := source_shader.code
	if not code.contains("TANGENT.z"):
		return
	# ArrayMesh normalizes tangent vectors, so generated particle rotation must use a non-tangent channel.
	var shader := Shader.new()
	shader.code = code.replace("TANGENT.z", "UV2.y")
	material.shader = shader

static func _apply_generated_geometry_render_state(material: Material, desc: BrushDescriptor, source_mode: String) -> void:
	if desc == null:
		return
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
	elif material is ShaderMaterial:
		var desired_cull := _desired_generated_shader_cull(material as ShaderMaterial, desc)
		if source_mode == SOURCE_LIVE_RUNTIME and _uses_open_brush_opaque_live_render_state(desc):
			_apply_live_opaque_shader_render_state(material as ShaderMaterial, desired_cull)
		else:
			_apply_shader_cull_mode(material as ShaderMaterial, desired_cull)

static func _uses_open_brush_opaque_live_render_state(desc: BrushDescriptor) -> bool:
	return desc != null and String(desc.godot_runtime_material.get("live_depth_mode", "")) == LIVE_DEPTH_MODE_OPAQUE

static func _desired_generated_shader_cull(material: ShaderMaterial, desc: BrushDescriptor) -> String:
	var source_cull := _first_shader_render_mode_cull(material)
	if not source_cull.is_empty():
		return source_cull
	return "cull_disabled" if desc != null and desc.m_RenderBackfaces else "cull_back"

static func _first_shader_render_mode_cull(material: ShaderMaterial) -> String:
	var shader := material.shader
	if shader == null:
		return ""
	for line in shader.code.split("\n"):
		var trimmed := String(line).strip_edges()
		if not trimmed.begins_with("render_mode"):
			continue
		var body := trimmed.trim_prefix("render_mode").strip_edges()
		if body.ends_with(";"):
			body = body.trim_suffix(";").strip_edges()
		for raw_mode in body.split(","):
			var mode := String(raw_mode).strip_edges()
			if mode.begins_with("cull_"):
				return mode
		return ""
	return ""

static func _apply_shader_cull_mode(material: ShaderMaterial, desired_cull: String) -> void:
	var source_shader := material.shader
	if source_shader == null:
		return
	var source_code := source_shader.code
	var rewritten := _rewrite_render_mode_cull(source_code, desired_cull)
	if rewritten == source_code:
		return
	var shader := Shader.new()
	shader.code = rewritten
	material.shader = shader

static func _apply_live_opaque_shader_render_state(material: ShaderMaterial, desired_cull: String) -> void:
	var source_shader := material.shader
	if source_shader == null:
		return
	var source_code := source_shader.code
	var rewritten := _rewrite_live_opaque_shader_render_state(source_code, desired_cull)
	if rewritten == source_code:
		return
	var shader := Shader.new()
	shader.code = rewritten
	material.shader = shader

static func _rewrite_live_opaque_shader_render_state(source_code: String, desired_cull: String) -> String:
	var lines := source_code.split("\n")
	var found_render_mode := false
	var output: Array[String] = []
	for raw_line in lines:
		var line := String(raw_line)
		var trimmed := line.strip_edges()
		if trimmed.begins_with("render_mode"):
			found_render_mode = true
			output.append(_rewrite_render_mode_for_live_opaque(line, desired_cull))
			continue
		if trimmed.begins_with("ALPHA") and trimmed.ends_with(";"):
			continue
		output.append(line)
	if not found_render_mode:
		output.insert(1, "render_mode depth_draw_opaque, %s;" % desired_cull)
	return "\n".join(output)

static func _rewrite_render_mode_for_live_opaque(line: String, desired_cull: String) -> String:
	var trimmed := line.strip_edges()
	var indent := line.substr(0, line.find("render_mode")) if line.find("render_mode") >= 0 else ""
	var has_semicolon := trimmed.ends_with(";")
	var body := trimmed.trim_prefix("render_mode").strip_edges()
	if has_semicolon:
		body = body.trim_suffix(";").strip_edges()
	var modes: Array[String] = []
	for raw_mode in body.split(","):
		var mode := String(raw_mode).strip_edges()
		if mode.is_empty():
			continue
		if mode.begins_with("blend_") or mode.begins_with("cull_") or mode.begins_with("depth_draw_"):
			continue
		modes.append(mode)
	modes.append("depth_draw_opaque")
	modes.append(desired_cull)
	return "%srender_mode %s%s" % [
		indent,
		", ".join(modes),
		";" if has_semicolon else "",
	]

static func _rewrite_render_mode_cull(source_code: String, desired_cull: String) -> String:
	var lines := source_code.split("\n")
	for index in range(lines.size()):
		var line := String(lines[index])
		var trimmed := line.strip_edges()
		if not trimmed.begins_with("render_mode"):
			continue
		var indent := line.substr(0, line.find("render_mode")) if line.find("render_mode") >= 0 else ""
		var has_semicolon := trimmed.ends_with(";")
		var body := trimmed.trim_prefix("render_mode").strip_edges()
		if has_semicolon:
			body = body.trim_suffix(";").strip_edges()
		var modes: Array[String] = []
		for raw_mode in body.split(","):
			var mode := String(raw_mode).strip_edges()
			if mode.is_empty():
				continue
			if mode.begins_with("cull_"):
				continue
			modes.append(mode)
		modes.append(desired_cull)
		lines[index] = "%srender_mode %s%s" % [
			indent,
			", ".join(modes),
			";" if has_semicolon else "",
		]
		return "\n".join(lines)
	return source_code

static func _apply_mesh_source_params(material: ShaderMaterial, source_mode: String) -> void:
	var shader: Shader = material.shader
	if shader == null:
		return
	var param_names: Array = RenderingServer.get_shader_parameter_list(shader.get_rid()).map(
		func(param): return param["name"])

	if "u_IsLiveRuntime" in param_names:
		material.set_shader_parameter("u_IsLiveRuntime", source_mode == SOURCE_LIVE_RUNTIME)
	if "u_IsGltfImported" in param_names:
		material.set_shader_parameter("u_IsGltfImported", source_mode != SOURCE_LIVE_RUNTIME)
	if "u_IsLegacyOpenBrushGltf" in param_names:
		material.set_shader_parameter("u_IsLegacyOpenBrushGltf", source_mode == SOURCE_GLTF_LEGACY_OPEN_BRUSH)
	if "u_IsNewUnityGltf" in param_names:
		material.set_shader_parameter("u_IsNewUnityGltf", source_mode == SOURCE_GLTF_NEW_UNITYGLTF)

static func _apply_default_light_params(material: ShaderMaterial) -> void:
	var shader: Shader = material.shader
	if shader == null:
		return
	var param_names: Array = RenderingServer.get_shader_parameter_list(shader.get_rid()).map(
		func(param): return param["name"])

	if "u_SceneLight_0_direction" in param_names:
		material.set_shader_parameter("u_SceneLight_0_direction", Vector3(0.0, -0.707, 0.707))
	if "u_SceneLight_0_color" in param_names:
		material.set_shader_parameter("u_SceneLight_0_color", Color(1.0, 0.99, 0.95, 1.0))
	if "u_SceneLight_1_direction" in param_names:
		material.set_shader_parameter("u_SceneLight_1_direction", Vector3(0.0, 0.5, -0.866))
	if "u_SceneLight_1_color" in param_names:
		material.set_shader_parameter("u_SceneLight_1_color", Color(0.35, 0.4, 0.55, 1.0))
	if "u_ambient_light_color" in param_names:
		material.set_shader_parameter("u_ambient_light_color", Color(1.0, 1.0, 1.0, 1.0))
