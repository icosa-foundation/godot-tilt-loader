extends SceneTree

const BrushRuntimeRegistryScript := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")

var _failures := 0

func _init() -> void:
	_check_live_registry_excludes_compatibility_brushes()
	_check_parent_composite_brushes_are_explicitly_unsupported()
	_check_experimental_promotions_are_live_brushes()
	_check_unknown_normal_prefab_does_not_generate_fallback_mesh()
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

func _check_experimental_promotions_are_live_brushes() -> void:
	var manifest := _load_manifest()
	BrushCatalog.init(manifest)
	BrushRuntimeRegistryScript.register_supported_brushes(manifest)
	var expected := {
		"DotMarker": {
			"prefab": "Spray",
			"runtime": "SprayBrush",
		},
		"Plasma": {
			"prefab": "DistanceUV",
			"runtime": "QuadStripBrushDistanceUV",
		},
		"TaperedMarker_Flat": {
			"prefab": "FlatStretch",
			"runtime": "FlatGeometryBrush",
		},
	}
	for durable_name in expected.keys():
		var desc := _find_brush_by_durable_name(manifest.Brushes, durable_name)
		_expect(desc != null, "promoted brush is present as normal brush: %s" % durable_name)
		if desc == null:
			continue
		_expect(not BrushRuntimeRegistryScript.is_compatibility_brush(manifest, desc), "promoted brush is not compatibility: %s" % durable_name)
		_expect(BrushRuntimeRegistryScript.is_supported(desc), "promoted brush has live factory: %s" % durable_name)
		_expect(String(desc.prefab_fields.get("prefab_name", "")) == String(expected[durable_name]["prefab"]), "promoted brush prefab route: %s" % durable_name)
		var brush := BrushRuntimeRegistryScript.create_brush_for_descriptor(desc)
		_expect(brush != null, "promoted brush creates runtime instance: %s" % durable_name)
		if brush != null:
			_expect(brush.get_class() == String(expected[durable_name]["runtime"]) or _runtime_class_name(brush) == String(expected[durable_name]["runtime"]), "promoted brush runtime class: %s" % durable_name)
			brush.free()

func _find_brush_by_durable_name(brushes: Array[BrushDescriptor], durable_name: String) -> BrushDescriptor:
	for brush in brushes:
		if brush != null and brush.m_DurableName == durable_name:
			return brush
	return null

func _runtime_class_name(brush: BaseBrushScript) -> String:
	if brush is SprayBrush:
		return "SprayBrush"
	if brush is QuadStripBrushDistanceUV:
		return "QuadStripBrushDistanceUV"
	if brush is FlatGeometryBrush:
		return "FlatGeometryBrush"
	return brush.get_class()

func _check_unknown_normal_prefab_does_not_generate_fallback_mesh() -> void:
	var desc := _test_descriptor("UnknownNormalBrush", "dddddddd-dddd-dddd-dddd-dddddddddddd", "NoRuntimeFactory")
	var manifest := TiltBrushManifest.new()
	manifest.Brushes = [desc]
	manifest.CompatibilityBrushes = []
	BrushCatalog.init(manifest)
	BrushRuntimeRegistryScript.register_supported_brushes(manifest)
	_expect(not BrushRuntimeRegistryScript.is_supported(desc), "unknown normal prefab is not registered")
	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_BrushGuid = desc.m_Guid
	stroke.m_BrushScale = 1.0
	stroke.m_BrushSize = 0.1
	stroke.m_Color = Color(1.0, 0.0, 0.0, 1.0)
	stroke.m_Seed = 123
	stroke.m_ControlPoints = [
		ControlPoint.create(Vector3.ZERO, Quaternion.IDENTITY, 1.0, 0),
		ControlPoint.create(Vector3.RIGHT, Quaternion.IDENTITY, 1.0, 1),
	]
	stroke.m_ControlPointsToDrop = [false, false]
	var mesh := BrushStrokeReplay.build_mesh_data_for_stroke(stroke)
	_expect(mesh == null, "unknown normal prefab does not produce fallback mesh")

func _test_descriptor(durable_name: String, guid: String, prefab_name: String) -> BrushDescriptor:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = durable_name
	desc.m_Guid = guid
	desc.prefab_fields = {
		"prefab_name": prefab_name,
	}
	return desc

func _load_manifest() -> TiltBrushManifest:
	var manifest := UnityAssetLoader.load_manifest(ProjectSettings.globalize_path("res://").path_join("Manifest.asset"))
	var experimental := UnityAssetLoader.load_manifest(ProjectSettings.globalize_path("res://").path_join("Manifest_Experimental.asset"))
	manifest.append_from(experimental)
	return manifest

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("BrushRuntimeRegistryParityTest: %s" % message)
