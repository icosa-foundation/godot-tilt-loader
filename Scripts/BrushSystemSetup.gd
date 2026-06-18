class_name BrushSystemSetup
extends Node3D

@export var auto_load_brushes := true
@export var brushes_path := ""

var manifest: TiltBrushManifest

func _ready() -> void:
	if auto_load_brushes:
		load_brushes()

func load_brushes() -> void:
	var project_path := ProjectSettings.globalize_path("res://")
	var manifest_path := project_path.path_join("Manifest.asset")
	manifest = UnityAssetLoader.load_manifest(manifest_path)

	var experimental_path := project_path.path_join("Manifest_Experimental.asset")
	if FileAccess.file_exists(experimental_path):
		var experimental_manifest := UnityAssetLoader.load_manifest(experimental_path)
		manifest.append_from(experimental_manifest)

	if manifest != null and manifest.Brushes != null:
		BrushCatalog.init(manifest)
		print("Brush system initialized with %d brushes" % manifest.Brushes.size())
	else:
		push_error("Failed to load brush manifest")

func get_brush_by_name(durable_name: String) -> BrushDescriptor:
	if manifest == null:
		return null
	for brush in manifest.Brushes:
		if brush != null and brush.m_DurableName == durable_name:
			return brush
	return null

func get_default_brush() -> BrushDescriptor:
	if manifest != null and manifest.Brushes.size() > 0:
		return manifest.Brushes[0]
	return null
