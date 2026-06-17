extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_hsl_round_trip()
	_check_hsv_conversion()
	_check_tr_transform_multiply_and_inverse()
	_check_control_point_copy()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SHARED: all checks passed")

func _check_hsl_round_trip() -> void:
	var source := Color(0.2, 0.5, 1.0, 0.75)
	var hsl := HSLColor.from_color(source)
	var round_trip := hsl.to_color()
	_expect_color_close(round_trip, source, "HSL color round trip")

func _check_hsv_conversion() -> void:
	var hsl := HSLColor.from_hsv(2.5, 0.6, 0.8, 0.5)
	var hsv := hsl.to_hsv_values()
	_expect_close(hsv.h, 2.5, "HSV hue")
	_expect_close(hsv.s, 0.6, "HSV saturation")
	_expect_close(hsv.v, 0.8, "HSV value")
	_expect_close(hsl.a, 0.5, "HSV alpha")

func _check_tr_transform_multiply_and_inverse() -> void:
	var parent := TrTransform.trs(Vector3(1.0, 2.0, 3.0), Quaternion(Vector3.UP, PI * 0.5), 2.0)
	var child := TrTransform.trs(Vector3(0.5, 0.0, 0.0), Quaternion(Vector3.RIGHT, PI * 0.25), 0.5)
	var composed := parent.multiplied(child)
	var recovered := TrTransform.inv_mul(parent, composed)

	_expect_vec3_close(recovered.translation, child.translation, "TrTransform inv_mul translation")
	_expect_quat_close(recovered.rotation, child.rotation, "TrTransform inv_mul rotation")
	_expect_close(recovered.scale, child.scale, "TrTransform inv_mul scale")

	var point := Vector3(0.0, 0.0, 1.0)
	var transformed := composed.multiply_point(point)
	var inverse_point := composed.inverse().multiply_point(transformed)
	_expect_vec3_close(inverse_point, point, "TrTransform inverse point")

func _check_control_point_copy() -> void:
	var point := ControlPoint.create(Vector3(1.0, 2.0, 3.0), Quaternion.IDENTITY, 0.5, 42)
	var copy := point.duplicate_point()
	copy.m_Pos.x = 9.0
	_expect_close(point.m_Pos.x, 1.0, "ControlPoint duplicate is independent")
	_expect_close(copy.m_Pressure, 0.5, "ControlPoint duplicate pressure")

func _expect_color_close(actual: Color, expected: Color, label: String) -> void:
	_expect_close(actual.r, expected.r, "%s r" % label)
	_expect_close(actual.g, expected.g, "%s g" % label)
	_expect_close(actual.b, expected.b, "%s b" % label)
	_expect_close(actual.a, expected.a, "%s a" % label)

func _expect_vec3_close(actual: Vector3, expected: Vector3, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)
	_expect_close(actual.z, expected.z, "%s z" % label)

func _expect_quat_close(actual: Quaternion, expected: Quaternion, label: String) -> void:
	var same := (
		is_equal_approx(actual.x, expected.x)
		and is_equal_approx(actual.y, expected.y)
		and is_equal_approx(actual.z, expected.z)
		and is_equal_approx(actual.w, expected.w)
	)
	var negated_same := (
		is_equal_approx(actual.x, -expected.x)
		and is_equal_approx(actual.y, -expected.y)
		and is_equal_approx(actual.z, -expected.z)
		and is_equal_approx(actual.w, -expected.w)
	)
	if not same and not negated_same:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _expect_close(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_SHARED: %s" % message)
