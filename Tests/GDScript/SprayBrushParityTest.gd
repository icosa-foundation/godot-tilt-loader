extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_spray_salt_wraps_like_open_brush()
	_check_spawn_interval_uses_pressured_size_and_spray_rate()
	_check_spray_geometry()
	_check_spray_single_sided_geometry()
	_check_randomized_particle_layout_branches()
	_check_spray_batched_finalize()
	_check_preview_decay_bookkeeping()
	if _failures == 0:
		print("GDSCRIPT_PARITY_SPRAYBRUSH: all checks passed")

func _check_spray_salt_wraps_like_open_brush() -> void:
	var brush := SprayBrush.new()
	_expect_equal(brush.calculate_salt(3, 0), 360, "spray salt base")
	_expect_equal(brush.calculate_salt(3, SprayBrush.K_SALT_MAX_QUADS_PER_KNOT), 360, "spray salt wraps at salt max quads")
	_expect_equal(brush.calculate_salt(3, SprayBrush.K_SALT_MAX_QUADS_PER_KNOT + 1), 370, "spray salt wraps next quad")
	brush.m_DecayedKnots = 2
	_expect_equal(brush.calculate_salt(3, 0), 600, "spray salt includes decayed knots")
	brush.free()

func _check_spawn_interval_uses_pressured_size_and_spray_rate() -> void:
	var brush := _make_spray_brush(true)
	brush.m_Desc.m_PressureSizeRange = Vector2(0.4, 1.0)
	brush.m_Desc.m_SprayRateMultiplier = 2.5

	_expect_close(brush.get_spawn_interval(0.0), 0.16, "spray spawn interval minimum pressure")
	_expect_close(brush.get_spawn_interval(0.5), 0.28, "spray spawn interval interpolated pressure")
	_expect_close(brush.get_spawn_interval(1.0), 0.4, "spray spawn interval full pressure")
	brush.free()

func _check_spray_geometry() -> void:
	var brush := _make_spray_brush(true)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "spray update keeps")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "spray knot invariants")
	_expect_equal(brush.NS, 2, "spray double-sided stride")
	_expect_equal(brush.m_knots[1].nVert, 16, "spray spawned two double-sided quads")
	_expect_equal(brush.m_geometry.num_verts(), 16, "spray vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 24, "spray tri index count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 2, 6, 7, 3, 1], "spray double-sided first tri")

	_expect_vec3_close(brush.m_geometry.m_Vertices[SprayBrush.BR * brush.NS], Vector3(-0.5, 0.5, 0.0), "spray first br")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SprayBrush.BL * brush.NS], Vector3(-0.5, -0.5, 0.0), "spray first bl")
	_expect_vec3_close(brush.m_geometry.m_Vertices[SprayBrush.FR * brush.NS], Vector3(0.5, 0.5, 0.0), "spray first fr")
	_expect_vec3_close(brush.m_geometry.m_Vertices[8 + SprayBrush.BR * brush.NS], Vector3(0.5, 0.5, 0.0), "spray second br")
	_expect_vec3_close(brush.m_geometry.m_Vertices[8 + SprayBrush.FR * brush.NS], Vector3(1.5, 0.5, 0.0), "spray second fr")
	_expect_vec3_close(brush.m_geometry.m_Normals[0], Vector3.FORWARD, "spray normal")
	_expect_vec3_close(brush.m_geometry.m_Normals[1], -Vector3.FORWARD, "spray backface normal")
	_expect_color_close(brush.m_geometry.m_Colors[0], _color32(Color(0.9, 0.4, 0.1, 1.0)), "spray color32 color")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[SprayBrush.BL * brush.NS], Vector2(0.0, 0.0), "spray uv bl")
	_expect_equal(brush.m_geometry.m_Texcoord0.v2[SprayBrush.FR * brush.NS], Vector2(1.0, 1.0), "spray uv fr")
	_expect_close(brush.m_geometry.m_Tangents[0].length(), sqrt(2.0), "spray tangent length includes handedness")
	_expect_close(brush.m_geometry.m_Tangents[0].w, -1.0, "spray tangent handedness")
	_expect_close(brush.m_geometry.m_Tangents[1].w, 1.0, "spray backface tangent handedness")
	_expect(brush.needs_straight_edge_proxy(), "spray straight edge proxy")
	_expect(not brush.always_rebuild_preview_brush(), "spray no preview rebuild")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 16, "spray finalized vertex count")
	_expect(brush.m_geometry == null, "spray releases geometry")
	brush.free()

func _check_spray_single_sided_geometry() -> void:
	var brush := _make_spray_brush(false)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "spray single-sided update keeps")
	brush.apply_changes_to_visuals()

	_expect_equal(brush.NS, 1, "spray single-sided stride")
	_expect_equal(brush.m_geometry.num_verts(), 8, "spray single-sided vertex count")
	_expect_equal(brush.m_geometry.num_tri_indices(), 12, "spray single-sided tri index count")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 1, 3, 0, 3, 2], "spray single-sided first tri")
	brush.free()

func _check_randomized_particle_layout_branches() -> void:
	var brush := _make_spray_brush(true)
	brush.m_Desc.m_TextureAtlasV = 4
	brush.m_Desc.m_RotationVariance = 40.0
	brush.m_Desc.m_PositionVariance = 0.25
	brush.m_Desc.m_SizeRatio = Vector2(1.4, 0.6)
	brush.m_Desc.m_RandomizeAlpha = true
	brush.m_Desc.m_PressureSizeRange = Vector2(0.5, 1.0)
	brush.m_Desc.m_PressureOpacityRange = Vector2(0.2, 0.8)
	brush.m_Desc.m_Opacity = 0.75
	brush.m_Desc.m_SizeVariance = 0.3
	brush.m_Desc.m_SprayRateMultiplier = 1.0

	_expect(brush.update_position_ls(TrTransform.trs(Vector3(3.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 0.5), "spray randomized update keeps")
	brush.apply_changes_to_visuals()

	var knot_index := 1
	var knot := brush.m_knots[knot_index]
	var min_distance_to_spawn := brush.get_spawn_interval(knot.smoothedPressure)
	_expect_equal(knot.nVert, 32, "spray randomized four double-sided quads")

	for quad in range(2):
		var expected := _expected_spray_quad(brush, knot_index, quad, Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.RIGHT * min_distance_to_spawn * quad)
		var vert_index := knot.iVert + quad * SprayBrush.K_VERTS_IN_SOLID * brush.NS
		_expect_vec3_close(brush.m_geometry.m_Vertices[vert_index + SprayBrush.BR * brush.NS], expected.br, "spray randomized quad %d br" % quad)
		_expect_vec3_close(brush.m_geometry.m_Vertices[vert_index + SprayBrush.BL * brush.NS], expected.bl, "spray randomized quad %d bl" % quad)
		_expect_vec3_close(brush.m_geometry.m_Vertices[vert_index + SprayBrush.FR * brush.NS], expected.fr, "spray randomized quad %d fr" % quad)
		_expect_vec3_close(brush.m_geometry.m_Vertices[vert_index + SprayBrush.FL * brush.NS], expected.fl, "spray randomized quad %d fl" % quad)
		_expect_close(brush.m_geometry.m_Colors[vert_index].a, expected.alpha, "spray randomized quad %d color32 alpha" % quad)
		_expect_equal(brush.m_geometry.m_Texcoord0.v2[vert_index + SprayBrush.BL * brush.NS], expected.uv_bl, "spray randomized quad %d atlas bl" % quad)
		_expect_equal(brush.m_geometry.m_Texcoord0.v2[vert_index + SprayBrush.FR * brush.NS], expected.uv_fr, "spray randomized quad %d atlas fr" % quad)
		_expect_vec3_close(Vector3(brush.m_geometry.m_Tangents[vert_index].x, brush.m_geometry.m_Tangents[vert_index].y, brush.m_geometry.m_Tangents[vert_index].z), expected.tangent, "spray randomized quad %d tangent" % quad)
		_expect_close(brush.m_geometry.m_Tangents[vert_index].w, -1.0, "spray randomized quad %d tangent sign" % quad)
		_expect_close(brush.m_geometry.m_Tangents[vert_index + 1].w, 1.0, "spray randomized quad %d backface tangent sign" % quad)
	brush.free()

func _check_spray_batched_finalize() -> void:
	var brush := _make_spray_brush(true)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "spray batched update keeps")
	brush.apply_changes_to_visuals()
	brush.finalize_for_runtime()

	_expect_equal(brush.mesh_data.vertices.size(), 16, "spray batched finalized vertex count")
	_expect_equal(brush.mesh_data.triangles.size(), 24, "spray batched finalized tri count")
	_expect(brush.m_geometry == null, "spray batched releases geometry")
	brush.free()

func _check_preview_decay_bookkeeping() -> void:
	var brush := _make_spray_brush(true)
	brush.set_preview_mode()
	brush.reset_brush_for_preview(TrTransform.identity())
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "spray preview update keeps")
	_expect_equal(brush.m_DecayTimers.size(), 1, "spray preview decay timer")
	var initial_knots := brush.m_knots.size()
	brush.m_DecayTimers[0] = BaseBrushScript.K_PREVIEW_DURATION - 0.001
	brush.m_LastDecayTimeSeconds = SprayBrush._current_decay_time_seconds() - 0.01

	brush.decay_brush()

	_expect_equal(brush.m_DecayTimers.size(), 0, "spray preview decay removes expired timer")
	_expect_equal(brush.m_DecayedKnots, 1, "spray preview decay increments decayed knot count")
	_expect_equal(brush.m_knots.size(), initial_knots - 1, "spray preview decay shifts initial knot")
	brush.free()

func _expected_spray_quad(brush: SprayBrush, knot_index: int, quad_index: int, move_direction: Vector3, right: Vector3, surface: Vector3, last_spawn_pos: Vector3) -> Dictionary:
	var salt := brush.calculate_salt(knot_index, quad_index)
	var facing := move_direction
	var rotated_right := right
	if brush.m_Desc.m_RotationVariance > 0.0001:
		var rotate := Quaternion(surface.normalized(), deg_to_rad(brush.m_rng.in_range(salt + SprayBrush.K_SALT_ROTATION, -brush.m_Desc.m_RotationVariance, brush.m_Desc.m_RotationVariance)))
		rotated_right = rotate * rotated_right
		facing = rotate * facing

	var pressure := brush.m_knots[knot_index].smoothedPressure
	var size := brush.pressured_random_size(pressure, salt + SprayBrush.K_SALT_PRESSURE)
	var random_offset := brush.m_rng.in_unit_sphere(salt + SprayBrush.K_SALT_POSITION)
	random_offset.z = -random_offset.z
	var center := last_spawn_pos + size * brush.m_Desc.m_PositionVariance * random_offset
	var forward_offset := facing * size * brush.m_Desc.m_SizeRatio.x * 0.5
	var right_offset := rotated_right * size * brush.m_Desc.m_SizeRatio.y * 0.5
	var alpha := _color32_channel(brush.m_rng.in_range(salt + SprayBrush.K_SALT_ALPHA, 0.0, 1.0))
	var atlas_offset := _spray_atlas_offset(brush, salt)
	var tangent := (facing * size * brush.m_Desc.m_SizeRatio.x).normalized()
	return {
		"br": center - forward_offset + right_offset,
		"bl": center - forward_offset - right_offset,
		"fr": center + forward_offset + right_offset,
		"fl": center + forward_offset - right_offset,
		"alpha": alpha,
		"uv_bl": SprayBrush.TEXTURE_ATLAS_00 + atlas_offset,
		"uv_fr": SprayBrush.TEXTURE_ATLAS_55 + atlas_offset,
		"tangent": tangent
	}

func _spray_atlas_offset(brush: SprayBrush, salt: int) -> Vector2:
	var rand := brush.m_rng.in_int_range(salt + SprayBrush.K_SALT_ATLAS, 0, 4)
	if rand == 1:
		return SprayBrush.TEXTURE_ATLAS_50
	if rand == 2:
		return SprayBrush.TEXTURE_ATLAS_05
	if rand == 3:
		return SprayBrush.TEXTURE_ATLAS_55
	return SprayBrush.TEXTURE_ATLAS_00

func _make_spray_brush(backfaces: bool) -> SprayBrush:
	var desc := BrushDescriptor.new()
	desc.name = "Splatter"
	desc.m_Guid = "8dc4a70c-d558-4efd-a5ed-d4e860f40dc3"
	desc.m_DurableName = "Splatter"
	desc.m_RenderBackfaces = backfaces
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

	var brush := SprayBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.9, 0.4, 0.1, 1.0)
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
	push_error("GDSCRIPT_PARITY_SPRAYBRUSH: %s" % message)
