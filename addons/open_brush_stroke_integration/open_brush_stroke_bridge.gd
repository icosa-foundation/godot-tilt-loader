@tool
class_name OpenBrushStrokeBridge
extends RefCounted

const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"
const ICOSA_OPEN_BRUSH_PATH := "res://addons/icosa/open_brush/open_brush.gd"
const _BrushMaterialResolver := preload("res://Scripts/Brushes/BrushMaterialResolver.gd")

var _open_brush
var _runtime_manifest: TiltBrushManifest = null

func _init(open_brush = null) -> void:
	_open_brush = open_brush

func load_tilt_as_strokes(path: String, canvas: CanvasScript = null) -> Array[Stroke]:
	var reader = _new_tilt_reader()
	if reader == null:
		return []
	var tilt_data: Dictionary = reader.load_tilt(path)
	if not String(tilt_data.get("error", "")).is_empty():
		push_error("OpenBrushStrokeBridge: %s" % tilt_data["error"])
		return []
	return convert_tilt_data_to_strokes(tilt_data, canvas)

func convert_tilt_data_to_strokes(tilt_data: Dictionary, canvas: CanvasScript = null) -> Array[Stroke]:
	var output: Array[Stroke] = []
	var scene_scale := _scene_scale(tilt_data.get("metadata", {}))
	for stroke_data in tilt_data.get("strokes", []):
		if stroke_data is Dictionary:
			var stroke := stroke_from_icosa_stroke(stroke_data, canvas, scene_scale)
			if stroke != null:
				output.append(stroke)
	return output

func stroke_from_icosa_stroke(stroke_data: Dictionary, canvas: CanvasScript = null, scene_scale: float = 1.0, desc: BrushDescriptor = null) -> Stroke:
	var control_points: Array = stroke_data.get("control_points", [])
	if control_points.is_empty():
		return null
	if desc == null:
		desc = _resolve_descriptor(stroke_data)
	if desc == null:
		return null

	var stroke := Stroke.new()
	stroke.m_Type = Stroke.Type.NOT_CREATED
	stroke.m_IntendedCanvas = canvas
	stroke.m_BrushGuid = desc.m_Guid
	stroke.m_BrushScale = float(stroke_data.get("brush_scale", 1.0)) * scene_scale
	stroke.m_BrushSize = float(stroke_data.get("brush_size", 1.0))
	stroke.m_Color = stroke_data.get("color", Color.WHITE)
	stroke.m_Seed = int(stroke_data.get("seed", 0))
	stroke.m_ControlPoints = []
	stroke.m_ControlPointsToDrop = []

	for index in range(control_points.size()):
		var point_data = control_points[index]
		if not point_data is Dictionary:
			continue
		var position: Vector3 = point_data.get("position", Vector3.ZERO) * scene_scale
		var orientation: Quaternion = point_data.get("orientation", Quaternion.IDENTITY)
		var pressure := float(point_data.get("pressure", 1.0))
		var timestamp := int(point_data.get("timestamp", index))
		stroke.m_ControlPoints.append(ControlPoint.create(position, orientation, pressure, timestamp))
		stroke.m_ControlPointsToDrop.append(false)

	if stroke.m_ControlPoints.is_empty():
		return null
	return stroke

func _resolve_descriptor(stroke_data: Dictionary) -> BrushDescriptor:
	var guid := String(stroke_data.get("brush_guid", ""))
	return _resolve_descriptor_by_guid(guid)

func _resolve_descriptor_by_guid(guid: String) -> BrushDescriptor:
	_ensure_runtime_manifest()
	var desc := BrushCatalog.get_brush(guid)
	if desc != null:
		return desc
	if not _ensure_open_brush():
		return null
	_open_brush.ensure_loaded()
	var mapped_name: String = _open_brush.resolve_brush_name(guid)
	desc = BrushCatalog.get_brush_by_durable_name(mapped_name)
	if desc == null:
		push_error("OpenBrushStrokeBridge: unresolved brush guid %s" % guid)
	return desc

func recreate_strokes(canvas: CanvasScript, pointer: PointerScript, strokes: Array[Stroke]) -> Array[Stroke]:
	var recreated: Array[Stroke] = []
	if canvas == null or pointer == null:
		push_error("OpenBrushStrokeBridge: canvas and pointer are required to recreate strokes")
		return recreated
	for stroke in strokes:
		if stroke == null:
			continue
		stroke.m_IntendedCanvas = canvas
		var before := stroke.m_Type
		pointer.recreate_line_from_memory(stroke)
		if stroke.m_Type != before and stroke.m_Type == Stroke.Type.BRUSH_STROKE:
			recreated.append(stroke)
	return recreated

func find_material_for_stroke(stroke: Stroke) -> Material:
	if stroke == null:
		return null
	var desc := _resolve_descriptor_by_guid(stroke.m_BrushGuid)
	if desc == null:
		return null
	return _BrushMaterialResolver.find_material_for_descriptor(desc)

func apply_material_to_stroke(stroke: Stroke) -> void:
	var material := find_material_for_stroke(stroke)
	if material == null or stroke == null or stroke.m_Object == null:
		return
	_apply_material_recursive(stroke.m_Object, material)

func _apply_material_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.mesh.surface_set_material(surface_index, material)
	for child in node.get_children():
		_apply_material_recursive(child, material)

func _scene_scale(metadata: Dictionary) -> float:
	var scene_xf: Array = metadata.get("SceneTransformInRoomSpace", [])
	if scene_xf.size() >= 3:
		var scale := float(scene_xf[2])
		if scale > 0.0:
			return scale
	return 1.0

func _new_tilt_reader():
	var script := load(TILT_READER_PATH)
	if script == null:
		push_error("OpenBrushStrokeBridge: Icosa tilt reader is missing. Run gd-plug install from the repository root.")
		return null
	return script.new()

func _ensure_open_brush() -> bool:
	if _open_brush != null:
		return true
	var script := load(ICOSA_OPEN_BRUSH_PATH)
	if script == null:
		push_error("OpenBrushStrokeBridge: Icosa Open Brush helper is missing. Run gd-plug install from the repository root.")
		return false
	_open_brush = script.new()
	return true

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
	_runtime_manifest = manifest
	return _runtime_manifest
