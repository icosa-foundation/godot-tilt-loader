extends SceneTree

const TiltReaderScript := preload("res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd")
const TiltSceneBuilderScript := preload("res://addons/open_brush_stroke_integration/open_brush_tilt_scene_builder.gd")

const PREFIX := "IMPORTED_VS_RUNTIME_CAFE_INK"
const TILT_FILE := "res://Resources/Fixtures/brush_cafe_experimental.tilt"
const BRUSH_NODE_NAME := "Ink"

func _initialize() -> void:
	var imported_scene := _load_imported_scene()
	var runtime_scene := _build_runtime_scene()
	if imported_scene == null or runtime_scene == null:
		quit(1)
		return

	var imported_mesh := _find_mesh_instance(imported_scene, BRUSH_NODE_NAME)
	var runtime_mesh := _find_mesh_instance(runtime_scene, BRUSH_NODE_NAME)
	if imported_mesh == null or runtime_mesh == null:
		_log("missing mesh imported=%s runtime=%s" % [imported_mesh != null, runtime_mesh != null])
		quit(1)
		return

	_compare_meshes(imported_mesh, runtime_mesh)
	quit(0)

func _load_imported_scene() -> Node3D:
	var packed := load(TILT_FILE)
	if not packed is PackedScene:
		_log("imported resource is not PackedScene type=%s" % type_string(typeof(packed)))
		return null
	var scene: Node3D = packed.instantiate()
	_log("loaded imported scene from %s" % TILT_FILE)
	return scene

func _build_runtime_scene() -> Node3D:
	var tilt_data: Dictionary = TiltReaderScript.new().load_tilt(TILT_FILE)
	var err := String(tilt_data.get("error", ""))
	if not err.is_empty():
		_log("reader error %s" % err)
		return null
	var scene: Node3D = TiltSceneBuilderScript.new().build_scene(tilt_data)
	_log("rebuilt runtime scene from %s strokes=%d" % [TILT_FILE, tilt_data.get("strokes", []).size()])
	return scene

func _find_mesh_instance(root: Node, node_name: String) -> MeshInstance3D:
	if root is MeshInstance3D and root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_mesh_instance(child, node_name)
		if found != null:
			return found
	return null

func _compare_meshes(imported_mi: MeshInstance3D, runtime_mi: MeshInstance3D) -> void:
	var imported_arrays := imported_mi.mesh.surface_get_arrays(0)
	var runtime_arrays := runtime_mi.mesh.surface_get_arrays(0)
	var imported_vertices: PackedVector3Array = imported_arrays[Mesh.ARRAY_VERTEX]
	var runtime_vertices: PackedVector3Array = runtime_arrays[Mesh.ARRAY_VERTEX]
	var imported_uv: PackedVector2Array = imported_arrays[Mesh.ARRAY_TEX_UV]
	var runtime_uv: PackedVector2Array = runtime_arrays[Mesh.ARRAY_TEX_UV]
	var imported_indices: PackedInt32Array = imported_arrays[Mesh.ARRAY_INDEX]
	var runtime_indices: PackedInt32Array = runtime_arrays[Mesh.ARRAY_INDEX]

	_log("counts imported verts=%d indices=%d uv0=%d runtime verts=%d indices=%d uv0=%d" % [
		imported_vertices.size(),
		imported_indices.size(),
		imported_uv.size(),
		runtime_vertices.size(),
		runtime_indices.size(),
		runtime_uv.size(),
	])
	_log("materials imported=%s runtime=%s" % [
		_material_name(imported_mi.mesh.surface_get_material(0)),
		_material_name(runtime_mi.mesh.surface_get_material(0)),
	])

	var shared_vertices := mini(imported_vertices.size(), runtime_vertices.size())
	var max_vertex_delta := 0.0
	for i in range(shared_vertices):
		max_vertex_delta = maxf(max_vertex_delta, imported_vertices[i].distance_to(runtime_vertices[i]))

	var shared_uv := mini(imported_uv.size(), runtime_uv.size())
	var max_uv_delta := 0.0
	var max_uv_index := -1
	for i in range(shared_uv):
		var uv_delta := imported_uv[i].distance_to(runtime_uv[i])
		if uv_delta > max_uv_delta:
			max_uv_delta = uv_delta
			max_uv_index = i
	var visible_uv := _max_visible_uv_delta(imported_vertices, imported_indices, imported_uv, runtime_uv)

	_log("deltas shared_verts=%d max_vertex_delta=%f shared_uv=%d max_uv_delta=%f max_uv_index=%d imported_uv=%s runtime_uv=%s visible_triangles=%d visible_max_uv_delta=%f visible_max_uv_index=%d" % [
		shared_vertices,
		max_vertex_delta,
		shared_uv,
		max_uv_delta,
		max_uv_index,
		imported_uv[max_uv_index] if max_uv_index >= 0 else Vector2.ZERO,
		runtime_uv[max_uv_index] if max_uv_index >= 0 else Vector2.ZERO,
		visible_uv.triangles,
		visible_uv.max_delta,
		visible_uv.index,
	])
	if max_uv_index >= 0:
		_log("max_uv_context %s" % _uv_context(imported_uv, runtime_uv, max_uv_index))
	_log("samples imported=%s runtime=%s" % [
		_samples(imported_vertices, imported_uv),
		_samples(runtime_vertices, runtime_uv),
	])

func _material_name(material: Material) -> String:
	if material == null:
		return "<null>"
	return "%s:%s" % [material.get_class(), material.resource_name]

func _samples(vertices: PackedVector3Array, uv: PackedVector2Array) -> String:
	var parts: Array[String] = []
	var count := mini(5, mini(vertices.size(), uv.size()))
	for i in range(count):
		parts.append("#%d v=%s uv=%s" % [i, vertices[i], uv[i]])
	return " | ".join(parts)

func _uv_context(imported_uv: PackedVector2Array, runtime_uv: PackedVector2Array, center: int) -> String:
	var parts: Array[String] = []
	var start := maxi(0, center - 12)
	var end := mini(imported_uv.size(), center + 13)
	for i in range(start, end):
		parts.append("#%d i=%s r=%s d=%f" % [i, imported_uv[i], runtime_uv[i], imported_uv[i].distance_to(runtime_uv[i])])
	return " | ".join(parts)

func _max_visible_uv_delta(vertices: PackedVector3Array, indices: PackedInt32Array, imported_uv: PackedVector2Array, runtime_uv: PackedVector2Array) -> Dictionary:
	var max_delta := 0.0
	var max_index := -1
	var visible_triangles := 0
	for i in range(0, indices.size(), 3):
		var ia := indices[i]
		var ib := indices[i + 1]
		var ic := indices[i + 2]
		var area := (vertices[ib] - vertices[ia]).cross(vertices[ic] - vertices[ia]).length()
		if area <= 0.0000001:
			continue
		visible_triangles += 1
		for index in [ia, ib, ic]:
			var delta := imported_uv[index].distance_to(runtime_uv[index])
			if delta > max_delta:
				max_delta = delta
				max_index = index
	return {"max_delta": max_delta, "index": max_index, "triangles": visible_triangles}

func _log(message: String) -> void:
	print("%s %s" % [PREFIX, message])
