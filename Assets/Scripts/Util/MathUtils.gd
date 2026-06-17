class_name MathUtils
extends RefCounted

static func constrain_rotation_delta(q0: Quaternion, q1: Quaternion, axis: Vector3) -> Quaternion:
	if QuaternionUtils.dot(q0, q1) < 0.0:
		q1 = QuaternionUtils.negated(q1)
	axis = axis.normalized()
	var adjust := q1 * q0.inverse()
	var ln_adjust := QuaternionUtils.imaginary(QuaternionUtils.log_quat(adjust))
	ln_adjust = axis * axis.dot(ln_adjust)
	return QuaternionUtils.exp_quat(Quaternion(ln_adjust.x, ln_adjust.y, ln_adjust.z, 0.0))

static func two_point_object_transformation_no_scale(
	grip_l0: TrTransform,
	grip_r0: TrTransform,
	grip_l1: TrTransform,
	grip_r1: TrTransform,
	obj0: TrTransform,
	constraint_position_t: float
) -> TrTransform:
	var vlr0 := grip_r0.translation - grip_l0.translation
	var vlr1 := grip_r1.translation - grip_l1.translation
	var pivot0 := grip_l0.translation.lerp(grip_r0.translation, constraint_position_t)
	var xf_delta := TrTransform.trs(
		(grip_l1.translation - grip_l0.translation).lerp(grip_r1.translation - grip_r0.translation, constraint_position_t),
		QuaternionUtils.from_to_rotation(vlr0, vlr1),
		1.0
	)
	var delta_l := constrain_rotation_delta(grip_l0.rotation, grip_l1.rotation, vlr0)
	var delta_r := constrain_rotation_delta(grip_r0.rotation, grip_r1.rotation, vlr0)
	xf_delta = TrTransform.r(QuaternionUtils.slerp(delta_l, delta_r, 0.5)).multiplied(xf_delta)
	xf_delta = xf_delta.transform_by(TrTransform.t(pivot0))
	return xf_delta.multiplied(obj0)

static func solve_quadratic(a: float, b: float, c: float) -> Dictionary:
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return {"ok": false, "r0": NAN, "r1": NAN}
	var q: float = -0.5 * (b + sign(b) * sqrt(discriminant))
	var ra: float = q / a
	var rb: float = c / q
	if ra < rb:
		return {"ok": true, "r0": ra, "r1": rb}
	return {"ok": true, "r0": rb, "r1": ra}

static func transform_vector3_as_point(xf: TrTransform, start_index: int, end_index: int, values: Array[Vector3]) -> void:
	for index in range(start_index, end_index):
		values[index] = xf.multiply_point(values[index])

static func transform_vector3_as_vector(xf: TrTransform, start_index: int, end_index: int, values: Array[Vector3]) -> void:
	for index in range(start_index, end_index):
		values[index] = xf.multiply_vector(values[index])

static func transform_vector3_as_z_distance(scale: float, start_index: int, end_index: int, values: Array[Vector3]) -> void:
	for index in range(start_index, end_index):
		values[index] = Vector3(values[index].x, values[index].y, scale * values[index].z)

static func transform_vector4_as_point(xf: TrTransform, start_index: int, end_index: int, values: Array[Vector4]) -> void:
	for index in range(start_index, end_index):
		var p := xf.multiply_point(Vector3(values[index].x, values[index].y, values[index].z))
		values[index] = Vector4(p.x, p.y, p.z, values[index].w)

static func transform_vector4_as_vector(xf: TrTransform, start_index: int, end_index: int, values: Array[Vector4]) -> void:
	for index in range(start_index, end_index):
		var v := xf.multiply_vector(Vector3(values[index].x, values[index].y, values[index].z))
		values[index] = Vector4(v.x, v.y, v.z, values[index].w)

static func transform_vector4_as_z_distance(scale: float, start_index: int, end_index: int, values: Array[Vector4]) -> void:
	for index in range(start_index, end_index):
		values[index] = Vector4(values[index].x, values[index].y, scale * values[index].z, values[index].w)

static func compute_minimal_rotation_frame(tangent: Vector3, previous_frame: Variant, bootstrap_orientation: Quaternion) -> Quaternion:
	assert(abs(tangent.length() - 1.0) < 1e-4)
	if previous_frame == null:
		var desired_up := Basis(bootstrap_orientation) * Vector3.UP
		if desired_up.dot(tangent) < 0.01:
			desired_up = Basis(bootstrap_orientation) * Vector3.RIGHT
		return Basis.looking_at(tangent, desired_up).get_rotation_quaternion()
	var n_prev_tangent := Basis(previous_frame as Quaternion) * Vector3.FORWARD * -1.0
	var minimal := QuaternionUtils.from_to_rotation(n_prev_tangent, tangent)
	return (minimal * (previous_frame as Quaternion)).normalized()

static func random_int() -> int:
	var low := randi_range(0, 0xffff)
	var high := randi_range(0, 0xffff)
	var value := ((high << 16) ^ low) & 0xffffffff
	return value if value < 0x80000000 else value - 0x100000000
