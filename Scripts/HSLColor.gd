class_name HSLColor
extends RefCounted

const HUE_MAX := 6.0

var h: float
var s: float
var l: float
var a: float

static func create(hue: float, saturation: float, lightness: float, alpha: float = 1.0) -> HSLColor:
	var result := HSLColor.new()
	result.h = _wrap_hue(hue)
	result.s = saturation
	result.l = lightness
	result.a = alpha
	return result

static func from_color(color: Color) -> HSLColor:
	var min_value: float = min(min(color.r, color.g), color.b)
	var clamped_color := color
	if min_value > 1.0:
		push_error("HSL cannot handle HDR color")
		clamped_color.r = min(clamped_color.r, 1.0)
		clamped_color.g = min(clamped_color.g, 1.0)
		clamped_color.b = min(clamped_color.b, 1.0)
		clamped_color.a = min(clamped_color.a, 1.0)

	var max_value: float = max(max(clamped_color.r, clamped_color.g), clamped_color.b)
	var delta: float = max_value - min_value
	var hue := 0.0
	var saturation := 0.0
	var lightness: float = (max_value + min_value) * 0.5

	if delta != 0.0:
		if lightness < 0.5:
			saturation = delta / (max_value + min_value)
		else:
			saturation = delta / (2.0 - max_value - min_value)

		if clamped_color.r == max_value:
			hue = (clamped_color.g - clamped_color.b) / delta
		elif clamped_color.g == max_value:
			hue = 2.0 + (clamped_color.b - clamped_color.r) / delta
		elif clamped_color.b == max_value:
			hue = 4.0 + (clamped_color.r - clamped_color.g) / delta

	return HSLColor.create(hue * HUE_MAX / 6.0, saturation, lightness, clamped_color.a)

static func from_hsv(hue: float, saturation: float, value: float, alpha: float = 1.0) -> HSLColor:
	var result := HSLColor.new()
	result.h = _wrap_hue(hue)
	result.a = alpha
	result.l = value - 0.5 * saturation * value
	if result.l <= 0.5:
		result.s = saturation / (2.0 - saturation)
	elif saturation == 0.0:
		result.s = 0.0
	else:
		var vs := value * saturation
		var value_inverse := 1.0 - value
		result.s = vs / (2.0 * value_inverse + vs)
	return result

static func _wrap_hue(value: float) -> float:
	var wrapped := fmod(value, HUE_MAX)
	if wrapped < 0.0:
		wrapped += HUE_MAX
	return wrapped

static func _color_calc(component: float, t1: float, t2: float) -> float:
	if component < 0.0:
		component += 6.0
	elif component >= 6.0:
		component -= 6.0

	if component < 1.0:
		return t1 + (t2 - t1) * component
	if component < 3.0:
		return t2
	if component < 4.0:
		return t1 + (t2 - t1) * (4.0 - component)
	return t1

func get_hue_degrees() -> float:
	return h * (360.0 / HUE_MAX)

func set_hue_degrees(value: float) -> void:
	h = _wrap_hue((value * HUE_MAX) / 360.0)

func get_hue01() -> float:
	return h * (1.0 / HUE_MAX)

func set_hue01(value: float) -> void:
	h = _wrap_hue(value * HUE_MAX)

func to_color() -> Color:
	if s == 0.0:
		return Color(l, l, l, a)

	var t2: float
	if l < 0.5:
		t2 = l * (1.0 + s)
	else:
		t2 = (l + s) - (l * s)
	var t1 := 2.0 * l - t2
	var th := h * (6.0 / HUE_MAX)
	return Color(
		_color_calc(th + 2.0, t1, t2),
		_color_calc(th, t1, t2),
		_color_calc(th - 2.0, t1, t2),
		a
	)

func get_base_color() -> HSLColor:
	return HSLColor.create(h, s, 0.5, a)

func to_hsv_values() -> Dictionary:
	var out_value: float
	var out_saturation: float
	if l <= 0.5:
		out_value = l + s * l
		out_saturation = 2.0 * s / (1.0 + s)
	else:
		var slinv := s * (1.0 - l)
		out_value = l + slinv
		out_saturation = 2.0 * slinv / (l + slinv)
	return {"h": h, "s": out_saturation, "v": out_value}

func _to_string() -> String:
	return "HSLA(%.3f, %.3f, %.3f, %.3f)" % [h, s, l, a]
