extends SceneTree

const EXPORTER_SOURCE_PATH := "res://Tools/OpenBrushReferenceMeshExport/OpenBrushReferenceMeshExportTest.cs"
const EXPORTER_RUNNER_PATH := "res://Tools/OpenBrushReferenceMeshExport/RunOpenBrushReferenceMeshExport.ps1"
const REFERENCE_README_PATH := "res://Resources/Fixtures/OpenBrushReferenceMeshes/README.md"
const EXPECTED_FIXTURES := [
	{
		"name": "cafe_ink_stroke_150",
		"brush": "Ink",
		"source": "Resources/Fixtures/cafe_ink_stroke_150.json",
	},
	{
		"name": "cafe_duct_tape_geometry_stroke_496",
		"brush": "DuctTapeGeometry",
		"source": "Resources/Fixtures/cafe_duct_tape_geometry_stroke_496.json",
	},
	{
		"name": "cafe_stars_stroke_130",
		"brush": "Stars",
		"source": "Resources/Fixtures/cafe_stars_stroke_130.json",
	},
	{
		"name": "cafe_sparks_stroke_463",
		"brush": "Sparks",
		"source": "Resources/Fixtures/cafe_sparks_stroke_463.json",
	},
	{
		"name": "cafe_matte_hull_stroke_11",
		"brush": "MatteHull",
		"source": "Resources/Fixtures/cafe_matte_hull_stroke_11.json",
	},
]

var _failures := 0


func _init() -> void:
	var exporter_source := _read_text(EXPORTER_SOURCE_PATH)
	var exporter_runner := _read_text(EXPORTER_RUNNER_PATH)
	var reference_readme := _read_text(REFERENCE_README_PATH)
	_expect(not exporter_source.is_empty(), "exporter source loads")
	_expect(not exporter_runner.is_empty(), "exporter runner loads")
	_expect(not reference_readme.is_empty(), "reference fixture README loads")

	if not exporter_source.is_empty():
		_expect(exporter_source.contains("ExportRepresentativeCafeFixtures"), "representative cafe export test exists")
		_expect(exporter_source.contains("OpenBrushReferenceExport"), "OpenBrushReferenceExport category exists")
		for fixture_spec in EXPECTED_FIXTURES:
			_expect_exporter_contains_fixture(exporter_source, fixture_spec)

	if not exporter_runner.is_empty():
		_expect(exporter_runner.contains("open-brush-reference-exporter-worktree"), "runner defaults to exporter worktree")
		_expect(exporter_runner.contains("open-brush-fast"), "runner names main Open Brush checkout")
		_expect(exporter_runner.contains("AllowMainOpenBrushProject"), "runner has explicit main-checkout override")
		_expect(exporter_runner.contains("Refusing to run reference export against the main Open Brush checkout"), "runner refuses main checkout by default")

	if not reference_readme.is_empty():
		for fixture_spec in EXPECTED_FIXTURES:
			_expect_readme_lists_fixture(reference_readme, fixture_spec)
		_expect(reference_readme.contains("open-brush-reference-exporter-worktree"), "README documents exporter worktree")
		_expect(reference_readme.contains("-AllowMainOpenBrushProject"), "README documents main-checkout override")

	quit(1 if _failures > 0 else 0)


func _expect_exporter_contains_fixture(exporter_source: String, fixture_spec: Dictionary) -> void:
	var fixture_name := String(fixture_spec["name"])
	var brush_name := String(fixture_spec["brush"])
	var source_path := String(fixture_spec["source"])
	_expect(exporter_source.contains("name: \"%s\"" % fixture_name), "%s exporter fixture name" % fixture_name)
	_expect(exporter_source.contains("brushName: \"%s\"" % brush_name), "%s exporter brush name" % fixture_name)
	_expect(exporter_source.contains("sourceStrokeFixtureRelativePath: \"%s\"" % source_path), "%s exporter source fixture path" % fixture_name)


func _expect_readme_lists_fixture(reference_readme: String, fixture_spec: Dictionary) -> void:
	var fixture_name := String(fixture_spec["name"])
	var brush_name := String(fixture_spec["brush"])
	_expect(reference_readme.contains("`%s`" % fixture_name), "%s README fixture name" % fixture_name)
	_expect(reference_readme.contains("(`%s`)" % brush_name), "%s README brush name" % fixture_name)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("OPEN_BRUSH_REFERENCE_EXPORTER_COVERAGE PASS %s" % message)
	else:
		_failures += 1
		push_error("OPEN_BRUSH_REFERENCE_EXPORTER_COVERAGE FAIL %s" % message)
