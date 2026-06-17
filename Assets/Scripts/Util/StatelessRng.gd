class_name StatelessRng
extends RefCounted

const K_LARGEST_FLOAT_LESS_THAN_ONE := 1.0 - pow(0.5, 24.0)
const _TWO_TO_NEGATIVE_32 := 2.3283064365386963e-10

var seed := 0

static func create(seed_value: int) -> StatelessRng:
	var rng := StatelessRng.new()
	rng.seed = seed_value
	return rng

static func uint32_to_float01(value: int) -> float:
	var unsigned_value := _uint32(value)
	var result := float(unsigned_value) * _TWO_TO_NEGATIVE_32
	return min(result, K_LARGEST_FLOAT_LESS_THAN_ONE)

func in01(salt: int) -> float:
	return uint32_to_float01(_lowbias32(_uint32(seed ^ salt)))

func in_range(salt: int, min_value: float, max_value: float) -> float:
	return min_value + (max_value - min_value) * in01(salt)

func in_int_range(salt: int, min_value: int, max_value: int) -> int:
	return min_value + int((max_value - min_value) * in01(salt))

func on_unit_circle(salt: int) -> Vector2:
	var angle := in_range(salt, 0.0, 2.0 * PI)
	return Vector2(sin(angle), cos(angle))

func in_unit_circle(salt: int) -> Vector2:
	return sqrt(in01(salt + 1)) * on_unit_circle(salt)

func on_unit_sphere(salt: int) -> Vector3:
	var u := in_range(salt, -1.0, 1.0)
	var theta := in_range(salt + 1, 0.0, 2.0 * PI)
	var k := sqrt(1.0 - u * u)
	return Vector3(k * cos(theta), k * sin(theta), u)

func in_unit_sphere(salt: int) -> Vector3:
	return pow(in01(salt + 2), 1.0 / 3.0) * on_unit_sphere(salt)

func rotation(salt: int) -> Quaternion:
	var v12 := in_unit_circle(salt)
	var s1 := v12.length_squared()
	var v34 := sqrt(max(1.0 - s1, 0.0)) * on_unit_circle(salt + 2)
	return Quaternion(v12.x, v12.y, v34.x, v34.y)

static func _lowbias32(value: int) -> int:
	var x := _uint32(value)
	x = _uint32(x ^ (x >> 16))
	x = _uint32(x * 0x7feb352d)
	x = _uint32(x ^ (x >> 15))
	x = _uint32(x * 0x846ca68b)
	x = _uint32(x ^ (x >> 16))
	return x

static func _uint32(value: int) -> int:
	return value & 0xffffffff
