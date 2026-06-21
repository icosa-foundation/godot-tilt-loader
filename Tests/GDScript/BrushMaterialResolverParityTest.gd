extends SceneTree

const BrushMaterialResolverScript := preload("res://Scripts/Brushes/BrushMaterialResolver.gd")

var _failures := 0

func _init() -> void:
	_check_live_brush_uses_icosa_material()
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

func _find_brush(durable_name: String) -> BrushDescriptor:
	var project_path: String = ProjectSettings.globalize_path("res://")
	var manifest: TiltBrushManifest = UnityAssetLoader.load_manifest(project_path.path_join("Manifest.asset"))
	var experimental: TiltBrushManifest = UnityAssetLoader.load_manifest(project_path.path_join("Manifest_Experimental.asset"))
	manifest.append_from(experimental)
	for brush in manifest.Brushes:
		if brush != null and brush.m_DurableName == durable_name:
			return brush
	return null

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
