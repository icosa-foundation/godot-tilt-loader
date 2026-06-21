extends SceneTree

var _failures := 0

func _init() -> void:
	_check_wide_texcoords_are_preserved()
	quit(1 if _failures > 0 else 0)

func _check_wide_texcoords_are_preserved() -> void:
	var mesh_data := MeshData.new()
	mesh_data.vertices = [Vector3.ZERO, Vector3.RIGHT, Vector3.UP]
	mesh_data.triangles = [0, 1, 2]
	mesh_data.uv0_v3 = [
		Vector3(0.1, 0.2, 0.3),
		Vector3(0.4, 0.5, 0.6),
		Vector3(0.7, 0.8, 0.9),
	]
	mesh_data.uv1_v4 = [
		Vector4(1.1, 1.2, 1.3, 1.4),
		Vector4(1.5, 1.6, 1.7, 1.8),
		Vector4(1.9, 2.0, 2.1, 2.2),
	]
	mesh_data.uv2_v2 = [
		Vector2(3.1, 3.2),
		Vector2(3.3, 3.4),
		Vector2(3.5, 3.6),
	]

	var arrays: Array = mesh_data.to_mesh_arrays()
	_expect(arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array, "uv0 exports Godot UV")
	_expect(arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array, "uv1 exports Godot UV2")
	_expect(arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array, "uv0 wide data exports CUSTOM0")
	_expect(arrays[Mesh.ARRAY_CUSTOM1] is PackedFloat32Array, "uv1 wide data exports CUSTOM1")
	_expect(arrays[Mesh.ARRAY_CUSTOM2] is PackedFloat32Array, "uv2 exports CUSTOM2")

	var uv0: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv1: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var custom0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var custom1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	var custom2: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM2]

	_expect_vec2_close(uv0[1], Vector2(0.4, 0.5), "uv0 xy")
	_expect_vec2_close(uv1[2], Vector2(1.9, 2.0), "uv1 xy")
	_expect_close(custom0[6], 0.6, "custom0 preserves uv0 z")
	_expect_close(custom1[11], 2.2, "custom1 preserves uv1 w")
	_expect_close(custom2[8], 3.5, "custom2 preserves uv2 x")

	var mesh := mesh_data.to_array_mesh()
	_expect_equal(mesh.get_surface_count(), 1, "array mesh surface count")

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _expect_vec2_close(actual: Vector2, expected: Vector2, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)

func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.00001:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("MeshDataArrayExportParityTest: %s" % message)
