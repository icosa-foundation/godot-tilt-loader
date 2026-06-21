extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

const EXPECTED_PREFAB_COUNTS := {
	"Spray": 4,
	"MiddpointPlusLifetimeGeomSpray": 3,
}

var _failures := 0

func _init() -> void:
	App.force_deterministic_birth_time_for_export = true
	var manifest := _load_manifest()
	_expect(manifest != null, "runtime manifest loads")
	if manifest != null:
		BrushCatalog.init(manifest)
		BrushRuntimeRegistryScript.register_supported_brushes(manifest)
		_check_catalog_spray_prefabs(manifest)
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

func _check_catalog_spray_prefabs(manifest: TiltBrushManifest) -> void:
	var compatibility := {}
	for brush in manifest.CompatibilityBrushes:
		compatibility[_brush_key(brush)] = true

	var counts := {}
	for desc in manifest.Brushes:
		if desc == null or compatibility.has(_brush_key(desc)):
			continue
		var prefab := String(desc.prefab_fields.get("prefab_name", ""))
		if not EXPECTED_PREFAB_COUNTS.has(prefab):
			continue
		counts[prefab] = int(counts.get(prefab, 0)) + 1
		_check_replay(desc, prefab)

	for prefab in EXPECTED_PREFAB_COUNTS.keys():
		_expect_equal(int(counts.get(prefab, 0)), int(EXPECTED_PREFAB_COUNTS[prefab]), "%s normal catalog count" % prefab)

func _check_replay(desc: BrushDescriptor, prefab: String) -> void:
	_expect(BrushRuntimeRegistryScript.is_supported(desc), "%s is registered for live replay" % desc.m_DurableName)
	_expect(desc.m_SprayRateMultiplier > 0.0, "%s spray rate multiplier is nonzero" % desc.m_DurableName)
	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_BrushGuid = desc.m_Guid
	stroke.m_BrushScale = 1.0
	stroke.m_BrushSize = 0.08
	stroke.m_Color = Color(0.9, 0.6, 0.2, 1.0)
	stroke.m_Seed = 12345
	for point in _sample_points():
		stroke.m_ControlPoints.append(ControlPoint.create(point.position, point.orientation, point.pressure, point.timestamp))
		stroke.m_ControlPointsToDrop.append(false)

	var mesh_data := BrushStrokeReplay.build_mesh_data_for_stroke(stroke)
	_expect(mesh_data != null, "%s replay returns mesh data" % desc.m_DurableName)
	if mesh_data == null:
		return
	var vertex_count := mesh_data.vertices.size()
	print("SPRAY_CATALOG_REPLAY\tbrush=%s\tprefab=%s\tverts=%d\ttris=%d\tuv0_v2=%d\tuv1_v4=%d\ttangents=%d" % [
		desc.m_DurableName,
		prefab,
		vertex_count,
		mesh_data.triangles.size(),
		mesh_data.uv0_v2.size(),
		mesh_data.uv1_v4.size(),
		mesh_data.tangents.size(),
	])

	_expect(vertex_count > 0, "%s replay produces vertices" % desc.m_DurableName)
	_expect(mesh_data.triangles.size() > 0, "%s replay produces triangles" % desc.m_DurableName)
	_expect_equal(mesh_data.normals.size(), vertex_count, "%s normal count" % desc.m_DurableName)
	_expect_equal(mesh_data.colors.size(), vertex_count, "%s color count" % desc.m_DurableName)
	_expect_equal(mesh_data.uv0_v2.size(), vertex_count, "%s uv0 Vector2 count" % desc.m_DurableName)
	_expect_equal(mesh_data.tangents.size(), vertex_count, "%s tangent count" % desc.m_DurableName)
	match prefab:
		"Spray":
			var stride := SprayBrush.K_VERTS_IN_SOLID * (2 if desc.m_RenderBackfaces else 1)
			_expect(vertex_count % stride == 0, "%s vertex count is Spray quad aligned" % desc.m_DurableName)
			_expect(mesh_data.uv1_v4.is_empty(), "%s Spray uv1 Vector4 is empty" % desc.m_DurableName)
		"MiddpointPlusLifetimeGeomSpray":
			_expect(vertex_count % MidpointPlusLifetimeSprayBrush.K_VERTS_IN_SOLID == 0, "%s midpoint vertex count is quad aligned" % desc.m_DurableName)
			_expect_equal(mesh_data.uv1_v4.size(), vertex_count, "%s midpoint uv1 Vector4 count" % desc.m_DurableName)

func _sample_points() -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, 0.0, 0.0),
			"orientation": Quaternion.IDENTITY,
			"pressure": 1.0,
			"timestamp": 0,
		},
		{
			"position": Vector3(1.2, 0.0, 0.1),
			"orientation": Quaternion(Vector3.UP, 0.2),
			"pressure": 0.9,
			"timestamp": 16,
		},
		{
			"position": Vector3(2.4, 0.15, -0.15),
			"orientation": Quaternion(Vector3.UP, 0.45),
			"pressure": 1.0,
			"timestamp": 33,
		},
		{
			"position": Vector3(3.6, -0.05, 0.2),
			"orientation": Quaternion(Vector3.UP, 0.7),
			"pressure": 0.95,
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
		push_error("SprayCatalogReplayTest: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("SprayCatalogReplayTest: %s expected %s but got %s" % [message, expected, actual])
