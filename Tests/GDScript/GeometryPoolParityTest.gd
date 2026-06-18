extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_master_brush_defaults()
	_check_geometry_pool_mesh_append_copy()
	_check_geometry_pool_transform_and_shift()
	_check_geometry_pool_append_pool()
	if _failures == 0:
		print("GDSCRIPT_PARITY_GEOMETRY: all checks passed")

func _check_master_brush_defaults() -> void:
	var brush := MasterBrush.new()
	_expect_equal(brush.num_verts(), MasterBrush.K_ACTIVE_STROKE_QUADS * 6, "MasterBrush vertex count")
	_expect_equal(brush.m_Tris.slice(0, 6), [0, 1, 2, 3, 4, 5], "MasterBrush first tris")
	_expect_equal(brush.m_UVs.slice(0, 6), [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
	], "MasterBrush first UV pattern")
	brush.m_Vertices[0] = Vector3.ONE
	brush.reset(1)
	_expect_vec3_close(brush.m_Vertices[0], Vector3.ZERO, "MasterBrush reset clears vertices")

func _check_geometry_pool_mesh_append_copy() -> void:
	var layout := GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV),
		null,
		null,
		true,
		true,
		true
	)
	var pool := GeometryPool.new()
	pool.set_layout(layout)
	var mesh := _make_basic_mesh_data()
	pool.append_mesh_data(mesh)
	_expect(pool.verify_sizes(), "GeometryPool verifies appended mesh sizes")
	_expect_equal(pool.num_verts(), 3, "GeometryPool appended vertex count")
	_expect_equal(pool.num_tri_indices(), 3, "GeometryPool appended tri count")

	var out_mesh := MeshData.new()
	pool.copy_to_mesh_data(out_mesh)
	_expect_equal(out_mesh.triangles, [0, 1, 2], "GeometryPool copy triangles")
	_expect_vec3_close(out_mesh.vertices[1], Vector3(1.0, 0.0, 0.0), "GeometryPool copy vertex")
	_expect_equal(out_mesh.uv0_v2[2], Vector2(0.0, 1.0), "GeometryPool copy uv0")

	var sub_mesh := MeshData.new()
	pool.copy_to_mesh_data(sub_mesh, 1, 2, 1, 2)
	_expect_equal(sub_mesh.triangles, [0, 1], "GeometryPool submesh triangle rebase")
	_expect_equal(sub_mesh.vertices.size(), 2, "GeometryPool submesh vertex count")

func _check_geometry_pool_transform_and_shift() -> void:
	var layout := GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(3, GeometryPool.Semantic.XY_IS_UV_Z_IS_DISTANCE),
		null,
		null,
		true,
		true,
		false
	)
	var pool := GeometryPool.new()
	pool.set_layout(layout)
	pool.set_num_verts(3)
	pool.set_num_tri_indices(3)
	pool.m_Vertices[0] = Vector3(0.0, 0.0, 0.0)
	pool.m_Vertices[1] = Vector3(1.0, 0.0, 0.0)
	pool.m_Vertices[2] = Vector3(0.0, 1.0, 0.0)
	pool.m_Normals[0] = Vector3.UP
	pool.m_Normals[1] = Vector3.UP
	pool.m_Normals[2] = Vector3.UP
	pool.m_Texcoord0.v3[0] = Vector3(0.0, 0.0, 1.0)
	pool.m_Texcoord0.v3[1] = Vector3(1.0, 0.0, 2.0)
	pool.m_Texcoord0.v3[2] = Vector3(0.0, 1.0, 3.0)
	pool.m_Colors[0] = Color.RED
	pool.m_Colors[1] = Color.GREEN
	pool.m_Colors[2] = Color.BLUE
	pool.m_Tris = [0, 1, 2]

	var xf := TrTransform.trs(Vector3(10.0, 0.0, 0.0), Quaternion.IDENTITY, 2.0)
	pool.apply_transform(xf, 0, 3)
	_expect_vec3_close(pool.m_Vertices[1], Vector3(12.0, 0.0, 0.0), "GeometryPool transformed position")
	_expect_vec3_close(pool.m_Texcoord0.v3[2], Vector3(0.0, 1.0, 6.0), "GeometryPool transformed uv distance")

	pool.shift_forward(1, 0)
	_expect_equal(pool.m_Tris, [-1, 0, 1], "GeometryPool shift adjusts indices like C#")
	_expect_equal(pool.num_verts(), 2, "GeometryPool shift vertex count")

func _check_geometry_pool_append_pool() -> void:
	var layout := GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(2, GeometryPool.Semantic.XY_IS_UV),
		null,
		null,
		true,
		true,
		false
	)
	var source := GeometryPool.new()
	source.set_layout(layout)
	source.append_mesh_data(_make_basic_mesh_data(false))

	var dest := GeometryPool.new()
	dest.set_layout(layout)
	dest.append_pool(source, 0, 3, 0, 3, TrTransform.t(Vector3(5.0, 0.0, 0.0)))
	_expect_equal(dest.m_Tris, [0, 1, 2], "GeometryPool append_pool triangles")
	_expect_vec3_close(dest.m_Vertices[0], Vector3(5.0, 0.0, 0.0), "GeometryPool append_pool transform")

func _make_basic_mesh_data(include_tangent: bool = true) -> MeshData:
	var mesh := MeshData.new()
	mesh.vertices = [Vector3.ZERO, Vector3.RIGHT, Vector3.UP]
	mesh.triangles = [0, 1, 2]
	mesh.normals = [Vector3.BACK, Vector3.BACK, Vector3.BACK]
	mesh.uv0_v2 = [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(0.0, 1.0)]
	mesh.colors = [Color.RED, Color.GREEN, Color.BLUE]
	if include_tangent:
		mesh.tangents = [Vector4(1.0, 0.0, 0.0, 1.0), Vector4(1.0, 0.0, 0.0, 1.0), Vector4(1.0, 0.0, 0.0, 1.0)]
	return mesh

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

func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_GEOMETRY: %s" % message)
