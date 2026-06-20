extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

var _failures := 0

func _init() -> void:
	_check_live_registry_excludes_compatibility_brushes()
	quit(1 if _failures > 0 else 0)

func _check_live_registry_excludes_compatibility_brushes() -> void:
	var manifest := UnityAssetLoader.load_manifest(ProjectSettings.globalize_path("res://").path_join("Manifest.asset"))
	var experimental := UnityAssetLoader.load_manifest(ProjectSettings.globalize_path("res://").path_join("Manifest_Experimental.asset"))
	manifest.append_from(experimental)
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

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("BrushRuntimeRegistryParityTest: %s" % message)
