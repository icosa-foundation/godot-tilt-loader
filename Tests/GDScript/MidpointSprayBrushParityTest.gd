extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	App.force_deterministic_birth_time_for_export = true
	_check_spawn_interval_uses_pressured_size_and_spray_rate()
	_check_midpoint_geometry_and_uv1()
	_check_randomized_particle_layout_and_uv1_branches()
	_check_finalize_preserves_generated_particles()
	App.force_deterministic_birth_time_for_export = false
	_check_midpoint_birth_time_in_uv1()
	if _failures == 0:
		print("GDSCRIPT_PARITY_MIDPOINTSPRAY: all checks passed")

func _check_spawn_interval_uses_pressured_size_and_spray_rate() -> void:
	var brush := _make_midpoint_brush()
	brush.m_Desc.m_PressureSizeRange = Vector2(0.4, 1.0)
	brush.m_Desc.m_SprayRateMultiplier = 2.5

	_expect_close(brush.get_spawn_interval(0.0), 0.16, "midpoint spawn interval minimum pressure")
	_expect_close(brush.get_spawn_interval(0.5), 0.28, "midpoint spawn interval interpolated pressure")
	_expect_close(brush.get_spawn_interval(1.0), 0.4, "midpoint spawn interval full pressure")
	brush.free()

func _check_midpoint_geometry_and_uv1() -> void:
	var brush := _make_midpoint_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "midpoint update keeps")
	brush.apply_changes_to_visuals()

	var layout := brush.get_vertex_layout(brush.m_Desc)
	_expect_equal(layout.texcoord1.size, 4, "midpoint uv1 size")
	_expect_equal(layout.texcoord1.semantic, GeometryPool.Semantic.VECTOR, "midpoint uv1 semantic")
	_expect_equal(brush.NS, 1, "midpoint single-sided stride")
	_expect_equal(brush.m_geometry.num_verts(), 8, "midpoint vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 12, "midpoint tri count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 1, 3, 0, 3, 2], "midpoint first tris")

	_expect_vec3_close(brush.m_geometry.m_Vertices[MidpointPlusLifetimeSprayBrush.BR], Vector3(-0.5, 0.5, 0.0), "midpoint first br")
	_expect_vec3_close(brush.m_geometry.m_Vertices[MidpointPlusLifetimeSprayBrush.FL], Vector3(0.5, -0.5, 0.0), "midpoint first fl")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[MidpointPlusLifetimeSprayBrush.BL], Vector2(0.0, 0.0), "midpoint uv0 bl")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[MidpointPlusLifetimeSprayBrush.FR], Vector2(1.0, 1.0), "midpoint uv0 fr")
	_expect_equal(brush.m_geometry.m_Texcoord1.v4[MidpointPlusLifetimeSprayBrush.BR], Vector4(-0.5, 0.5, 0.0, 0.0), "midpoint uv1 br")
	_expect_equal(brush.m_geometry.m_Texcoord1.v4[MidpointPlusLifetimeSprayBrush.FL], Vector4(0.5, -0.5, 0.0, 0.0), "midpoint uv1 fl")
	_expect_close(brush.m_geometry.m_Tangents[0].length(), sqrt(2.0), "midpoint tangent length includes handedness")
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.45, 0.8, 0.2, 1.0)), "midpoint color32 color")
	brush.free()

func _check_randomized_particle_layout_and_uv1_branches() -> void:
	var brush := _make_midpoint_brush()
	brush.m_Desc.m_TextureAtlasV = 4
	brush.m_Desc.m_RotationVariance = 35.0
	brush.m_Desc.m_PositionVariance = 0.2
	brush.m_Desc.m_SizeRatio = Vector2(1.25, 0.65)
	brush.m_Desc.m_RandomizeAlpha = true
	brush.m_Desc.m_PressureSizeRange = Vector2(0.5, 1.0)
	brush.m_Desc.m_PressureOpacityRange = Vector2(0.2, 0.8)
	brush.m_Desc.m_Opacity = 0.75
	brush.m_Desc.m_SizeVariance = 0.3
	brush.m_Desc.m_SprayRateMultiplier = 1.0

	_expect(brush.update_position_ls(TrTransform.trs(Vector3(3.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 0.5), "midpoint randomized update keeps")
	brush.apply_changes_to_visuals()

	var knot_index := 1
	var knot := brush.m_knots[knot_index]
	var min_distance_to_spawn := brush.get_spawn_interval(knot.smoothedPressure)
	_expect_equal(knot.nVert, 16, "midpoint randomized four quads")

	for quad in range(2):
		var expected := _expected_midpoint_quad(brush, knot_index, quad, Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.RIGHT * min_distance_to_spawn * quad)
		var vert_index := knot.iVert + quad * MidpointPlusLifetimeSprayBrush.K_VERTS_IN_SOLID * brush.NS
		_expect_vec3_close(brush.m_geometry.m_Vertices[vert_index + MidpointPlusLifetimeSprayBrush.BR], expected.br, "midpoint randomized quad %d br" % quad)
		_expect_vec3_close(brush.m_geometry.m_Vertices[vert_index + MidpointPlusLifetimeSprayBrush.BL], expected.bl, "midpoint randomized quad %d bl" % quad)
		_expect_vec3_close(brush.m_geometry.m_Vertices[vert_index + MidpointPlusLifetimeSprayBrush.FR], expected.fr, "midpoint randomized quad %d fr" % quad)
		_expect_vec3_close(brush.m_geometry.m_Vertices[vert_index + MidpointPlusLifetimeSprayBrush.FL], expected.fl, "midpoint randomized quad %d fl" % quad)
		_expect_vec4_close(brush.m_geometry.m_Texcoord1.v4[vert_index + MidpointPlusLifetimeSprayBrush.BR], expected.uv1_br, "midpoint randomized quad %d uv1 br" % quad)
		_expect_vec4_close(brush.m_geometry.m_Texcoord1.v4[vert_index + MidpointPlusLifetimeSprayBrush.FL], expected.uv1_fl, "midpoint randomized quad %d uv1 fl" % quad)
		_expect_close(brush.m_geometry.m_Colors[vert_index].a, expected.alpha, "midpoint randomized quad %d color32 alpha" % quad)
		_expect_equal(brush.m_geometry.m_Texcoord0.v2[vert_index + MidpointPlusLifetimeSprayBrush.BL], expected.uv_bl, "midpoint randomized quad %d atlas bl" % quad)
		_expect_equal(brush.m_geometry.m_Texcoord0.v2[vert_index + MidpointPlusLifetimeSprayBrush.FR], expected.uv_fr, "midpoint randomized quad %d atlas fr" % quad)
		_expect_vec3_close(Vector3(brush.m_geometry.m_Tangents[vert_index].x, brush.m_geometry.m_Tangents[vert_index].y, brush.m_geometry.m_Tangents[vert_index].z), expected.tangent, "midpoint randomized quad %d tangent" % quad)
	brush.free()

func _check_finalize_preserves_generated_particles() -> void:
	var brush := _make_midpoint_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "midpoint finalize update keeps")
	brush.apply_changes_to_visuals()
	var expected_vertices := brush.m_geometry.m_Vertices.duplicate()
	var expected_uv1 := brush.m_geometry.m_Texcoord1.v4.duplicate()
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), expected_vertices.size(), "midpoint finalize keeps generated particles")
	_expect_equal(brush.mesh_data.triangles.size(), 12, "midpoint finalize tri count")
	_expect_vec3_close(brush.mesh_data.vertices[4], expected_vertices[4], "midpoint finalize preserves second particle br")
	_expect_vec4_close(brush.mesh_data.uv1_v4[4], expected_uv1[4], "midpoint finalize preserves second particle uv1")
	_expect(brush.m_geometry == null, "midpoint releases geometry")
	brush.free()

func _check_midpoint_birth_time_in_uv1() -> void:
	var brush := _make_midpoint_brush()
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "midpoint birth time update keeps")
	brush.apply_changes_to_visuals()
	_expect(brush.m_geometry.m_Texcoord1.v4[MidpointPlusLifetimeSprayBrush.BR].w > 0.0, "midpoint uv1 birth time is positive")
	brush.free()

func _expected_midpoint_quad(brush: MidpointPlusLifetimeSprayBrush, knot_index: int, quad_index: int, move_direction: Vector3, right: Vector3, surface: Vector3, last_spawn_pos: Vector3) -> Dictionary:
	var salt := MidpointPlusLifetimeSprayBrush.K_SALT_MAX_SALTS_PER_QUAD * (knot_index * MidpointPlusLifetimeSprayBrush.K_SALT_MAX_QUADS_PER_KNOT + quad_index)
	var facing := move_direction
	var rotated_right := right
	if brush.m_Desc.m_RotationVariance > 0.0001:
		var rotate := Quaternion(surface.normalized(), deg_to_rad(brush.m_rng.in_range(salt + MidpointPlusLifetimeSprayBrush.K_SALT_ROTATION, -brush.m_Desc.m_RotationVariance, brush.m_Desc.m_RotationVariance)))
		rotated_right = rotate * rotated_right
		facing = rotate * facing

	var pressure := brush.m_knots[knot_index].smoothedPressure
	var size := brush.pressured_random_size(pressure, salt + MidpointPlusLifetimeSprayBrush.K_SALT_PRESSURE)
	var center := last_spawn_pos + size * brush.m_Desc.m_PositionVariance * brush.m_rng.in_unit_sphere(salt + MidpointPlusLifetimeSprayBrush.K_SALT_POSITION)
	var forward_offset := facing * size * brush.m_Desc.m_SizeRatio.x * 0.5
	var right_offset := rotated_right * size * brush.m_Desc.m_SizeRatio.y * 0.5
	var alpha := _color32_channel(brush.m_rng.in_range(salt + MidpointPlusLifetimeSprayBrush.K_SALT_ALPHA, 0.0, 1.0))
	var atlas_offset := _midpoint_atlas_offset(brush, salt)
	var tangent := (facing * size * brush.m_Desc.m_SizeRatio.x).normalized()
	return {
		"br": center - forward_offset + right_offset,
		"bl": center - forward_offset - right_offset,
		"fr": center + forward_offset + right_offset,
		"fl": center + forward_offset - right_offset,
		"uv1_br": Vector4((-forward_offset + right_offset).x, (-forward_offset + right_offset).y, (-forward_offset + right_offset).z, 0.0),
		"uv1_fl": Vector4((forward_offset - right_offset).x, (forward_offset - right_offset).y, (forward_offset - right_offset).z, 0.0),
		"alpha": alpha,
		"uv_bl": MidpointPlusLifetimeSprayBrush.TEXTURE_ATLAS_00 + atlas_offset,
		"uv_fr": MidpointPlusLifetimeSprayBrush.TEXTURE_ATLAS_55 + atlas_offset,
		"tangent": tangent
	}

func _midpoint_atlas_offset(brush: MidpointPlusLifetimeSprayBrush, salt: int) -> Vector2:
	var rand := brush.m_rng.in_int_range(salt + MidpointPlusLifetimeSprayBrush.K_SALT_ATLAS, 0, 4)
	if rand == 1:
		return MidpointPlusLifetimeSprayBrush.TEXTURE_ATLAS_50
	if rand == 2:
		return MidpointPlusLifetimeSprayBrush.TEXTURE_ATLAS_05
	if rand == 3:
		return MidpointPlusLifetimeSprayBrush.TEXTURE_ATLAS_55
	return MidpointPlusLifetimeSprayBrush.TEXTURE_ATLAS_00

func _make_midpoint_brush() -> MidpointPlusLifetimeSprayBrush:
	var desc := BrushDescriptor.new()
	desc.name = "HyperGrid"
	desc.m_Guid = "6a1cf9f9-032c-45ec-9b6e-a6680bee32e9"
	desc.m_DurableName = "HyperGrid"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = 1
	desc.m_SprayRateMultiplier = 1.0
	desc.m_RotationVariance = 0.0
	desc.m_PositionVariance = 0.0
	desc.m_SizeRatio = Vector2(1.0, 1.0)
	desc.m_RandomizeAlpha = false
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0

	var brush := MidpointPlusLifetimeSprayBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.45, 0.8, 0.2, 1.0)
	brush.set_random_seed(0)
	brush.init_brush(desc, TrTransform.identity())
	brush.set_random_seed(0)
	return brush

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

func _expect_vec4_close(actual: Vector4, expected: Vector4, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)
	_expect_close(actual.z, expected.z, "%s z" % label)
	_expect_close(actual.w, expected.w, "%s w" % label)

func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _expect_color_close(actual: Color, expected: Color, label: String) -> void:
	_expect_close(actual.r, expected.r, "%s r" % label)
	_expect_close(actual.g, expected.g, "%s g" % label)
	_expect_close(actual.b, expected.b, "%s b" % label)
	_expect_close(actual.a, expected.a, "%s a" % label)

func _color32_channel(value: float) -> float:
	return float(int(clamp(value, 0.0, 1.0) * 255.0)) / 255.0

func _color32(value: Color) -> Color:
	return Color(
		_color32_channel(value.r),
		_color32_channel(value.g),
		_color32_channel(value.b),
		_color32_channel(value.a)
	)

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_MIDPOINTSPRAY: %s" % message)
