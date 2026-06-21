extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

var _failures := 0
var _bounds_padding_checked := 0

func _init() -> void:
	App.force_deterministic_birth_time_for_export = true
	var manifest := _load_manifest()
	_expect(manifest != null, "runtime manifest loads")
	if manifest != null:
		BrushCatalog.init(manifest)
		BrushRuntimeRegistryScript.register_supported_brushes(manifest)
		_check_all_normal_genius_particle_brushes(manifest)
	App.force_deterministic_birth_time_for_export = false
	quit(1 if _failures > 0 else 0)

func _load_manifest() -> TiltBrushManifest:
	var project_path := ProjectSettings.globalize_path("res://")
	var manifest := UnityAssetLoader.load_manifest(project_path.path_join("Manifest.asset"))
	if manifest == null:
		return null
	var experimental := UnityAssetLoader.load_manifest(project_path.path_join("Manifest_Experimental.asset"))
	if experimental != null:
		manifest.append_from(experimental)
	return manifest

func _check_all_normal_genius_particle_brushes(manifest: TiltBrushManifest) -> void:
	var compatibility := {}
	for brush in manifest.CompatibilityBrushes:
		compatibility[_brush_key(brush)] = true

	var checked := 0
	for desc in manifest.Brushes:
		if desc == null or compatibility.has(_brush_key(desc)):
			continue
		if String(desc.prefab_fields.get("prefab_name", "")) != "GeniusParticle":
			continue
		_check_genius_particle_replay(desc)
		checked += 1
	_expect_equal(checked, 7, "normal GeniusParticle brush count")
	_expect_equal(_bounds_padding_checked, 2, "normal GeniusParticle bounds-padding brush count")

func _check_genius_particle_replay(desc: BrushDescriptor) -> void:
	_expect(BrushRuntimeRegistryScript.is_supported(desc), "%s is registered for live replay" % desc.m_DurableName)
	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_BrushGuid = desc.m_Guid
	stroke.m_BrushScale = 1.0
	stroke.m_BrushSize = 0.2
	stroke.m_Color = Color(1.0, 0.8, 0.25, 1.0)
	stroke.m_Seed = 12345
	for point in _sample_points():
		stroke.m_ControlPoints.append(ControlPoint.create(point.position, point.orientation, point.pressure, point.timestamp))
		stroke.m_ControlPointsToDrop.append(false)

	var mesh_data := BrushStrokeReplay.build_mesh_data_for_stroke(stroke)
	_expect(mesh_data != null, "%s replay returns mesh data" % desc.m_DurableName)
	if mesh_data == null:
		return
	var vertex_count := mesh_data.vertices.size()
	print("GENIUS_CATALOG_REPLAY\tbrush=%s\tverts=%d\ttris=%d\tuv0_v4=%d\tuv1_v3=%d\tcolors=%d" % [
		desc.m_DurableName,
		vertex_count,
		mesh_data.triangles.size(),
		mesh_data.uv0_v4.size(),
		mesh_data.uv1_v3.size(),
		mesh_data.colors.size(),
	])
	_expect(vertex_count > 0, "%s replay produces vertices" % desc.m_DurableName)
	_expect(mesh_data.triangles.size() > 0, "%s replay produces triangles" % desc.m_DurableName)
	_expect(vertex_count % GeniusParticlesBrush.K_VERTS_IN_SOLID == 0, "%s vertex count is particle-quad aligned" % desc.m_DurableName)
	_expect(mesh_data.triangles.size() % (GeniusParticlesBrush.K_TRIS_IN_SOLID * 3) == 0, "%s triangle index count is particle-quad aligned" % desc.m_DurableName)
	_expect_equal(mesh_data.normals.size(), vertex_count, "%s normal count" % desc.m_DurableName)
	_expect_equal(mesh_data.colors.size(), vertex_count, "%s color count" % desc.m_DurableName)
	_expect_equal(mesh_data.uv0_v4.size(), vertex_count, "%s uv0 Vector4 count" % desc.m_DurableName)
	_expect_equal(mesh_data.uv1_v3.size(), vertex_count, "%s uv1 Vector3 count" % desc.m_DurableName)
	_expect_equal(mesh_data.tangents.size(), 0, "%s tangent count" % desc.m_DurableName)
	_check_particle_array_export(desc, mesh_data)
	_check_generated_mesh_bounds_padding(desc, mesh_data)

func _check_particle_array_export(desc: BrushDescriptor, mesh_data: MeshData) -> void:
	var vertex_count := mesh_data.vertices.size()
	_expect(mesh_data.use_particle_attributes, "%s uses particle shader export path" % desc.m_DurableName)
	var arrays := mesh_data.to_mesh_arrays()
	_expect(arrays[Mesh.ARRAY_NORMAL] == null, "%s particle export removes center normals" % desc.m_DurableName)
	_expect(arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array, "%s particle export writes UV" % desc.m_DurableName)
	_expect(arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array, "%s particle export writes UV2 birth time and rotation" % desc.m_DurableName)
	_expect(arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array, "%s particle export writes importer-compatible tangent rotation" % desc.m_DurableName)
	_expect(arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array, "%s particle export writes CUSTOM0 center/id" % desc.m_DurableName)
	if not (
		arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array
		and arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array
		and arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array
		and arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array
	):
		return
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var custom0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	_expect_equal(uv.size(), vertex_count, "%s exported UV count" % desc.m_DurableName)
	_expect_equal(uv2.size(), vertex_count, "%s exported UV2 count" % desc.m_DurableName)
	_expect_equal(tangents.size(), vertex_count * 4, "%s exported tangent float count" % desc.m_DurableName)
	_expect_equal(custom0.size(), vertex_count * 4, "%s exported CUSTOM0 float count" % desc.m_DurableName)
	if vertex_count == 0:
		return
	var source_uv0 := mesh_data.uv0_v4[0]
	var source_center := mesh_data.normals[0]
	_expect_vec2_close(uv[0], Vector2(source_uv0.x, source_uv0.y), "%s exported texture uv" % desc.m_DurableName)
	_expect_vec2_close(uv2[0], Vector2(source_uv0.w, source_uv0.z), "%s exported birth time and rotation" % desc.m_DurableName)
	_expect_close(tangents[2], source_uv0.z, "%s exported importer-compatible rotation" % desc.m_DurableName)
	_expect_close(tangents[3], 1.0, "%s exported tangent handedness" % desc.m_DurableName)
	_expect_close(custom0[0], 0.0, "%s exported first vertex id" % desc.m_DurableName)
	_expect_vec3_close(
		Vector3(custom0[1], custom0[2], custom0[3]),
		source_center,
		"%s exported first particle center" % desc.m_DurableName
	)

func _check_generated_mesh_bounds_padding(desc: BrushDescriptor, mesh_data: MeshData) -> void:
	if desc.m_BoundsPadding <= 0.0:
		return
	_bounds_padding_checked += 1
	var original_aabb := _mesh_data_aabb(mesh_data)
	var brush := BaseBrushScript.new()
	get_root().add_child(brush)
	brush.m_Desc = desc
	brush.m_LastSpawnXf = TrTransform.identity()
	brush.mesh_data.copy_from(mesh_data)
	brush.update_visible_mesh()

	var mesh_instance := brush.get_node("GeneratedMesh") as MeshInstance3D
	_expect(mesh_instance != null, "%s generated mesh instance for bounds padding" % desc.m_DurableName)
	if mesh_instance != null:
		var mesh := mesh_instance.mesh as ArrayMesh
		_expect(mesh != null, "%s generated array mesh for bounds padding" % desc.m_DurableName)
		if mesh != null:
			var expected_padding := desc.m_BoundsPadding * App.METERS_TO_UNITS
			var expected := original_aabb.grow(expected_padding)
			_expect_vec3_close(mesh.custom_aabb.position, expected.position, "%s padded custom aabb position" % desc.m_DurableName)
			_expect_vec3_close(mesh.custom_aabb.size, expected.size, "%s padded custom aabb size" % desc.m_DurableName)
	brush.free()

func _mesh_data_aabb(mesh_data: MeshData) -> AABB:
	if mesh_data.vertices.is_empty():
		return AABB()
	var min_point := mesh_data.vertices[0]
	var max_point := mesh_data.vertices[0]
	for vertex in mesh_data.vertices:
		min_point.x = minf(min_point.x, vertex.x)
		min_point.y = minf(min_point.y, vertex.y)
		min_point.z = minf(min_point.z, vertex.z)
		max_point.x = maxf(max_point.x, vertex.x)
		max_point.y = maxf(max_point.y, vertex.y)
		max_point.z = maxf(max_point.z, vertex.z)
	return AABB(min_point, max_point - min_point)

func _sample_points() -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, 0.0, 0.0),
			"orientation": Quaternion.IDENTITY,
			"pressure": 1.0,
			"timestamp": 0,
		},
		{
			"position": Vector3(1.2, 0.1, 0.0),
			"orientation": Quaternion(Vector3.UP, 0.2),
			"pressure": 0.9,
			"timestamp": 16,
		},
		{
			"position": Vector3(2.1, -0.15, 0.25),
			"orientation": Quaternion(Vector3.UP, 0.45),
			"pressure": 1.0,
			"timestamp": 33,
		},
		{
			"position": Vector3(3.2, 0.05, -0.2),
			"orientation": Quaternion(Vector3.UP, 0.7),
			"pressure": 0.85,
			"timestamp": 50,
		},
	]

func _brush_key(brush: BrushDescriptor) -> String:
	if brush == null:
		return ""
	return brush.m_Guid.strip_edges().to_lower().replace("-", "")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("GeniusParticlesCatalogReplayTest: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("GeniusParticlesCatalogReplayTest: %s expected %s but got %s" % [message, expected, actual])

func _expect_vec2_close(actual: Vector2, expected: Vector2, message: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % message)
	_expect_close(actual.y, expected.y, "%s y" % message)

func _expect_vec3_close(actual: Vector3, expected: Vector3, message: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % message)
	_expect_close(actual.y, expected.y, "%s y" % message)
	_expect_close(actual.z, expected.z, "%s z" % message)

func _expect_close(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.00001:
		_failures += 1
		push_error("GeniusParticlesCatalogReplayTest: %s expected %.8f but got %.8f" % [message, expected, actual])
