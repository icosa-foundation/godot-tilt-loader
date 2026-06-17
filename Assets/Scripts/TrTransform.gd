class_name TrTransform
extends RefCounted

var translation: Vector3
var rotation: Quaternion
var scale: float

static func identity() -> TrTransform:
	return TrTransform.from_translation_rotation(Vector3.ZERO, Quaternion.IDENTITY)

static func t(translation_value: Vector3) -> TrTransform:
	return TrTransform.trs(translation_value, Quaternion.IDENTITY, 1.0)

static func r(rotation_value: Quaternion) -> TrTransform:
	return TrTransform.trs(Vector3.ZERO, rotation_value, 1.0)

static func s(scale_value: float) -> TrTransform:
	return TrTransform.trs(Vector3.ZERO, Quaternion.IDENTITY, scale_value)

static func from_translation_rotation(translation_value: Vector3, rotation_value: Quaternion) -> TrTransform:
	return TrTransform.trs(translation_value, rotation_value, 1.0)

static func trs(translation_value: Vector3, rotation_value: Quaternion, scale_value: float) -> TrTransform:
	var result := TrTransform.new()
	result.translation = translation_value
	result.rotation = rotation_value.normalized()
	result.scale = scale_value
	return result

static func from_global_node(node: Node3D) -> TrTransform:
	return TrTransform.trs(node.global_position, node.global_basis.get_rotation_quaternion(), Coords.get_global_uniform_scale(node))

static func from_local_node(node: Node3D) -> TrTransform:
	return TrTransform.trs(node.position, node.quaternion, node.scale.x)

static func inv_mul(a: TrTransform, b: TrTransform) -> TrTransform:
	var a_invrot := a.rotation.inverse()
	return TrTransform.trs(
		Basis(a_invrot) * ((b.translation - a.translation) / a.scale),
		(a_invrot * b.rotation).normalized(),
		b.scale / a.scale
	)

static func lerp(a: TrTransform, b: TrTransform, amount: float) -> TrTransform:
	assert(a.scale > 0.0 and b.scale > 0.0)
	return TrTransform.trs(
		a.translation.lerp(b.translation, amount),
		a.rotation.slerp(b.rotation, amount).normalized(),
		exp(lerpf(log(a.scale), log(b.scale), amount))
	)

func inverse() -> TrTransform:
	var invrot := rotation.inverse()
	var inv_scale := 1.0 / scale
	return TrTransform.trs(Basis(invrot) * translation * -inv_scale, invrot, inv_scale)

func forward() -> Vector3:
	return Basis(rotation) * Vector3.FORWARD * -1.0

func up() -> Vector3:
	return Basis(rotation) * Vector3.UP

func right() -> Vector3:
	return Basis(rotation) * Vector3.RIGHT

func is_finite() -> bool:
	return (
		translation.is_finite()
		and is_finite(rotation.x)
		and is_finite(rotation.y)
		and is_finite(rotation.z)
		and is_finite(rotation.w)
		and is_finite(scale)
	)

func multiplied(rhs: TrTransform) -> TrTransform:
	return TrTransform.trs(
		Basis(rotation) * (rhs.translation * scale) + translation,
		(rotation * rhs.rotation).normalized(),
		scale * rhs.scale
	)

func multiply_point(point: Vector3) -> Vector3:
	return translation + Basis(rotation) * (point * scale)

func multiply_vector(vector: Vector3) -> Vector3:
	return Basis(rotation) * (vector * scale)

func multiply_bivector(vector: Vector3) -> Vector3:
	return Basis(rotation) * (vector * scale * scale)

func multiply_normal(vector: Vector3) -> Vector3:
	return Basis(rotation) * vector

func approximately(rhs: TrTransform) -> bool:
	return translation.is_equal_approx(rhs.translation) and rotation.is_equal_approx(rhs.rotation) and is_equal_approx(scale, rhs.scale)

func exact_equals(rhs: TrTransform) -> bool:
	return translation == rhs.translation and rotation == rhs.rotation and scale == rhs.scale

func transform_by(rhs: TrTransform) -> TrTransform:
	var similar := (rhs.rotation * rotation * rhs.rotation.inverse()).normalized()
	var ret_translation := Basis(similar) * (-scale * rhs.translation)
	ret_translation += Basis(rhs.rotation) * (rhs.scale * translation)
	ret_translation += rhs.translation
	return TrTransform.trs(ret_translation, similar, scale)

func to_global_node(node: Node3D) -> void:
	node.global_position = translation
	node.global_basis = Basis(rotation)
	Coords.set_global_uniform_scale(node, scale)

func to_local_node(node: Node3D) -> void:
	node.position = translation
	node.quaternion = rotation
	node.scale = Vector3.ONE * scale

func _to_string() -> String:
	return "T: %e %e %e\nR: %e %e %e %e\n S: %e" % [
		translation.x, translation.y, translation.z,
		rotation.x, rotation.y, rotation.z, rotation.w,
		scale
	]
