extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_particle_geometry()
	_check_finalize_removes_hanging_particle()
	_check_preview_decay_uses_elapsed_time()
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

func _make_genius_brush() -> GeniusParticlesBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "GeniusParticles"
	desc.m_RenderBackfaces = false
	desc.m_BackIsInvisible = false
	desc.m_M11Compatibility = false
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0
	desc.m_ParticleRate = 0.1
	desc.m_ParticleSpeed = 0.0
	desc.m_ParticleInitialRotationRange = 0.0
	desc.m_RandomizeAlpha = false
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

func _expect_close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_GENIUSPARTICLES: %s" % message)
