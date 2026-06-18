class_name QuaternionUtils
extends RefCounted

static func angle_axis_rad(angle: float, axis: Vector3) -> Quaternion:
	return Quaternion(axis.normalized(), angle)

static func log_quat(q: Quaternion) -> Quaternion:
	var vec_len_sq := q.x * q.x + q.y * q.y + q.z * q.z
	var len_sq := vec_len_sq + q.w * q.w
	if abs(len_sq - 1.0) > 3e-3:
		push_error("Quaternion must be unit")
		return Quaternion.IDENTITY

	var sin_theta := sqrt(vec_len_sq)
	var theta := atan2(sin_theta, q.w)
	if sin_theta < 1e-5:
		if q.w > 0.0:
			return Quaternion(q.x, q.y, q.z, 0.0)
		var axis := Vector3(q.x, q.y, q.z).normalized()
		if axis == Vector3.ZERO:
			axis = Vector3.UP
		axis *= theta
		return Quaternion(axis.x, axis.y, axis.z, 0.0)

	var k := theta / sin_theta
	return Quaternion(k * q.x, k * q.y, k * q.z, 0.0)

static func exp_quat(q: Quaternion) -> Quaternion:
	if q.w != 0.0:
		push_error("Quaternion must be pure (w=0)")
		return Quaternion.IDENTITY

	var v := Vector3(q.x, q.y, q.z)
	var v_len := v.length()
	var sin_v_over_v: float
	if v_len < 1e-4:
		sin_v_over_v = v_len
	else:
		sin_v_over_v = sin(v_len) / v_len
	v *= sin_v_over_v
	return Quaternion(v.x, v.y, v.z, cos(v_len))

static func negated(q: Quaternion) -> Quaternion:
	return Quaternion(-q.x, -q.y, -q.z, -q.w)

static func imaginary(q: Quaternion) -> Vector3:
	return Vector3(q.x, q.y, q.z)

static func true_inverse(q: Quaternion) -> Quaternion:
	var sqr_magnitude := q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w
	var factor := 1.0 / sqr_magnitude
	return Quaternion(-q.x * factor, -q.y * factor, -q.z * factor, q.w * factor)

static func dot(a: Quaternion, b: Quaternion) -> float:
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w

static func slerp(a: Quaternion, b: Quaternion, amount: float) -> Quaternion:
	return a.slerp(b, amount)

static func from_to_rotation(from_direction: Vector3, to_direction: Vector3) -> Quaternion:
	var from_normalized := from_direction.normalized()
	var to_normalized := to_direction.normalized()
	if from_normalized == Vector3.ZERO or to_normalized == Vector3.ZERO:
		return Quaternion.IDENTITY
	var cos_theta := from_normalized.dot(to_normalized)
	if cos_theta >= 1.0 - 1e-6:
		return Quaternion.IDENTITY
	if cos_theta < -1.0 + 1e-6:
		var axis := Vector3.RIGHT.cross(from_normalized)
		if axis.length_squared() < 1e-6:
			axis = Vector3.UP.cross(from_normalized)
		return Quaternion(axis.normalized(), PI)
	var axis := from_normalized.cross(to_normalized)
	var s := sqrt((1.0 + cos_theta) * 2.0)
	var inv_s := 1.0 / s
	return Quaternion(axis.x * inv_s, axis.y * inv_s, axis.z * inv_s, s * 0.5).normalized()
