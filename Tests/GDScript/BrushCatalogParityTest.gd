extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	var project_path := ProjectSettings.globalize_path("res://")
	_check_ink_descriptor(project_path)
	_check_manifest_and_catalog(project_path)
	if _failures == 0:
		print("GDSCRIPT_PARITY_BRUSHCATALOG: all checks passed")

func _check_ink_descriptor(project_path: String) -> void:
	var ink_path := project_path.path_join("Resources").path_join("Brushes").path_join("Basic").path_join("Ink").path_join("Ink.asset")
	var ink := UnityAssetLoader.load_brush_descriptor(ink_path)
	_expect(ink != null, "Ink descriptor loads")
	if ink == null:
		return
	_expect_equal(ink.m_DurableName, "Ink", "Ink durable name")
	_expect_equal(ink.m_Guid, "f5c336cf-5108-4b40-ade9-c687504385ab", "Ink runtime GUID")
	_expect_vec2_close(ink.m_BrushSizeRange, Vector2(0.05, 1.0), "Ink brush size range")
	_expect_vec2_close(ink.m_PressureSizeRange, Vector2(0.2, 1.0), "Ink pressure size range")
	_expect_equal(ink.m_TextureAtlasV, 4, "Ink atlas V")
	_expect_close(ink.m_TileRate, 1.0, "Ink tile rate")
	_expect(ink.m_RenderBackfaces, "Ink render backfaces")
	_expect_equal(ink.m_Tags.size(), 1, "Ink tag count")
	_expect_equal(ink.m_Tags[0], "default", "Ink default tag")

func _check_manifest_and_catalog(project_path: String) -> void:
	var manifest_path := project_path.path_join("Manifest.asset")
	var manifest := UnityAssetLoader.load_manifest(manifest_path)
	_expect(manifest != null, "Manifest loads")
	if manifest == null:
		return
	_expect(manifest.Brushes.size() > 0, "Manifest contains brushes")
	var ink: BrushDescriptor = null
	for brush in manifest.Brushes:
		if brush.m_DurableName == "Ink" and brush.m_Guid == "f5c336cf-5108-4b40-ade9-c687504385ab":
			ink = brush
			break
	_expect(ink != null, "Manifest resolves Ink descriptor")

	BrushCatalog.init(manifest)
	_expect(BrushCatalog.all_brushes().size() > 0, "Catalog exposes GUI brushes")
	if ink != null:
		_expect(BrushCatalog.get_brush(ink.m_Guid) == ink, "Catalog gets Ink by runtime GUID")
		_expect(BrushCatalog.get_brush(ink.m_Guid.replace("-", "")) == ink, "Catalog gets Ink by canonical GUID")

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _expect_vec2_close(actual: Vector2, expected: Vector2, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)

func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_BRUSHCATALOG: %s" % message)
