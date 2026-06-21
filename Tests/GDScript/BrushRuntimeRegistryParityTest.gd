extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

var _failures := 0

func _init() -> void:
	_check_live_registry_excludes_compatibility_brushes()
	_check_parent_composite_brushes_are_explicitly_unsupported()
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

func _check_parent_composite_brushes_are_explicitly_unsupported() -> void:
	var manifest := _load_manifest()
	var unsupported := UnityAssetLoader.get_unsupported_catalog_brushes()
	var expected := {
		"81969b4d6dd64af488d0ddece18329d8": "CandyCane",
		"b72ff267ccfa05a4d81f9da0e9e07539": "HolidayTree",
		"731681c2cdd050b478219dc6153f2a5c": "Snowflake",
		"0eecc41a00bac3044a9c10591d311f06": "Braid3",
	}
	for asset_guid in expected.keys():
		_expect(unsupported.has(asset_guid), "unsupported parent composite asset is classified: %s" % asset_guid)
		if unsupported.has(asset_guid):
			_expect(String(unsupported[asset_guid].get("m_DurableName", "")) == expected[asset_guid], "unsupported parent composite durable name: %s" % expected[asset_guid])
			_expect(String(unsupported[asset_guid].get("unsupported_reason", "")).contains("ParentBrush"), "unsupported parent composite reason mentions ParentBrush: %s" % expected[asset_guid])

	var parent_composite_names := {
		"CandyCane": true,
		"HolidayTree": true,
		"Braid3": true,
		"Snowflake": true,
	}
	for brush in manifest.Brushes:
		_expect(not parent_composite_names.has(brush.m_DurableName), "unsupported parent composite is not live: %s" % brush.m_DurableName)
		var prefab := String(brush.prefab_fields.get("prefab_name", ""))
		_expect(not prefab.ends_with("_prefab") or not ["CandyCane_prefab", "HolidayTree_prefab", "Plait_prefab", "Snowflake_prefab"].has(prefab), "unsupported parent composite prefab is not live: %s" % prefab)
	for brush in manifest.CompatibilityBrushes:
		_expect(not parent_composite_names.has(brush.m_DurableName), "unsupported parent composite is not compatibility brush: %s" % brush.m_DurableName)
		var prefab := String(brush.prefab_fields.get("prefab_name", ""))
		_expect(not ["CandyCane_prefab", "HolidayTree_prefab", "Plait_prefab", "Snowflake_prefab"].has(prefab), "unsupported parent composite prefab is not compatibility brush: %s" % prefab)

func _load_manifest() -> TiltBrushManifest:
	var manifest := UnityAssetLoader.load_manifest(ProjectSettings.globalize_path("res://").path_join("Manifest.asset"))
	var experimental := UnityAssetLoader.load_manifest(ProjectSettings.globalize_path("res://").path_join("Manifest_Experimental.asset"))
	manifest.append_from(experimental)
	return manifest

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("BrushRuntimeRegistryParityTest: %s" % message)
