class_name OpenBrushTiltSceneBuilder
extends RefCounted

const _BrushMaterialResolver := preload("res://Scripts/Brushes/BrushMaterialResolver.gd")
const _BrushRuntimeRegistry := preload("res://Scripts/Brushes/BrushRuntimeRegistry.gd")
const _TrTransform := preload("res://Scripts/TrTransform.gd")

const IMPORT_LOG_PREFIX := "TILT_RUNTIME_IMPORT"

var _open_brush: IcosaOpenBrush = null
var _runtime_manifest: TiltBrushManifest = null
var error_count := 0
var warning_count := 0
var _logged_messages := {}

func build_scene(tilt_data: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "TiltScene"

	var metadata: Dictionary = tilt_data.get("metadata", {})
	var strokes: Array = tilt_data.get("strokes", [])
	var manifest := _ensure_runtime_manifest()
	if manifest == null:
		_log_import_error("runtime manifest unavailable; tilt geometry cannot be generated")
		return root

	var scene_scale := _scene_scale_from_metadata(metadata)
	var ob := _get_open_brush()
	var env_preset: String = metadata.get("EnvironmentPreset", "")
	var resolved_env_guid: String = ob.resolve_env_guid(env_preset, "")

	var brush_groups := {}
	var ordered_hull_meshes: Array[MeshInstance3D] = []
	var hull_index := 0
	var stroke_index := 0
	for stroke_value in strokes:
		var stroke: Dictionary = stroke_value
		var desc := _resolve_stroke_descriptor(stroke)
		if desc == null:
			stroke_index += 1
			continue
		if _BrushRuntimeRegistry.is_compatibility_brush(manifest, desc):
			_log_import_warning("skipping compatibility brush %s (%s)" % [desc.m_DurableName, desc.m_Guid])
			stroke_index += 1
			continue
		if not _BrushRuntimeRegistry.is_supported(desc):
			_log_import_error("normal brush has no registered runtime implementation: %s (%s)" % [desc.m_DurableName, _prefab_name(desc)])
			stroke_index += 1
			continue

		var stroke_mesh := _build_runtime_mesh_data(desc, stroke, scene_scale, stroke_index)
		if stroke_mesh == null or stroke_mesh.is_empty():
			_log_import_error("runtime replay produced no mesh for stroke %d brush %s" % [stroke_index, desc.m_DurableName])
			stroke_index += 1
			continue

		if _is_hull_brush(desc):
			var hull_mesh := _build_mesh_instance(desc, stroke_mesh, "%s_%04d" % [desc.m_DurableName, hull_index])
			if hull_mesh != null:
				ordered_hull_meshes.append(hull_mesh)
				hull_index += 1
		else:
			var group_key := _descriptor_key(desc)
			if not brush_groups.has(group_key):
				brush_groups[group_key] = {"desc": desc, "mesh_data": MeshData.new()}
			var group: Dictionary = brush_groups[group_key]
			var merged: MeshData = group["mesh_data"]
			merged.append_mesh_data(stroke_mesh)
		stroke_index += 1

	for group_key in brush_groups:
		var group: Dictionary = brush_groups[group_key]
		var desc: BrushDescriptor = group["desc"]
		var mesh_data: MeshData = group["mesh_data"]
		var mesh_instance := _build_mesh_instance(desc, mesh_data, desc.m_DurableName)
		if mesh_instance != null:
			root.add_child(mesh_instance)
			mesh_instance.owner = root

	for hull_mesh in ordered_hull_meshes:
		root.add_child(hull_mesh)
		hull_mesh.owner = root

	var light_params: Dictionary = ob.extract_lights_from_env(resolved_env_guid)
	ob.apply_lights(
		root,
		light_params["light_0_dir"], light_params["light_0_col"],
		light_params["light_1_dir"], light_params["light_1_col"],
		light_params["ambient_col"])

	if ProjectSettings.get_setting("icosa/import/import_tilt_brush_environment", false):
		ob.apply_environment(root, resolved_env_guid)

	if ProjectSettings.get_setting("icosa/import/import_world_environment", false):
		ob.apply_world_environment(root, resolved_env_guid,
			Color(0, 0, 0, 0), Color(0, 0, 0, 0), Vector3.ZERO)

	return root

func _get_open_brush() -> IcosaOpenBrush:
	if _open_brush == null:
		_open_brush = IcosaOpenBrush.new()
		_open_brush.ensure_loaded()
	return _open_brush

func _ensure_runtime_manifest() -> TiltBrushManifest:
	if _runtime_manifest != null:
		return _runtime_manifest
	var project_path := ProjectSettings.globalize_path("res://")
	var manifest := UnityAssetLoader.load_manifest(project_path.path_join("Manifest.asset"))
	if manifest == null:
		return null
	var experimental_manifest := UnityAssetLoader.load_manifest(project_path.path_join("Manifest_Experimental.asset"))
	if experimental_manifest != null:
		manifest.append_from(experimental_manifest)
	BrushCatalog.init(manifest)
	_BrushRuntimeRegistry.register_supported_brushes(manifest)
	_runtime_manifest = manifest
	return _runtime_manifest

func _resolve_stroke_descriptor(stroke: Dictionary) -> BrushDescriptor:
	var guid: String = stroke.get("brush_guid", "")
	var desc := BrushCatalog.get_brush(guid)
	if desc == null:
		var mapped_name := _get_open_brush().resolve_brush_name(guid)
		desc = BrushCatalog.get_brush_by_durable_name(mapped_name)
		if desc != null:
			_log_import_warning("resolved legacy brush guid %s to %s" % [guid, desc.m_DurableName])
	if desc == null:
		_log_import_error("unresolved brush guid: %s" % guid)
	return desc

func _build_runtime_mesh_data(desc: BrushDescriptor, stroke: Dictionary, scene_scale: float, stroke_index: int) -> MeshData:
	var control_points: Array = stroke.get("control_points", [])
	if control_points.size() < 2:
		_log_import_warning("stroke %d has fewer than two control points" % stroke_index)
		return null

	var first_cp: Dictionary = control_points[0]
	var first_pos: Vector3 = first_cp.get("position", Vector3.ZERO) * scene_scale
	var first_orientation: Quaternion = first_cp.get("orientation", Quaternion.IDENTITY)
	var first_pressure := float(first_cp.get("pressure", 1.0))
	var stroke_scale := float(stroke.get("brush_scale", 1.0)) * scene_scale
	var stroke_size := float(stroke.get("brush_size", 0.01))
	var stroke_color: Color = stroke.get("color", Color.WHITE)
	var stroke_seed := int(stroke.get("seed", 0))

	var brush: BaseBrushScript = _BrushRuntimeRegistry.create_brush_for_descriptor(desc)
	if brush == null:
		_log_import_error("factory returned null for %s (%s)" % [desc.m_DurableName, _prefab_name(desc)])
		return null

	brush.m_BaseSize_PS = stroke_size
	brush.m_Color = stroke_color
	brush.set_is_loading()
	brush.set_random_seed(stroke_seed)
	brush.init_brush(desc, _TrTransform.trs(first_pos, first_orientation, stroke_scale))
	brush.set_random_seed(stroke_seed)

	for i in range(1, control_points.size()):
		var cp: Dictionary = control_points[i]
		var position: Vector3 = cp.get("position", Vector3.ZERO) * scene_scale
		var orientation: Quaternion = cp.get("orientation", Quaternion.IDENTITY)
		var pressure := float(cp.get("pressure", first_pressure))
		brush.update_position_ls(_TrTransform.trs(position, orientation, stroke_scale), pressure)

	brush.apply_changes_to_visuals()
	brush.finalize_solitary_brush()

	var result := MeshData.new()
	result.copy_from(brush.mesh_data)
	brush.free()
	return result

func _build_mesh_instance(desc: BrushDescriptor, mesh_data: MeshData, node_name: String) -> MeshInstance3D:
	if mesh_data == null or mesh_data.is_empty():
		return null
	var arrays := mesh_data.to_mesh_arrays()
	var verts = arrays[Mesh.ARRAY_VERTEX]
	if verts == null or (verts as PackedVector3Array).is_empty():
		return null

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, MeshData.surface_format_flags(arrays))
	var material: Material = _BrushMaterialResolver.find_material_for_descriptor(desc)
	if material != null:
		arr_mesh.surface_set_material(0, material)

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = arr_mesh
	return mi

func _scene_scale_from_metadata(metadata: Dictionary) -> float:
	var scene_xf: Array = metadata.get("SceneTransformInRoomSpace", [])
	var scene_scale := 1.0
	if scene_xf.size() >= 3:
		scene_scale = float(scene_xf[2])
	if scene_scale <= 0.0:
		scene_scale = 1.0
	return scene_scale

func _descriptor_key(desc: BrushDescriptor) -> String:
	var guid := desc.m_Guid.strip_edges().to_lower()
	if not guid.is_empty():
		return guid
	return desc.m_DurableName.to_lower()

func _is_hull_brush(desc: BrushDescriptor) -> bool:
	return _prefab_name(desc) in ["ConcaveHullPrefab", "HullPrefab", "HullPrefabPassthrough", "HullPrefabSmooth"]

func _prefab_name(desc: BrushDescriptor) -> String:
	if desc == null or desc.prefab_fields == null:
		return ""
	return String(desc.prefab_fields.get("prefab_name", ""))

func _log_import_warning(message: String) -> void:
	warning_count += 1
	if _logged_messages.has("warning:%s" % message):
		return
	_logged_messages["warning:%s" % message] = true
	var line := "%s WARNING %s" % [IMPORT_LOG_PREFIX, message]
	push_warning(line)
	_append_debug_log(line)

func _log_import_error(message: String) -> void:
	error_count += 1
	if _logged_messages.has("error:%s" % message):
		return
	_logged_messages["error:%s" % message] = true
	var line := "%s ERROR %s" % [IMPORT_LOG_PREFIX, message]
	push_error(line)
	_append_debug_log(line)

func _append_debug_log(line: String) -> void:
	var file := FileAccess.open("user://debug.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://debug.log", FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	file.close()
