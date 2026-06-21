class_name BrushMaterialResolver
extends RefCounted

const ICOSA_OPEN_BRUSH_PATH := "res://addons/icosa/open_brush/open_brush.gd"

static var _open_brush
static var _material_cache := {}

static func find_material(desc: BrushDescriptor) -> Material:
	return find_material_for_descriptor(desc)

static func find_material_for_descriptor(desc: BrushDescriptor) -> Material:
	if desc == null:
		return null

	var cache_key := desc.m_Guid.strip_edges()
	if cache_key.is_empty():
		cache_key = desc.m_DurableName
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
		material = _prepare_live_material(material, desc)
		_apply_generated_geometry_culling(material, desc)

	_material_cache[cache_key] = material
	return material

static func find_material_for_guid(guid: String) -> Material:
	var open_brush: Variant = _get_open_brush()
	if open_brush == null:
		return null
	open_brush.ensure_loaded()
	var brush_name: String = open_brush.resolve_brush_name(guid)
	return find_material_for_name(brush_name)

static func find_material_for_name(brush_name: String) -> Material:
	if brush_name.is_empty():
		return null
	var cache_key := "name:%s" % brush_name.to_lower()
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var open_brush: Variant = _get_open_brush()
	if open_brush == null:
		_material_cache[cache_key] = null
		return null
	open_brush.ensure_loaded()
	var material: Material = open_brush.find_matching_brush_material(brush_name)
	if material != null:
		material = _prepare_live_material(material, null)
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

static func _prepare_live_material(source: Material, desc: BrushDescriptor) -> Material:
	var material: Material = source.duplicate()
	if material is ShaderMaterial:
		_apply_particle_rotation_channel(material as ShaderMaterial, desc)
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

static func _apply_generated_geometry_culling(material: Material, desc: BrushDescriptor) -> void:
	if desc == null or not desc.m_RenderBackfaces:
		return
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK

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
