extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

const EXPECTED_PREFAB_COUNTS := {
	"TubeDistanceUV": 14,
	"TubeDistanceUVSin": 1,
	"TubeStretchUV": 2,
	"Tube_Petal": 1,
	"Tube_Rain": 1,
	"Tube_Sparks": 1,
	"Tube_Spikes": 1,
	"Tube_Tapered": 1,
	"TubeBrush_Comet": 1,
	"Lofted": 1,
	"LoftedHueShift": 1,
}

var _failures := 0

func _init() -> void:
	App.force_deterministic_birth_time_for_export = true
	var manifest := _load_manifest()
	_expect(manifest != null, "runtime manifest loads")
	if manifest != null:
		BrushCatalog.init(manifest)
		BrushRuntimeRegistryScript.register_supported_brushes(manifest)
		_check_catalog_tube_prefabs(manifest)
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

func _check_catalog_tube_prefabs(manifest: TiltBrushManifest) -> void:
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
	var brush := BrushRuntimeRegistryScript.create_brush_for_descriptor(desc)
	var runtime_class := _runtime_class_name(brush)
	if brush != null:
		brush.free()
	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_BrushGuid = desc.m_Guid
	stroke.m_BrushScale = 1.0
	stroke.m_BrushSize = 0.16
	stroke.m_Color = Color(0.25, 0.7, 1.0, 1.0)
	stroke.m_Seed = 12345
	for point in _sample_points():
		stroke.m_ControlPoints.append(ControlPoint.create(point.position, point.orientation, point.pressure, point.timestamp))
		stroke.m_ControlPointsToDrop.append(false)

	var mesh_data := BrushStrokeReplay.build_mesh_data_for_stroke(stroke)
	_expect(mesh_data != null, "%s replay returns mesh data" % desc.m_DurableName)
	if mesh_data == null:
		return
	var vertex_count := mesh_data.vertices.size()
	print("TUBE_CATALOG_REPLAY\tbrush=%s\tprefab=%s\truntime=%s\tverts=%d\ttris=%d\tuv0_v2=%d\tuv0_v3=%d\tuv1_v4=%d\ttangents=%d" % [
		desc.m_DurableName,
		prefab,
		runtime_class,
		vertex_count,
		mesh_data.triangles.size(),
		mesh_data.uv0_v2.size(),
		mesh_data.uv0_v3.size(),
		mesh_data.uv1_v4.size(),
		mesh_data.tangents.size(),
	])

	_expect(vertex_count > 0, "%s replay produces vertices" % desc.m_DurableName)
	_expect(mesh_data.triangles.size() > 0, "%s replay produces triangles" % desc.m_DurableName)
	_expect_equal(mesh_data.normals.size(), vertex_count, "%s normal count" % desc.m_DurableName)
	_expect_equal(mesh_data.colors.size(), vertex_count, "%s color count" % desc.m_DurableName)
	if desc.m_DurableName == "BubbleWand":
		_expect_equal(runtime_class, "BubbleWandBrush", "%s runtime class" % desc.m_DurableName)
		_expect_equal(mesh_data.uv0_v3.size(), vertex_count, "%s BubbleWand uv0 Vector3 count" % desc.m_DurableName)
		_expect_equal(mesh_data.uv1_v4.size(), vertex_count, "%s BubbleWand uv1 Vector4 count" % desc.m_DurableName)
		_expect_equal(mesh_data.tangents.size(), 0, "%s BubbleWand tangent count" % desc.m_DurableName)
	else:
		_expect_equal(runtime_class, "TubeBrush", "%s runtime class" % desc.m_DurableName)
		if desc.m_TubeStoreRadiusInTexcoord0Z:
			_expect_equal(mesh_data.uv0_v3.size(), vertex_count, "%s radius uv0 Vector3 count" % desc.m_DurableName)
			_expect_equal(mesh_data.uv0_v2.size(), 0, "%s radius uv0 Vector2 count" % desc.m_DurableName)
		else:
			_expect_equal(mesh_data.uv0_v2.size(), vertex_count, "%s uv0 Vector2 count" % desc.m_DurableName)
			_expect_equal(mesh_data.uv0_v3.size(), 0, "%s uv0 Vector3 count" % desc.m_DurableName)
		_expect_equal(mesh_data.uv1_v4.size(), 0, "%s TubeBrush uv1 Vector4 count" % desc.m_DurableName)
		_expect_equal(mesh_data.tangents.size(), vertex_count, "%s tangent count" % desc.m_DurableName)

func _sample_points() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for index in range(8):
		var t := float(index)
		output.append({
			"position": Vector3(t * 0.65, sin(t * 0.35) * 0.08, cos(t * 0.25) * 0.06),
			"orientation": Quaternion(Vector3.UP, t * 0.08),
			"pressure": 0.85 + 0.15 * (float(index % 3) / 2.0),
			"timestamp": index * 16,
		})
	return output

func _runtime_class_name(brush: BaseBrushScript) -> String:
	if brush is BubbleWandBrush:
		return "BubbleWandBrush"
	if brush is TubeBrush:
		return "TubeBrush"
	return "<none>" if brush == null else brush.get_script().get_global_name()

func _brush_key(brush: BrushDescriptor) -> String:
	if brush == null:
		return ""
	return brush.m_Guid.strip_edges().to_lower().replace("-", "")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("TubeCatalogReplayTest: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("TubeCatalogReplayTest: %s expected %s but got %s" % [message, expected, actual])
