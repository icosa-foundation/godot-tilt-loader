extends SceneTree

class PoolProbe:
	var gets := 0
	var puts := 0

	func on_pool_get() -> void:
		gets += 1

	func on_pool_put() -> void:
		puts += 1

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_stateless_rng()
	_check_quaternion_utils()
	_check_math_utils()
	_check_list_utils()
	_check_pool()
	_check_serializable_guid()
	if _failures == 0:
		print("GDSCRIPT_PARITY_UTILS: all checks passed")

func _check_stateless_rng() -> void:
	var rng := StatelessRng.create(12345)
	_expect_close(rng.in01(0), 0.56712323, "StatelessRng in01 salt 0")
	_expect_close(rng.in01(1), 0.7032278, "StatelessRng in01 salt 1")
	_expect_close(rng.in01(2), 0.38056386, "StatelessRng in01 salt 2")
	_expect_close(rng.in01(17), 0.2040678, "StatelessRng in01 salt 17")
	_expect_close(rng.in01(99), 0.627698, "StatelessRng in01 salt 99")
	_expect_close(rng.in01(-7), 0.5647332, "StatelessRng in01 salt -7")
	_expect_close(rng.in_range(17, -2.0, 5.0), -0.57152545, "StatelessRng range")
	_expect_equal(rng.in_int_range(17, 10, 20), 12, "StatelessRng int range")
	var circle := rng.on_unit_circle(17)
	_expect_close(circle.x, 0.9586431213376915, "StatelessRng unit circle x")
	_expect_close(circle.y, 0.28461090265822236, "StatelessRng unit circle y")

func _check_quaternion_utils() -> void:
	var source := Quaternion(Vector3.UP, PI * 0.25)
	var log_value := QuaternionUtils.log_quat(source)
	var round_trip := QuaternionUtils.exp_quat(log_value)
	_expect_quat_close(round_trip.normalized(), source.normalized(), "Quaternion log/exp round trip")
	var inverse := QuaternionUtils.true_inverse(Quaternion(1.0, 2.0, 3.0, 4.0))
	_expect_quat_close(inverse, Quaternion(-1.0 / 30.0, -2.0 / 30.0, -3.0 / 30.0, 4.0 / 30.0), "Quaternion true inverse")

func _check_math_utils() -> void:
	var roots := MathUtils.solve_quadratic(1.0, -3.0, 2.0)
	_expect(roots.ok, "Quadratic has roots")
	_expect_close(roots.r0, 1.0, "Quadratic r0")
	_expect_close(roots.r1, 2.0, "Quadratic r1")

	var no_roots := MathUtils.solve_quadratic(1.0, 0.0, 1.0)
	_expect(not no_roots.ok, "Quadratic no roots")

	var xf := TrTransform.trs(Vector3(1.0, 2.0, 3.0), Quaternion.IDENTITY, 2.0)
	var points: Array[Vector3] = [Vector3.ZERO, Vector3.ONE]
	MathUtils.transform_vector3_as_point(xf, 0, points.size(), points)
	_expect_vec3_close(points[0], Vector3(1.0, 2.0, 3.0), "Transform point 0")
	_expect_vec3_close(points[1], Vector3(3.0, 4.0, 5.0), "Transform point 1")

	var unity_forward := Vector3.FORWARD * -1.0
	var frame := MathUtils.compute_minimal_rotation_frame(unity_forward, null, Quaternion.IDENTITY)
	_expect_vec3_close(Basis(frame) * Vector3.FORWARD * -1.0, unity_forward, "Minimal frame forward")

func _check_list_utils() -> void:
	var values := [1, 2, 3]
	ListUtils.set_count(values, 5, 9)
	_expect_equal(values, [1, 2, 3, 9, 9], "ListUtils set_count grow")
	ListUtils.set_count(values, 2)
	_expect_equal(values, [1, 2], "ListUtils set_count shrink")
	ListUtils.add_range(values, [4, 5, 6, 7], 1, 2)
	_expect_equal(values, [1, 2, 5, 6], "ListUtils add_range")

func _check_pool() -> void:
	var pool := Pool.create(func(): return PoolProbe.new(), 1)
	var first: PoolProbe = pool.get_instance()
	_expect_equal(first.gets, 0, "Pool new instance skips get callback")
	pool.put(first)
	_expect_equal(first.puts, 1, "Pool put callback")
	var second: PoolProbe = pool.get_instance()
	_expect(first == second, "Pool reuses free instance")
	_expect_equal(second.gets, 1, "Pool get callback")

func _check_serializable_guid() -> void:
	var guid := SerializableGuid.create("F5C336CF51084B40ADE9C687504385AB")
	_expect_equal(guid.to_format("D"), "f5c336cf-5108-4b40-ade9-c687504385ab", "Guid D format")
	_expect_equal(guid.to_format("N"), "f5c336cf51084b40ade9c687504385ab", "Guid N format")
	_expect_equal(SerializableGuid.create("not a guid").to_format("D"), "00000000-0000-0000-0000-000000000000", "Guid invalid is empty")

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

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
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_UTILS: %s" % message)
