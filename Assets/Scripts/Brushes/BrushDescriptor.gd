class_name BrushDescriptor
extends Resource

var name := ""
var m_Guid := ""
var m_DurableName := ""
var m_CreationVersion := ""
var m_ShaderVersion := "10.0"
var m_Tags: Array[String] = ["default"]
var m_Nondeterministic := false
var m_Supersedes: BrushDescriptor
var m_SupersededBy: BrushDescriptor
var m_LooksIdentical := false
var m_DescriptionExtra := ""
var m_HiddenInGui := false
var m_TextureAtlasV := 0
var m_TileRate := 0.0
var m_BrushSizeRange := Vector2.ZERO
var m_PressureSizeRange := Vector2(0.1, 1.0)
var m_SizeVariance := 0.0
var m_PreviewPressureSizeMin := 0.001
var m_Opacity := 0.0
var m_PressureOpacityRange := Vector2.ZERO
var m_ColorLuminanceMin := 0.0
var m_ColorSaturationMax := 0.0
var m_ParticleSpeed := 0.0
var m_ParticleRate := 0.0
var m_ParticleInitialRotationRange := 0.0
var m_RandomizeAlpha := false
var m_SprayRateMultiplier := 0.0
var m_RotationVariance := 0.0
var m_PositionVariance := 0.0
var m_SizeRatio := Vector2.ZERO
var m_M11Compatibility := false
var m_SolidMinLengthMeters_PS := 0.002
var m_TubeStoreRadiusInTexcoord0Z := false
var m_RenderBackfaces := false
var m_BackIsInvisible := false
var m_BackfaceHueShift := 0.0
var m_BoundsPadding := 0.0
var prefab_fields := {}

func description() -> String:
	return m_DurableName

func pressure_size_min(preview_mode: bool) -> float:
	return m_PreviewPressureSizeMin if preview_mode else m_PressureSizeRange.x

func _to_string() -> String:
	return "BrushDescriptor<%s %s %s>" % [name, description(), m_Guid]
