extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

var _failures := 0

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
