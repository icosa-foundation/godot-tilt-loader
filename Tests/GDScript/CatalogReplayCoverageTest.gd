extends SceneTree

const COVERED_REPLAY_PREFAB_COUNTS := {
	"Line": 20,
	"LineWithWidth": 1,
	"DistanceUV": 19,
	"UnitizedUV": 1,
	"FlatDistance": 1,
	"FlatStretch": 2,
	"MidpointPlusOffset": 3,
	"ThickDistance": 1,
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
	"HullPrefab": 4,
	"HullPrefabPassthrough": 1,
	"HullPrefabSmooth": 1,
	"ConcaveHullPrefab": 1,
	"Spray": 4,
	"GeniusParticle": 7,
	"MiddpointPlusLifetimeGeomSpray": 3,
	"SquareBrush_prefab": 1,
	"Square3DPrintBrush": 1,
	"Slice": 1,
}

const REPLAY_TESTS_BY_PREFAB := {
	"Line": "FlatStripCatalogReplayTest.gd",
	"LineWithWidth": "FlatStripCatalogReplayTest.gd",
	"DistanceUV": "FlatStripCatalogReplayTest.gd",
	"UnitizedUV": "FlatStripCatalogReplayTest.gd",
	"FlatDistance": "FlatStripCatalogReplayTest.gd",
	"FlatStretch": "FlatStripCatalogReplayTest.gd",
	"MidpointPlusOffset": "FlatStripCatalogReplayTest.gd",
	"ThickDistance": "SolidCatalogReplayTest.gd",
	"TubeDistanceUV": "TubeCatalogReplayTest.gd",
	"TubeDistanceUVSin": "TubeCatalogReplayTest.gd",
	"TubeStretchUV": "TubeCatalogReplayTest.gd",
	"Tube_Petal": "TubeCatalogReplayTest.gd",
	"Tube_Rain": "TubeCatalogReplayTest.gd",
	"Tube_Sparks": "TubeCatalogReplayTest.gd",
	"Tube_Spikes": "TubeCatalogReplayTest.gd",
	"Tube_Tapered": "TubeCatalogReplayTest.gd",
	"TubeBrush_Comet": "TubeCatalogReplayTest.gd",
	"Lofted": "TubeCatalogReplayTest.gd",
	"LoftedHueShift": "TubeCatalogReplayTest.gd",
	"HullPrefab": "SolidCatalogReplayTest.gd",
	"HullPrefabPassthrough": "SolidCatalogReplayTest.gd",
	"HullPrefabSmooth": "SolidCatalogReplayTest.gd",
	"ConcaveHullPrefab": "SolidCatalogReplayTest.gd",
	"Spray": "SprayCatalogReplayTest.gd",
	"GeniusParticle": "GeniusParticlesCatalogReplayTest.gd",
	"MiddpointPlusLifetimeGeomSpray": "SprayCatalogReplayTest.gd",
	"SquareBrush_prefab": "SolidCatalogReplayTest.gd",
	"Square3DPrintBrush": "SolidCatalogReplayTest.gd",
	"Slice": "SolidCatalogReplayTest.gd",
}

var _failures := 0

func _init() -> void:
	var manifest := _load_manifest()
	_expect(manifest != null, "runtime manifest loads")
	if manifest != null:
		_check_all_normal_prefabs_have_catalog_replay_coverage(manifest)
		_check_replay_test_files_exist()
	if _failures == 0:
		print("CATALOG_REPLAY_COVERAGE: all checks passed")
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

func _check_all_normal_prefabs_have_catalog_replay_coverage(manifest: TiltBrushManifest) -> void:
	var compatibility := {}
	for brush in manifest.CompatibilityBrushes:
		compatibility[_brush_key(brush)] = true

	var actual_counts := {}
	var normal_count := 0
	for desc in manifest.Brushes:
		if desc == null or compatibility.has(_brush_key(desc)):
			continue
		var prefab := String(desc.prefab_fields.get("prefab_name", ""))
		actual_counts[prefab] = int(actual_counts.get(prefab, 0)) + 1
		normal_count += 1

	_expect_equal(normal_count, 97, "merged manifest normal brush count")
	for prefab in actual_counts.keys():
		_expect(COVERED_REPLAY_PREFAB_COUNTS.has(prefab), "%s has catalog replay coverage" % prefab)
		_expect(REPLAY_TESTS_BY_PREFAB.has(prefab), "%s names its catalog replay test" % prefab)
	for prefab in COVERED_REPLAY_PREFAB_COUNTS.keys():
		_expect_equal(int(actual_counts.get(prefab, 0)), int(COVERED_REPLAY_PREFAB_COUNTS[prefab]), "%s covered replay count" % prefab)

func _check_replay_test_files_exist() -> void:
	var seen := {}
	for test_file in REPLAY_TESTS_BY_PREFAB.values():
		seen[String(test_file)] = true
	for test_file in seen.keys():
		_expect(FileAccess.file_exists("res://Tests/GDScript/%s" % test_file), "%s exists" % test_file)

func _brush_key(brush: BrushDescriptor) -> String:
	if brush == null:
		return ""
	return brush.m_Guid.strip_edges().to_lower().replace("-", "")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("CatalogReplayCoverageTest: %s" % message)

func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error("CatalogReplayCoverageTest: %s expected %s but got %s" % [message, expected, actual])
