extends SceneTree

const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"
const TILT_IMPORTER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_scene_importer.gd"
const TILT_SCENE_BUILDER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_scene_builder.gd"
const SAMPLE_TILT_PATH := "res://Temp/TiltEvidence/brush_cafe_experimental.tilt"

var _failures := 0

func _init() -> void:
	_check_importer_has_no_fallback_tessellation()
	_check_importer_replays_tilt_through_runtime_brushes()
	quit(1 if _failures > 0 else 0)

func _check_importer_has_no_fallback_tessellation() -> void:
	var source := _read_text(TILT_IMPORTER_PATH) + "\n" + _read_text(TILT_SCENE_BUILDER_PATH)
	var forbidden_tokens := [
		"_tessellate_strokes",
		"_tessellate_particle_strokes",
		"_uses_runtime_flat_brush",
		"_uses_runtime_quad_strip_brush",
		"_uses_runtime_hull_brush",
		"PARTICLE_BRUSHES",
		"BRUSH_ATLAS_V",
		"BRUSH_TILE_RATE",
		"_FlatGeometryBrush",
		"_QuadStripBrushDistanceUV",
		"_QuadStripBrushStretchUV",
		"_HullBrush",
		"_ConcaveHullBrush",
		"FlatGeometryBrush.gd",
		"QuadStripBrush",
	]
	for token in forbidden_tokens:
		_expect(not source.contains(token), "tilt path has no fallback/importer-local brush path token: %s" % token)
	_expect(source.contains("BrushRuntimeRegistry"), "tilt path uses BrushRuntimeRegistry")
	_expect(source.contains("BrushStrokeReplay"), "tilt path uses BrushStrokeReplay")
	_expect(source.contains("BrushMaterialResolver"), "tilt path uses BrushMaterialResolver")

func _check_importer_replays_tilt_through_runtime_brushes() -> void:
	var reader_script := load(TILT_READER_PATH)
	var builder_script := load(TILT_SCENE_BUILDER_PATH)
	_expect(reader_script != null, "tilt reader script loads")
	_expect(builder_script != null, "tilt scene builder script loads")
	if reader_script == null or builder_script == null:
		return

	var tilt_data: Dictionary = reader_script.new().load_tilt(SAMPLE_TILT_PATH)
	var error := String(tilt_data.get("error", ""))
	_expect(error.is_empty(), "sample tilt reader succeeds")
	if not error.is_empty():
		return

	var builder = builder_script.new()
	var scene: Node3D = builder.build_scene(tilt_data)
	_expect(scene != null, "runtime replay returns a scene")
	if scene == null:
		return

	var stats := {
		"mesh_instances": 0,
		"vertices": 0,
		"triangles": 0,
		"materials": 0,
		"padded_particle_meshes": 0,
	}
	_collect_scene_stats(scene, stats)
	_expect(int(builder.error_count) == 0, "runtime replay has no unresolved normal brush errors")
	_expect(stats.mesh_instances > 50, "runtime replay creates many mesh instances")
	_expect(stats.vertices > 100000, "runtime replay creates substantial geometry")
	_expect(stats.triangles > 40000, "runtime replay creates substantial triangles")
	_expect(stats.materials > 50, "runtime replay assigns brush materials")
	_expect(stats.padded_particle_meshes >= 2, "runtime replay applies custom bounds padding to shader-displaced particle meshes")
	scene.free()

func _collect_scene_stats(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		stats.mesh_instances += 1
		var mesh: Mesh = node.mesh
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			stats.vertices += vertices.size()
			stats.triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
			if mesh.surface_get_material(surface) != null:
				stats.materials += 1
		if node.name in ["Embers", "Snow"] and _custom_aabb_grows_surface_bounds(mesh):
			stats.padded_particle_meshes += 1
	for child in node.get_children():
		_collect_scene_stats(child, stats)

func _custom_aabb_grows_surface_bounds(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	var original := _surface_bounds(mesh)
	var custom: AABB = mesh.custom_aabb
	return (
		custom.size.x > original.size.x + 0.001
		or custom.size.y > original.size.y + 0.001
		or custom.size.z > original.size.z + 0.001
	)

func _surface_bounds(mesh: Mesh) -> AABB:
	var have_vertex := false
	var min_point := Vector3.ZERO
	var max_point := Vector3.ZERO
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if not have_vertex:
				min_point = vertex
				max_point = vertex
				have_vertex = true
			else:
				min_point.x = minf(min_point.x, vertex.x)
				min_point.y = minf(min_point.y, vertex.y)
				min_point.z = minf(min_point.z, vertex.z)
				max_point.x = maxf(max_point.x, vertex.x)
				max_point.y = maxf(max_point.y, vertex.y)
				max_point.z = maxf(max_point.z, vertex.z)
	return AABB(min_point, max_point - min_point) if have_vertex else AABB()

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("could not read %s" % path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures += 1
	push_error("TiltImporterRuntimeReplayTest: %s" % message)
