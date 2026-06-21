extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

var _failures := 0

func _init() -> void:
	_check_live_registry_excludes_compatibility_brushes()
	_check_open_brush_source_only_classes_are_not_manifest_brushes()
	quit(1 if _failures > 0 else 0)

func _check_live_registry_excludes_compatibility_brushes() -> void:
	var manifest := _load_manifest()
	BrushCatalog.init(manifest)
	BrushRuntimeRegistryScript.register_supported_brushes(manifest)

	for brush in manifest.CompatibilityBrushes:
		_expect(
			not BrushRuntimeRegistryScript.is_supported(brush),
			"compatibility brush is not live: %s" % brush.m_DurableName
		)

	for brush in manifest.Brushes:
		if BrushRuntimeRegistryScript.is_compatibility_brush(manifest, brush):
			continue
		_expect(
			BrushRuntimeRegistryScript.is_supported(brush),
			"live brush has runtime factory: %s" % brush.m_DurableName
		)

func _check_open_brush_source_only_classes_are_not_manifest_brushes() -> void:
	var manifest := _load_manifest()
	var source_only_names := {
		"CandyCane": true,
		"HolidayTree": true,
		"ParentBrush": true,
		"Plait": true,
		"Snowflake": true,
	}
	for brush in manifest.Brushes:
		_expect(not source_only_names.has(brush.m_DurableName), "source-only class is not a normal durable brush: %s" % brush.m_DurableName)
		var prefab := String(brush.prefab_fields.get("prefab_name", ""))
		_expect(not source_only_names.has(prefab), "source-only class is not a normal prefab: %s" % prefab)
	for brush in manifest.CompatibilityBrushes:
		_expect(not source_only_names.has(brush.m_DurableName), "source-only class is not a compatibility durable brush: %s" % brush.m_DurableName)
		var prefab := String(brush.prefab_fields.get("prefab_name", ""))
		_expect(not source_only_names.has(prefab), "source-only class is not a compatibility prefab: %s" % prefab)

func _load_manifest() -> TiltBrushManifest:
	var manifest := UnityAssetLoader.load_manifest(ProjectSettings.globalize_path("res://").path_join("Manifest.asset"))
	var experimental := UnityAssetLoader.load_manifest(ProjectSettings.globalize_path("res://").path_join("Manifest_Experimental.asset"))
	manifest.append_from(experimental)
	return manifest

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("BrushRuntimeRegistryParityTest: %s" % message)
