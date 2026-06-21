extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	App.force_deterministic_birth_time_for_export = true
	_check_particle_geometry()
	_check_texture_atlas_uvs()
	_check_randomized_alpha_offset_and_roll_formula()
	_check_distance_tracking_spawn_interval_and_straight_edge_proxy()
	_check_finalize_removes_hanging_particle()
	_check_batched_finalize_removes_hanging_particle()
	_check_preview_decay_uses_elapsed_time()
	_check_decay_updates_length_cache_and_salt_offset()
	App.force_deterministic_birth_time_for_export = false
	_check_particle_birth_time_matches_open_brush_sign()
	if _failures == 0:
		print("GDSCRIPT_PARITY_GENIUSPARTICLES: all checks passed")

func _check_particle_geometry() -> void:
	var brush := _make_genius_brush()
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius first update waits for travelled distance")
	brush.apply_changes_to_visuals()

	_expect(brush.check_knot_invariants(), "genius knot invariants")
	_expect_equal(brush.m_geometry.get_layout().texcoord0.size, 4, "genius uv0 size")
	_expect_equal(brush.m_geometry.get_layout().texcoord1.size, 3, "genius uv1 size")
	_expect(not brush.m_geometry.get_layout().bUseTangents, "genius layout omits tangents")
	_expect_equal(brush.m_geometry.num_verts(), 24, "genius vertex count with hanging particle")
	_expect_equal(brush.m_geometry.num_tri_indices(), 36, "genius tri count with hanging particle")
	_expect_equal(brush.m_knots[1].nVert, 24, "genius active knot verts include hanging particle")
	_expect_equal(brush.m_geometry.m_Tris.slice(0, 6), [0, 1, 3, 0, 3, 2], "genius first particle tris")
	_expect_equal(brush.m_geometry.m_Texcoord0.v4.size(), 24, "genius uv0 count")
	_expect_equal(brush.m_geometry.m_Texcoord1.v3.size(), 24, "genius uv1 count")
	_expect_equal(brush.m_geometry.m_Tangents.size(), 0, "genius tangent count")
	_expect_vec3_close(brush.m_geometry.m_Normals[0], brush.m_geometry.m_Texcoord1.v3[0], "genius normal stores center")
	_expect_vec3_close(brush.m_geometry.m_Texcoord1.v3[0], Vector3.ZERO, "genius first particle position")
	_expect_vec3_close(brush.m_geometry.m_Texcoord1.v3[20], Vector3.RIGHT, "genius hanging particle position")
	_expect_close(brush.m_geometry.m_Texcoord0.v4[1].x, 0.0, "genius uv bl x")
	_expect_close(brush.m_geometry.m_Texcoord0.v4[3].x, 1.0, "genius uv fl x")
	_expect_close(brush.m_geometry.m_Texcoord0.v4[0].y, 1.0, "genius uv br y")
	brush.free()

func _check_texture_atlas_uvs() -> void:
	var brush := _make_genius_brush(4)
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius atlas update waits for travelled distance")
	brush.apply_changes_to_visuals()

	var salt := brush.calculate_salt(1, 0)
	var rand := brush.m_rng.in_int_range(salt + GeniusParticlesBrush.K_SALT_ATLAS, 0, 4)
	var offset := GeniusParticlesBrush.TEXTURE_ATLAS_00
	if rand == 1:
		offset = GeniusParticlesBrush.TEXTURE_ATLAS_50
	elif rand == 2:
		offset = GeniusParticlesBrush.TEXTURE_ATLAS_05
	elif rand == 3:
		offset = GeniusParticlesBrush.TEXTURE_ATLAS_55
	var uv0 := Vector4.ZERO
	_expect_vec4_close(brush.m_geometry.m_Texcoord0.v4[GeniusParticlesBrush.BL], GeniusParticlesBrush.TEXTURE_ATLAS_00 + offset + uv0, "genius atlas bl uv")
	_expect_vec4_close(brush.m_geometry.m_Texcoord0.v4[GeniusParticlesBrush.FL], GeniusParticlesBrush.TEXTURE_ATLAS_50 + offset + uv0, "genius atlas fl uv")
	_expect_vec4_close(brush.m_geometry.m_Texcoord0.v4[GeniusParticlesBrush.BR], GeniusParticlesBrush.TEXTURE_ATLAS_05 + offset + uv0, "genius atlas br uv")
	_expect_vec4_close(brush.m_geometry.m_Texcoord0.v4[GeniusParticlesBrush.FR], GeniusParticlesBrush.TEXTURE_ATLAS_55 + offset + uv0, "genius atlas fr uv")
	brush.free()

func _check_randomized_alpha_offset_and_roll_formula() -> void:
	var brush := _make_genius_brush(1, 0.5, true, 0.25, 60.0)
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius random branch update waits for travelled distance")
	brush.apply_changes_to_visuals()

	var knot_index := 1
	var particle_index := 0
	var salt := brush.calculate_salt(knot_index, particle_index)
	var knot := brush.m_knots[knot_index]
	var expected_size := brush.pressured_random_size(knot.smoothedPressure, salt + GeniusParticlesBrush.K_SALT_PRESSURE)
	var expected_center := brush.m_rng.on_unit_sphere(salt + GeniusParticlesBrush.K_SALT_ON_SPHERE) * expected_size * brush.m_ParticleSizeScale
	var expected_alpha := _color32_channel(brush.m_rng.in01(salt + GeniusParticlesBrush.K_SALT_ALPHA))
	var expected_roll := deg_to_rad(brush.m_rng.in_range(salt + GeniusParticlesBrush.K_SALT_ROLL, -30.0, 30.0))

	_expect_vec3_close(brush.m_geometry.m_Normals[GeniusParticlesBrush.BR], expected_center, "genius random offset center")
	_expect_close(brush.m_geometry.m_Colors[GeniusParticlesBrush.BR].a, expected_alpha, "genius randomized alpha color32")
	_expect_close(brush.m_geometry.m_Texcoord0.v4[GeniusParticlesBrush.BR].z, expected_roll, "genius roll packed in uv0 z")
	_expect_vec3_close(brush.m_geometry.m_Texcoord1.v3[GeniusParticlesBrush.BR], Vector3.ZERO, "genius random branch source particle position")
	brush.free()

func _check_distance_tracking_spawn_interval_and_straight_edge_proxy() -> void:
	var brush := _make_genius_brush()
	_expect_close(brush.get_spawn_interval(0.0), brush.m_SpawnInterval, "genius spawn interval ignores pressure")
	_expect(brush.needs_straight_edge_proxy(), "genius needs straight edge proxy")
	_expect_close(brush.m_DistancePointerTravelled, -1.0, "genius initial distance tracking sentinel")
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3(0.4, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "genius distance first update waits")
	_expect_close(brush.m_DistancePointerTravelled, 0.0, "genius first update initializes travelled distance")
	_expect_close(brush.distance_from_knot(brush.m_knots.size() - 2, Vector3(0.4, 9.0, 0.0)), 0.0, "genius current-knot distance uses travelled override")
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3(0.9, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "genius distance second update waits")
	_expect_close(brush.m_DistancePointerTravelled, 0.5, "genius accumulates pointer travel")
	_expect_close(brush.distance_from_knot(brush.m_knots.size() - 2, Vector3(0.9, 9.0, 0.0)), 0.5, "genius current-knot distance tracks pointer travel")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(1.4, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "genius distance third update keeps")
	_expect_close(brush.distance_from_knot(0, Vector3(0.4, 0.0, 0.0)), 0.4, "genius non-current distance uses geometric distance")
	brush.free()

func _check_finalize_removes_hanging_particle() -> void:
	var brush := _make_genius_brush()
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius finalize update waits for travelled distance")
	brush.apply_changes_to_visuals()
	brush.finalize_solitary_brush()

	_expect(brush.m_geometry == null, "genius releases geometry")
	_expect_equal(brush.mesh_data.vertices.size(), 20, "genius finalized vertex count")
	_expect_equal(brush.mesh_data.triangles.size(), 30, "genius finalized tri count")
	_expect_equal(brush.mesh_data.uv0_v4.size(), 20, "genius finalized uv0 count")
	_expect_equal(brush.mesh_data.uv1_v3.size(), 20, "genius finalized uv1 count")
	_expect_vec3_close(brush.mesh_data.uv1_v3[16], Vector3.ZERO, "genius single-stroke final particle reset to initial position")
	brush.free()

func _check_batched_finalize_removes_hanging_particle() -> void:
	var brush := _make_genius_brush()
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius batched finalize update waits for travelled distance")
	brush.apply_changes_to_visuals()
	brush.finalize_for_runtime()

	_expect(brush.m_geometry == null, "genius batched releases geometry")
	_expect_equal(brush.mesh_data.vertices.size(), 20, "genius batched finalized vertex count")
	_expect_equal(brush.mesh_data.triangles.size(), 30, "genius batched finalized tri count")
	_expect_equal(brush.mesh_data.uv0_v4.size(), 20, "genius batched finalized uv0 count")
	_expect_equal(brush.mesh_data.uv1_v3.size(), 20, "genius batched finalized uv1 count")
	_expect_vec3_close(brush.mesh_data.uv1_v3[16], Vector3.ZERO, "genius batched single-stroke final particle reset to initial position")
	brush.free()

func _check_preview_decay_uses_elapsed_time() -> void:
	var brush := _make_genius_brush()
	brush.set_preview_mode()
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius preview first update waits")
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "genius preview second update tracks travel")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(3.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "genius preview third update keeps")
	brush.apply_changes_to_visuals()
	_expect_equal(brush.m_DecayTimers.size(), 1, "genius preview creates one decay timer")
	var initial_knots := brush.m_knots.size()
	brush.m_DecayTimers[0] = BaseBrushScript.K_PREVIEW_DURATION - 0.001
	brush.m_LastDecayTimeSeconds = GeniusParticlesBrush._current_decay_time_seconds() - 0.01

	brush.decay_brush()

	_expect_equal(brush.m_DecayTimers.size(), 0, "genius preview decay removes expired timer")
	_expect_equal(brush.m_DecayedKnots, 1, "genius preview decay increments decayed knot count")
	_expect_equal(brush.m_knots.size(), initial_knots - 1, "genius preview decay shifts initial knot")
	brush.free()

func _check_decay_updates_length_cache_and_salt_offset() -> void:
	var brush := _make_genius_brush()
	brush.set_preview_mode()
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius decay cache first update waits")
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "genius decay cache second update tracks travel")
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(3.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "genius decay cache third update keeps")
	brush.apply_changes_to_visuals()
	_expect_equal(brush.m_DecayTimers.size(), 1, "genius decay cache setup timer count")
	brush.stroke_length_at_knot(brush.m_knots.size() - 1)
	var length_before := brush.m_LengthsAtKnot[1]
	var expected_reduction := floorf(length_before / brush.m_SpawnInterval) * brush.m_SpawnInterval
	var expected_salt := GeniusParticlesBrush.K_SALT_MAX_SALTS_PER_PARTICLE * ((1 + 1) * GeniusParticlesBrush.K_SALT_MAX_PARTICLES_PER_KNOT + 0)
	brush.m_DecayTimers[0] = BaseBrushScript.K_PREVIEW_DURATION - 0.001
	brush.m_LastDecayTimeSeconds = GeniusParticlesBrush._current_decay_time_seconds() - 0.01

	brush.decay_brush()

	_expect_equal(brush.calculate_salt(1, 0), expected_salt, "genius decay offsets salt by shifted knot count")
	_expect_close(brush.m_LengthsAtKnot[1], length_before - expected_reduction, "genius decay reduces cached length by spawn interval multiples")
	brush.free()

func _check_particle_birth_time_matches_open_brush_sign() -> void:
	var brush := _make_genius_brush()
	_expect(not brush.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius birth time update waits")
	brush.apply_changes_to_visuals()
	_expect(brush.m_geometry.m_Texcoord0.v4[0].w > 0.0, "genius non-preview birth time is positive")
	brush.free()

	var preview := _make_genius_brush()
	preview.set_preview_mode()
	_expect(not preview.update_position_ls(TrTransform.trs(Vector3.RIGHT, Quaternion.IDENTITY, 1.0), 1.0), "genius preview birth time update waits")
	preview.apply_changes_to_visuals()
	_expect(preview.m_geometry.m_Texcoord0.v4[0].w < 0.0, "genius preview birth time is negative")
	preview.free()

func _make_genius_brush(
	texture_atlas_v: int = 1,
	particle_speed: float = 0.0,
	randomize_alpha: bool = false,
	size_variance: float = 0.0,
	initial_rotation_range: float = 0.0
) -> GeniusParticlesBrush:
	var desc := BrushDescriptor.new()
	desc.name = "Stars"
	desc.m_Guid = "0eb4db27-3f82-408d-b5a1-19ebd7d5b711"
	desc.m_DurableName = "Stars"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = texture_atlas_v
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = size_variance
	desc.m_ParticleRate = 0.1
	desc.m_ParticleSpeed = particle_speed
	desc.m_ParticleInitialRotationRange = initial_rotation_range
	desc.m_RandomizeAlpha = randomize_alpha
	desc.m_BrushSizeRange = Vector2(1.0, 2.0)

	var brush := GeniusParticlesBrush.new()
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color(0.9, 0.7, 0.2, 1.0)
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

func _color32_channel(value: float) -> float:
	return float(int(clamp(value, 0.0, 1.0) * 255.0)) / 255.0

func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_GENIUSPARTICLES: %s" % message)
