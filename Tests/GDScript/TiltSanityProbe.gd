extends SceneTree

const TILT_READER_PATH := "res://addons/icosa/open_brush/open_brush_tilt_reader.gd"
const OPEN_BRUSH_PATH := "res://addons/icosa/open_brush/open_brush.gd"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var tilt_path := "res://Temp/TiltEvidence/brush_cafe_experimental.tilt"
	if not args.is_empty():
		tilt_path = args[0]

	var reader_script := load(TILT_READER_PATH)
	var open_brush_script := load(OPEN_BRUSH_PATH)
	if reader_script == null or open_brush_script == null:
		print("TILT_SANITY\tERROR\tmissing reader/open_brush scripts")
		quit(1)
		return

	var data: Dictionary = reader_script.new().load_tilt(tilt_path)
	var error := String(data.get("error", ""))
	if not error.is_empty():
		print("TILT_SANITY\tERROR\treader\t%s" % error)
		quit(1)
		return

	var ob = open_brush_script.new()
	ob.ensure_loaded()
	_print_source_stats(tilt_path, data, ob)
	_print_imported_scene_stats(tilt_path)
	quit(0)

func _print_source_stats(tilt_path: String, data: Dictionary, ob) -> void:
	var metadata: Dictionary = data.get("metadata", {})
	var strokes: Array = data.get("strokes", [])
	var scene_xf: Array = metadata.get("SceneTransformInRoomSpace", [])
	var scene_scale := 1.0
	if scene_xf.size() >= 3:
		scene_scale = float(scene_xf[2])

	var cps := 0
	var min_size := INF
	var max_size := 0.0
	var unscaled_bounds := _empty_bounds()
	var scaled_bounds := _empty_bounds()
	var brush_counts := {}
	for stroke in strokes:
		if not stroke is Dictionary:
			continue
		var brush_name: String = ob.resolve_brush_name(stroke.get("brush_guid", ""))
		brush_counts[brush_name] = brush_counts.get(brush_name, 0) + 1
		var brush_size := float(stroke.get("brush_size", 0.0)) * float(stroke.get("brush_scale", 1.0))
		min_size = minf(min_size, brush_size)
		max_size = maxf(max_size, brush_size)
		for cp in stroke.get("control_points", []):
			if not cp is Dictionary:
				continue
			cps += 1
			var position: Vector3 = cp.get("position", Vector3.ZERO)
			_expand_bounds(unscaled_bounds, position)
			_expand_bounds(scaled_bounds, position * scene_scale)

	var sorted_brushes := brush_counts.keys()
	sorted_brushes.sort_custom(func(a, b): return brush_counts[a] > brush_counts[b])
	var top := []
	for i in range(mini(12, sorted_brushes.size())):
		var brush_name = sorted_brushes[i]
		top.append("%s:%d" % [brush_name, brush_counts[brush_name]])

	print("TILT_SANITY\tSOURCE\tpath=%s\tstrokes=%d\tcontrol_points=%d\tthumbnail_bytes=%d\tscene_scale=%s\tenvironment=%s" % [
		tilt_path,
		strokes.size(),
		cps,
		(data.get("thumbnail", PackedByteArray()) as PackedByteArray).size(),
		str(scene_scale),
		String(metadata.get("EnvironmentPreset", "")),
	])
	print("TILT_SANITY\tSOURCE_BOUNDS\tunscaled_min=%s\tunscaled_max=%s\tscaled_min=%s\tscaled_max=%s\tbrush_size_min=%s\tbrush_size_max=%s" % [
		unscaled_bounds.min,
		unscaled_bounds.max,
		scaled_bounds.min,
		scaled_bounds.max,
		str(min_size),
		str(max_size),
	])
	print("TILT_SANITY\tSOURCE_TOP_BRUSHES\t%s" % ", ".join(top))

func _print_imported_scene_stats(tilt_path: String) -> void:
	var resource := load(tilt_path)
	if not resource is PackedScene:
		print("TILT_SANITY\tIMPORTED\tERROR\tnot_packed_scene")
		return
	var root: Node = resource.instantiate()
	var stats := {
		"mesh_instances": 0,
		"vertices": 0,
		"triangles": 0,
		"bounds": _empty_bounds(),
		"materials": {},
		"missing_material_meshes": [],
	}
	_collect_imported_recursive(root, stats)
	var material_names: Array = stats.materials.keys()
	material_names.sort()
	print("TILT_SANITY\tIMPORTED\tmesh_instances=%d\tvertices=%d\ttriangles=%d\tmaterials=%d" % [
		stats.mesh_instances,
		stats.vertices,
		stats.triangles,
		material_names.size(),
	])
	print("TILT_SANITY\tIMPORTED_BOUNDS\tmin=%s\tmax=%s" % [stats.bounds.min, stats.bounds.max])
	print("TILT_SANITY\tIMPORTED_MATERIALS\t%s" % ", ".join(material_names))
	if not stats.missing_material_meshes.is_empty():
		print("TILT_SANITY\tIMPORTED_MISSING_MATERIALS\t%s" % ", ".join(stats.missing_material_meshes))
	root.free()

func _collect_imported_recursive(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		stats.mesh_instances += 1
		var mesh: Mesh = node.mesh
		var aabb := (node as MeshInstance3D).get_aabb()
		_expand_bounds(stats.bounds, aabb.position)
		_expand_bounds(stats.bounds, aabb.position + aabb.size)
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			stats.vertices += vertices.size()
			stats.triangles += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
			var material := mesh.surface_get_material(surface)
			var material_name := "<none>"
			if material != null:
				material_name = material.resource_name
			else:
				stats.missing_material_meshes.append(node.name)
			stats.materials[material_name] = stats.materials.get(material_name, 0) + 1
	for child in node.get_children():
		_collect_imported_recursive(child, stats)

func _empty_bounds() -> Dictionary:
	return {"valid": false, "min": Vector3.ZERO, "max": Vector3.ZERO}

func _expand_bounds(bounds: Dictionary, point: Vector3) -> void:
	if not bounds.valid:
		bounds.valid = true
		bounds.min = point
		bounds.max = point
	else:
		bounds.min = bounds.min.min(point)
		bounds.max = bounds.max.max(point)
