extends SceneTree

const INVENTORY_PATH := "res://OPEN_BRUSH_BRUSH_CLASS_INVENTORY.md"
const SOURCE_BASELINE_PATH := "res://OPEN_BRUSH_SOURCE_BASELINE.md"
const CATALOG_PATH := "res://Resources/BrushCatalog/brush_catalog.json"

const RUNTIME_CLASSES := [
	"BaseBrushScript.gd",
	"GeometryBrush.gd",
	"QuadStripBrush.gd",
	"QuadStripBrushStretchUV.gd",
	"QuadStripBrushDistanceUV.gd",
	"QuadStripUnitizedUVBrush.gd",
	"FlatGeometryBrush.gd",
	"ThickGeometryBrush.gd",
	"TubeBrush.gd",
	"BubbleWandBrush.gd",
	"HullBrush.gd",
	"ConcaveHullBrush.gd",
	"SprayBrush.gd",
	"GeniusParticlesBrush.gd",
	"MidpointPlusLifetimeSprayBrush.gd",
	"TetraBrush.gd",
	"SquareBrush.gd",
	"Square3DPrintBrush.gd",
	"SliceBrush.gd",
	"PrintableBrush.gd",
	"BlocksBrushScript.gd",
	"PbrBrushScript.gd",
	"EnvironmentBrushScript.gd",
	"SvgBrushScript.gd",
]

const NORMAL_PREFABS := [
	"Line",
	"LineWithWidth",
	"DistanceUV",
	"UnitizedUV",
	"FlatDistance",
	"FlatStretch",
	"MidpointPlusOffset",
	"ThickDistance",
	"TubeDistanceUV",
	"TubeDistanceUVSin",
	"TubeStretchUV",
	"Tube_Petal",
	"Tube_Rain",
	"Tube_Sparks",
	"Tube_Spikes",
	"Tube_Tapered",
	"TubeBrush_Comet",
	"Lofted",
	"LoftedHueShift",
	"HullPrefab",
	"HullPrefabPassthrough",
	"HullPrefabSmooth",
	"ConcaveHullPrefab",
	"Spray",
	"GeniusParticle",
	"MiddpointPlusLifetimeGeomSpray",
	"SquareBrush_prefab",
	"Square3DPrintBrush",
	"Slice",
]

const COMPATIBILITY_PREFABS := [
	"BlocksFakeBrush",
	"EnvironmentFakeBrush",
	"EnvironmentLightmapFakeBrush",
	"PbrFakeBrush",
	"SvgFakeBrush",
]

const UNSUPPORTED_PARENT_PREFABS := [
	"CandyCane_prefab",
	"HolidayTree_prefab",
	"Plait_prefab",
	"Snowflake_prefab",
]

const UNSUPPORTED_PARENT_CLASSES := [
	"CandyCane.cs",
	"HolidayTree.cs",
	"PlaitBrush.cs",
	"SnowflakeBrush.cs",
]

const SOURCE_ONLY_CLASSES := [
	"ParentBrush.cs",
]

const EXPECTED_STATUS_SNIPPETS := [
	"BaseBrushScript.gd` | `BaseBrushScript.cs`",
	"Partially audited; lifecycle helper coverage includes scale conversions",
	"GeometryBrush.gd` | `GeometryBrush.cs`",
	"Partially audited.",
	"PbrBrushScript.gd` | `PbrBrushScript.cs`",
	"Audited as non-mesh layout provider.",
	"ParentBrush.cs` is the abstract Open Brush source helper",
	"Most mesh",
	"classes remain marked partially audited until line-by-line source comparison",
]

var _failures := 0


func _init() -> void:
	var inventory := _read_text(INVENTORY_PATH)
	_expect(not inventory.is_empty(), "inventory document loads")
	if not inventory.is_empty():
		_check_inventory_text(inventory)
		_check_catalog_prefabs_are_documented(inventory)
	var source_baseline := _read_text(SOURCE_BASELINE_PATH)
	_expect(not source_baseline.is_empty(), "source baseline document loads")
	if not source_baseline.is_empty():
		_check_source_baseline_text(source_baseline)
	quit(1 if _failures > 0 else 0)


func _check_inventory_text(inventory: String) -> void:
	for class_file in RUNTIME_CLASSES:
		_expect(inventory.contains("`%s`" % class_file), "%s is listed" % class_file)
	for prefab in NORMAL_PREFABS:
		_expect(inventory.contains("`%s`" % prefab), "%s normal prefab is listed" % prefab)
	for prefab in COMPATIBILITY_PREFABS:
		_expect(inventory.contains("`%s`" % prefab), "%s compatibility prefab is listed" % prefab)
	for prefab in UNSUPPORTED_PARENT_PREFABS:
		_expect(inventory.contains("`%s`" % prefab), "%s unsupported parent prefab is listed" % prefab)
	for source_file in UNSUPPORTED_PARENT_CLASSES:
		_expect(inventory.contains("`%s`" % source_file), "%s unsupported parent class is listed" % source_file)
	for source_file in SOURCE_ONLY_CLASSES:
		_expect(inventory.contains("`%s`" % source_file), "%s source-only class is listed" % source_file)
	for snippet in EXPECTED_STATUS_SNIPPETS:
		_expect(inventory.contains(snippet), "inventory status snippet is current: %s" % snippet)


func _check_catalog_prefabs_are_documented(inventory: String) -> void:
	var catalog := _read_json(CATALOG_PATH)
	_expect(not catalog.is_empty(), "brush catalog loads")
	if catalog.is_empty():
		return
	var descriptors: Dictionary = catalog.get("brushes", {})
	var manifests: Dictionary = catalog.get("manifests", {})
	var catalog_prefabs := {}
	for manifest_name in manifests.keys():
		var manifest: Dictionary = manifests[manifest_name]
		_collect_prefabs_from_guids(descriptors, manifest.get("brushes", []), catalog_prefabs)
		_collect_prefabs_from_guids(descriptors, manifest.get("compatibility_brushes", []), catalog_prefabs)
	for prefab in catalog_prefabs.keys():
		_expect(inventory.contains("`%s`" % prefab), "%s catalog prefab is documented" % prefab)
	var unsupported_brushes: Dictionary = catalog.get("unsupported_brushes", {})
	for unsupported in unsupported_brushes.values():
		if not unsupported is Dictionary:
			continue
		var fields: Dictionary = unsupported.get("prefab_fields", {})
		var prefab := String(fields.get("prefab_name", ""))
		if prefab != "":
			_expect(inventory.contains("`%s`" % prefab), "%s unsupported catalog prefab is documented" % prefab)


func _check_source_baseline_text(source_baseline: String) -> void:
	for snippet in [
		"`origin/feature/godot`",
		"`737f46875a97bbb3fc139929f3c029370777d5fa`",
		"`Assets/Scripts/Brushes`",
		"`Scripts/Brushes`",
		"`GeniusParticlesBrush.cs` -> `GeniusParticlesBrush.gd`",
		"`QuadStripBrush.cs` -> `QuadStripBrush.gd`",
		"`BrushRuntimeRegistry.gd`",
		"`MeshData.gd`",
		"do not use or modify that checkout",
	]:
		_expect(source_baseline.contains(snippet), "source baseline includes %s" % snippet)


func _collect_prefabs_from_guids(descriptors: Dictionary, guids: Array, output: Dictionary) -> void:
	for guid in guids:
		var desc: Dictionary = descriptors.get(String(guid), {})
		var fields: Dictionary = desc.get("prefab_fields", {})
		var prefab := String(fields.get("prefab_name", ""))
		if prefab != "":
			output[prefab] = true


func _read_json(path: String) -> Dictionary:
	var text := _read_text(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("BRUSH_CLASS_INVENTORY_COVERAGE PASS %s" % message)
	else:
		_failures += 1
		push_error("BRUSH_CLASS_INVENTORY_COVERAGE FAIL %s" % message)
