extends SceneTree

const BrushMaterialResolverScript := preload("res://Scripts/Brushes/BrushMaterialResolver.gd")
const BridgeScript := preload("res://addons/open_brush_stroke_integration/open_brush_stroke_bridge.gd")

const PARTICLE_SHADER_CONTRACT_BRUSHES := {
	"Bubbles": true,
	"Dots": true,
	"Embers": true,
	"Smoke": true,
	"Snow": true,
	"Stars": true,
}

const SIMPLE_PARTICLE_SHADER_BRUSHES := {
	"Rising Bubbles": true,
}

var _failures := 0

func _init() -> void:
	_check_live_brush_uses_icosa_material()
	_check_genius_particle_materials()
	_check_bridge_material_uses_resolver()
	quit(1 if _failures > 0 else 0)

func _check_live_brush_uses_icosa_material() -> void:
	var desc: BrushDescriptor = _find_brush("Ink")
	_expect(desc != null, "Ink descriptor exists")
	if desc == null:
		return

	var resolved: Material = BrushMaterialResolverScript.find_material(desc)
	_expect(resolved != null, "Ink resolves Icosa material")
	_expect(_has_brush_texture(resolved), "Ink material keeps brush textures")
	if resolved is StandardMaterial3D:
		_expect_equal((resolved as StandardMaterial3D).cull_mode, BaseMaterial3D.CULL_BACK, "generated Ink material culls duplicated backfaces")

	var brush := BaseBrushScript.new()
	brush.m_Desc = desc
	brush.m_Color = Color(0.2, 0.4, 0.8, 1.0)
	brush.mesh_data.vertices = [Vector3.ZERO, Vector3.RIGHT, Vector3.UP]
	brush.mesh_data.triangles = [0, 1, 2]
	brush.mesh_data.uv0_v2 = [Vector2.ZERO, Vector2.RIGHT, Vector2.UP]
	brush.mesh_data.colors = [brush.m_Color, brush.m_Color, brush.m_Color]
	brush.update_visible_mesh()

	var mesh_instance := brush.get_node_or_null("GeneratedMesh") as MeshInstance3D
	_expect(mesh_instance != null, "live brush creates generated mesh")
	if mesh_instance != null and mesh_instance.mesh != null:
		var live_material: Material = mesh_instance.mesh.surface_get_material(0)
		_expect(live_material != null, "live brush assigns a surface material")
		_expect(not live_material is StandardMaterial3D or _has_brush_texture(live_material), "live brush uses a real brush material")
		_expect(_has_brush_texture(live_material), "live brush assigned material keeps textures")
	brush.free()

func _check_genius_particle_materials() -> void:
	var manifest := _load_manifest()
	_expect(manifest != null, "manifest loads for Genius material checks")
	if manifest == null:
		return
	var checked := 0
	var particle_contract_checked := 0
	var simple_particle_checked := 0
	for desc in manifest.Brushes:
		if desc == null:
			continue
		if _is_compatibility_brush(manifest, desc):
			continue
		if String(desc.prefab_fields.get("prefab_name", "")) != "GeniusParticle":
			continue
		var material: Material = BrushMaterialResolverScript.find_material(desc)
		_expect(material != null, "%s resolves Icosa material" % desc.m_DurableName)
		_expect(material is ShaderMaterial, "%s resolves ShaderMaterial" % desc.m_DurableName)
		_expect(_has_brush_texture(material), "%s material keeps brush texture" % desc.m_DurableName)
		if material is ShaderMaterial:
			var shader := (material as ShaderMaterial).shader
			var code := shader.code if shader != null else ""
			_expect(not code.contains("TANGENT.z"), "%s runtime shader has no normalized Godot tangent dependency" % desc.m_DurableName)
			if PARTICLE_SHADER_CONTRACT_BRUSHES.has(desc.m_DurableName):
				particle_contract_checked += 1
				_expect(code.contains("CUSTOM0"), "%s shader reads particle CUSTOM0 data" % desc.m_DurableName)
				_expect(code.contains("UV2.y"), "%s runtime shader reads generated particle rotation from UV2.y" % desc.m_DurableName)
			elif SIMPLE_PARTICLE_SHADER_BRUSHES.has(desc.m_DurableName):
				simple_particle_checked += 1
				_expect(not code.contains("void vertex("), "%s is explicitly the simple UV/COLOR particle shader outlier" % desc.m_DurableName)
				_expect(not code.contains("CUSTOM0"), "%s simple shader does not require particle CUSTOM0 data" % desc.m_DurableName)
				_expect(not code.contains("UV2.y"), "%s simple shader does not require generated particle rotation" % desc.m_DurableName)
			else:
				_expect(false, "%s GeniusParticle shader contract is unclassified" % desc.m_DurableName)
		checked += 1
	_expect_equal(checked, 7, "normal GeniusParticle material count")
	_expect_equal(particle_contract_checked, 6, "normal GeniusParticle billboard shader contract count")
	_expect_equal(simple_particle_checked, 1, "normal GeniusParticle simple shader outlier count")

func _check_bridge_material_uses_resolver() -> void:
	var manifest := _load_manifest()
	_expect(manifest != null, "manifest loads for bridge material check")
	if manifest == null:
		return
	BrushCatalog.init(manifest)
	var desc := _find_brush("Embers")
	_expect(desc != null, "Embers descriptor exists for bridge material check")
	if desc == null:
		return
	var stroke := Stroke.new()
	stroke.m_BrushGuid = desc.m_Guid
	var material: Material = BridgeScript.new().find_material_for_stroke(stroke)
	_expect(material is ShaderMaterial, "bridge resolves Embers through runtime material resolver")
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		var code := shader.code if shader != null else ""
		_expect(code.contains("UV2.y"), "bridge GeniusParticle material reads generated rotation from UV2.y")
		_expect(not code.contains("TANGENT.z"), "bridge GeniusParticle material avoids normalized Godot tangent rotation")

func _find_brush(durable_name: String) -> BrushDescriptor:
	var manifest := _load_manifest()
	if manifest == null:
		return null
	for brush in manifest.Brushes:
		if brush != null and brush.m_DurableName == durable_name:
			return brush
	return null

func _load_manifest() -> TiltBrushManifest:
	var project_path: String = ProjectSettings.globalize_path("res://")
	var manifest: TiltBrushManifest = UnityAssetLoader.load_manifest(project_path.path_join("Manifest.asset"))
	var experimental: TiltBrushManifest = UnityAssetLoader.load_manifest(project_path.path_join("Manifest_Experimental.asset"))
	if manifest != null and experimental != null:
		manifest.append_from(experimental)
	return manifest

func _is_compatibility_brush(manifest: TiltBrushManifest, desc: BrushDescriptor) -> bool:
	var key := _brush_key(desc)
	for compatibility_brush in manifest.CompatibilityBrushes:
		if _brush_key(compatibility_brush) == key:
			return true
	return false

func _brush_key(desc: BrushDescriptor) -> String:
	if desc == null:
		return ""
	return desc.m_Guid.strip_edges().to_lower().replace("-", "")

func _has_brush_texture(material: Material) -> bool:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_texture != null
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		var shader: Shader = shader_material.shader
		if shader == null:
			return false
		for param in RenderingServer.get_shader_parameter_list(shader.get_rid()):
			var name: String = param["name"]
			var value: Variant = shader_material.get_shader_parameter(name)
			if value is Texture2D:
				return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("BrushMaterialResolverParityTest: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("BrushMaterialResolverParityTest: %s expected %s but got %s" % [message, expected, actual])
