extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_position_and_fuse_helpers()
	_check_num_used_verts_edge_cases()
	_check_destroy_releases_master_brush_to_pool()
	_check_preview_reset_layout_and_indices()
	_check_debug_geometry_reports_used_counts()
	_check_spawn_interval_pressure_smoothing_and_out_of_verts()
	_check_small_move_does_not_generate_or_update_spawn()
	_check_preview_move_does_not_commit_spawn_state()
	_check_unitized_uv_brush()
	_check_unitized_uv_complete_layout_and_noops()
	_check_unitized_uv_backfaces()
	_check_stretch_uv_brush()
	_check_stretch_uv_request_union_and_segment_flush()
	_check_stretch_uv_atlas_branch()
	_check_stretch_uv_live_preview_preserves_width_uv()
	_check_distance_uv_brush()
	_check_distance_uv_tangent_request_union_and_preview_reset()
	_check_distance_uv_finalize_flushes_tangents()
	_check_distance_uv_atlas_branch()
	_check_distance_uv_color32_alpha_quantization()
	_check_distance_uv_backfaces()
	_check_append_color32_quantization()
	_check_backface_append_color_pattern()
	_check_backface_append_hue_shift()
	_check_sharp_bend_shrinks_quad_strip()
	_check_double_back_creates_strip_break()
	_check_disabled_strip_break_keeps_single_segment()
	_check_backfaces_follow_fused_front_quads()
	_check_batched_finalization_welds_single_sided_strip()
	_check_batched_weld_preserves_width_uvws()
	_check_batched_finalization_preserves_double_sided_strip()
	if _failures == 0:
		print("GDSCRIPT_PARITY_QUADSTRIP: all checks passed")

func _check_position_and_fuse_helpers() -> void:
	var verts: Array[Vector3] = []
	verts.resize(12)
	var brush := QuadStripBrush.new()
	brush.position_quad(verts, 0, Vector3(2.0, 3.0, 4.0), Vector3.RIGHT, Vector3.UP)
	_expect_vec3_close(verts[0], Vector3(1.0, 2.0, 4.0), "position quad 0")
	_expect_vec3_close(verts[1], Vector3(3.0, 2.0, 4.0), "position quad 1")
	_expect_vec3_close(verts[5], Vector3(3.0, 4.0, 4.0), "position quad 5")

	var normals: Array[Vector3] = []
	normals.resize(12)
	for index in range(normals.size()):
		normals[index] = Vector3.BACK
	brush.fuse_quads(verts, normals, 0, 6, true)
	_expect_vec3_close(verts[1], verts[6], "fuse top")
	_expect_vec3_close(verts[5], verts[8], "fuse bottom")
	brush.free()

func _check_num_used_verts_edge_cases() -> void:
	var single := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	single.m_LeadingQuadIndex = 2
	single.m_LastSegmentLengthSolids = 0
	single.m_LeadingSegmentInitialQuadIndex = null
	_expect_equal(single.get_num_used_verts(), 12, "single-sided drops unattached leading edge only")
	single.m_LastSegmentLengthSolids = 1
	_expect_equal(single.get_num_used_verts(), 6, "single-sided drops previous lone segment")
	single.m_LastSegmentLengthSolids = 0
	single.m_LeadingSegmentInitialQuadIndex = 1
	_expect_equal(single.get_num_used_verts(), 6, "single-sided drops one-solid leading segment")
	single.m_LeadingSegmentInitialQuadIndex = 0
	_expect_equal(single.get_num_used_verts(), 18, "single-sided includes multi-solid leading segment")
	_expect(not single.should_discard(), "single-sided non-empty strip is kept")
	single.m_LeadingQuadIndex = 0
	single.m_LeadingSegmentInitialQuadIndex = null
	_expect(single.should_discard(), "single-sided empty strip is discarded")
	single.free()

	var double := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	double.m_LeadingQuadIndex = 4
	double.m_LastSegmentLengthSolids = 0
	double.m_LeadingSegmentInitialQuadIndex = null
	_expect_equal(double.get_num_used_verts(), 24, "double-sided drops unattached leading edge only")
	double.m_LastSegmentLengthSolids = 1
	_expect_equal(double.get_num_used_verts(), 12, "double-sided drops previous lone segment")
	double.m_LastSegmentLengthSolids = 0
	double.m_LeadingSegmentInitialQuadIndex = 2
	_expect_equal(double.get_num_used_verts(), 12, "double-sided drops one-solid leading segment")
	double.m_LeadingSegmentInitialQuadIndex = 0
	_expect_equal(double.get_num_used_verts(), 36, "double-sided includes multi-solid leading segment")
	double.free()

func _check_destroy_releases_master_brush_to_pool() -> void:
	var previous_pool := MasterBrush.shared_pool
	MasterBrush.shared_pool = Pool.create(func(): return MasterBrush.new())

	var unfinalized := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	_expect_equal(MasterBrush.shared_pool.free_count(), 0, "quad destroy pool starts empty")
	unfinalized.free()
	_expect_equal(MasterBrush.shared_pool.free_count(), 1, "quad destroy releases unfinalized geometry")

	var finalized := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	finalized.finalize_solitary_brush()
	_expect_equal(MasterBrush.shared_pool.free_count(), 1, "quad finalize releases geometry once")
	finalized.free()
	_expect_equal(MasterBrush.shared_pool.free_count(), 1, "quad free after finalize does not double release")

	MasterBrush.shared_pool = previous_pool

func _check_preview_reset_layout_and_indices() -> void:
	var stretch := QuadStripBrushStretchUV.new()
	stretch.m_StoreWidthInTexcoord0Z = true
	var brush := _make_quad_brush(stretch, false)
	brush.m_LeadingQuadIndex = 3
	brush.m_InitialQuadIndex = 2
	brush.m_LastQuadRight = Vector3.RIGHT
	brush.reset_brush_for_preview(TrTransform.identity())
	_expect_equal(brush.m_LeadingQuadIndex, 0, "preview reset clears leading quad index")
	_expect_equal(brush.m_InitialQuadIndex, 0, "preview reset clears initial quad index")
	_expect_vec3_close(brush.m_LastQuadRight, Vector3.ZERO, "preview reset clears last quad right")
	_expect_equal(brush.m_Geometry.vertex_layout.texcoord0.size, 3, "preview reset restores subclass vertex layout")
	_expect(brush.m_Geometry.num_verts() >= 24, "preview reset keeps enough vertices for old leading plus new solid")
	brush.finalize_solitary_brush()
	brush.free()

func _check_debug_geometry_reports_used_counts() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	_seed_two_quads(brush)
	var debug := brush.debug_get_geometry()
	_expect_equal(debug["nVerts"], 12, "debug geometry used vertex count")
	_expect_equal(debug["nTris"], 12, "debug geometry used triangle count")
	_expect(debug["verts"].size() >= debug["nVerts"], "debug geometry exposes full vertex buffer")
	_expect(debug["tris"].size() >= debug["nTris"], "debug geometry exposes full index buffer")
	brush.finalize_solitary_brush()
	brush.free()

func _check_spawn_interval_pressure_smoothing_and_out_of_verts() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	var expected_spawn := QuadStripBrush.K_SOLID_MIN_LENGTH_METERS_PS * App.METERS_TO_UNITS * brush.pointer_to_local()
	expected_spawn += brush.pressured_size(1.0) * QuadStripBrush.K_SOLID_ASPECT_RATIO
	_expect_close(brush.get_spawn_interval(1.0), expected_spawn, "quad strip spawn interval")
	_expect_close(brush.get_smoothed_pressure(0.8, Vector3(10.0, 0.0, 0.0)), 0.8, "quad strip initial pressure is unsmoothed")
	brush.m_LeadingQuadIndex = 1
	brush.m_LastSpawnXf = TrTransform.trs(Vector3.ZERO, Quaternion.IDENTITY, 2.0)
	brush.m_LastSpawnPressure = 0.2
	var distance_m := Vector3(10.0, 0.0, 0.0).length() * App.UNITS_TO_METERS
	var window_m := QuadStripBrush.K_PRESSURE_SMOOTH_WINDOW_METERS_PS * brush.pointer_to_local()
	var k := pow(0.1, distance_m / window_m)
	var expected_pressure := k * 0.2 + (1.0 - k) * 0.8
	_expect_close(brush.get_smoothed_pressure(0.8, Vector3(10.0, 0.0, 0.0)), expected_pressure, "quad strip pressure smoothing")
	brush.set_preview_mode()
	_expect_close(brush.get_smoothed_pressure(0.8, Vector3(10.0, 0.0, 0.0)), 0.8, "quad strip preview pressure is unsmoothed")
	brush.m_NumQuads = 4
	brush.m_LeadingQuadIndex = 2
	_expect(not brush.is_out_of_verts(), "single-sided one quad before out of verts")
	brush.m_LeadingQuadIndex = 3
	_expect(brush.is_out_of_verts(), "single-sided out of verts threshold")
	brush.free()

	var double := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	double.m_NumQuads = 6
	double.m_LeadingQuadIndex = 3
	_expect(not double.is_out_of_verts(), "double-sided one solid before out of verts")
	double.m_LeadingQuadIndex = 4
	_expect(double.is_out_of_verts(), "double-sided out of verts threshold")
	double.free()

func _check_small_move_does_not_generate_or_update_spawn() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	var prior_xf := brush.m_LastSpawnXf
	var threshold := QuadStripBrush.K_MINIMUM_MOVE_LENGTH_METERS_PS * App.METERS_TO_UNITS * brush.pointer_to_local()
	var generated := brush.update_position_ls(TrTransform.trs(Vector3(threshold * 0.5, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	_expect(not generated, "small quad-strip move does not generate")
	_expect_equal(brush.m_LeadingQuadIndex, 0, "small quad-strip move preserves leading index")
	_expect_equal(brush.m_InitialQuadIndex, 0, "small quad-strip move preserves initial index")
	_expect_vec3_close(brush.m_LastSpawnXf.translation, prior_xf.translation, "small quad-strip move preserves last spawn translation")
	_expect_close(brush.m_LastSpawnXf.scale, prior_xf.scale, "small quad-strip move preserves last spawn scale")
	brush.finalize_solitary_brush()
	brush.free()

func _check_preview_move_does_not_commit_spawn_state() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	_expect(brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0), "preview move setup generates first quad")
	var prior_xf := brush.m_LastSpawnXf
	var prior_facing := brush.m_LastFacing
	var prior_center := brush.m_LastQuadCenter
	var prior_forward := brush.m_LastQuadForward
	var prior_right := brush.m_LastQuadRight
	var prior_segment_solids := brush.m_LastSegmentLengthSolids
	var prior_initial := brush.m_InitialQuadIndex
	var prior_leading := brush.m_LeadingQuadIndex
	var preview_delta := brush.get_spawn_interval(1.0) * 0.5
	var generated := brush.update_position_ls(TrTransform.trs(prior_xf.translation + Vector3(preview_delta, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	_expect(not generated, "preview move does not commit a new quad")
	_expect_equal(brush.m_LeadingQuadIndex, prior_leading, "preview move restores leading index")
	_expect_equal(brush.m_InitialQuadIndex, prior_initial, "preview move restores initial index")
	_expect_equal(brush.m_LeadingSegmentInitialQuadIndex, prior_initial, "preview move records temporary leading segment start")
	_expect_equal(brush.m_LastSegmentLengthSolids, prior_segment_solids, "preview move preserves committed segment length")
	_expect_vec3_close(brush.m_LastSpawnXf.translation, prior_xf.translation, "preview move preserves last spawn translation")
	_expect_vec3_close(brush.m_LastFacing, prior_facing, "preview move preserves last facing")
	_expect_vec3_close(brush.m_LastQuadCenter, prior_center, "preview move preserves last quad center")
	_expect_vec3_close(brush.m_LastQuadForward, prior_forward, "preview move preserves last quad forward")
	_expect_vec3_close(brush.m_LastQuadRight, prior_right, "preview move preserves last quad right")
	brush.finalize_solitary_brush()
	brush.free()

func _check_unitized_uv_brush() -> void:
	var brush := _make_quad_brush(QuadStripUnitizedUVBrush.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	_expect_equal(brush.m_Geometry.m_UVs[0], Vector2(0.0, 1.0), "unitized uv 0")
	_expect_equal(brush.m_Geometry.m_UVs[1], Vector2(1.0, 1.0), "unitized uv 1")
	_expect_equal(brush.m_Geometry.m_UVs[5], Vector2(1.0, 0.0), "unitized uv 5")
	_expect_close(brush.m_Geometry.m_Tangents[0].length(), sqrt(2.0), "unitized tangent length includes handedness")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 12, "unitized finalize vertex count")
	_expect(brush.m_Geometry == null, "unitized releases geometry")
	brush.free()

func _check_unitized_uv_complete_layout_and_noops() -> void:
	var brush := _make_quad_brush(QuadStripUnitizedUVBrush.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	var expected := [
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 0.0),
		Vector2(0.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
	]
	for quad in range(2):
		var vert := quad * 6
		for offset in range(6):
			_expect_equal(brush.m_Geometry.m_UVs[vert + offset], expected[offset], "unitized complete uv quad %d offset %d" % [quad, offset])
	var uvs_before := brush.m_Geometry.m_UVs.duplicate()
	var tangents_before := brush.m_Geometry.m_Tangents.duplicate()
	brush.update_uvs_for_quad(0)
	brush.update_uvs_for_segment(0, 2, 1.0)
	_expect_equal(brush.m_Geometry.m_UVs, uvs_before, "unitized per-quad and per-segment hooks are no-op for uvs")
	_expect_equal(brush.m_Geometry.m_Tangents, tangents_before, "unitized per-quad and per-segment hooks are no-op for tangents")
	brush.finalize_solitary_brush()
	brush.free()

func _check_unitized_uv_backfaces() -> void:
	var brush := _make_quad_brush(QuadStripUnitizedUVBrush.new(), true)
	_seed_two_double_sided_solids(brush)
	brush.update_uvs(0, 4, 1.0)
	_expect_backface_uvs_match_front(brush, 0)
	_expect_backface_uvs_match_front(brush, 12)
	_expect_backface_tangents_match_front(brush, 0)
	_expect_backface_tangents_match_front(brush, 12)
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_brush() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.flush_update_uv_request()
	_expect_equal(brush.m_Geometry.m_UVs[0].x, 0.0, "stretch first x")
	_expect_close(brush.m_Geometry.m_UVs[1].x, 0.5, "stretch first end x")
	_expect_close(brush.m_Geometry.m_UVs[7].x, 1.0, "stretch second end x")
	_expect_equal(brush.m_QuadLengths.slice(0, 2), [1.0, 1.0], "stretch quad lengths")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_request_union_and_segment_flush() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs_for_quad(0)
	brush.update_uvs_for_quad(1)
	brush.update_uvs_for_segment(0, 1, 1.0)
	brush.update_uvs_for_segment(0, 2, 1.0)
	_expect_equal(brush._uv_request_back, 0, "stretch request keeps same segment back")
	_expect_equal(brush._uv_request_front, 2, "stretch request unions same segment front")
	brush.update_uvs_for_segment(1, 2, 1.0)
	_expect_equal(brush._uv_request_back, 1, "stretch request flushes when segment back changes")
	_expect_equal(brush._uv_request_front, 2, "stretch request stores new segment front")
	_expect_equal(brush.m_Geometry.m_UVs[0], Vector2(0.0, 0.0), "stretch flushed previous segment uv 0")
	_expect_equal(brush.m_Geometry.m_UVs[1], Vector2(0.5, 0.0), "stretch flushed previous segment uv 1")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_atlas_branch() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	brush.m_Desc.m_TextureAtlasV = 4
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.flush_update_uv_request()
	var random01 := brush.m_rng.in01(0)
	var atlas := int(random01 * brush.m_Desc.m_TextureAtlasV)
	var y_start := atlas / float(brush.m_Desc.m_TextureAtlasV)
	var y_end := (atlas + 1) / float(brush.m_Desc.m_TextureAtlasV)
	_expect_close(brush.m_Geometry.m_UVs[0].y, y_start, "stretch atlas first y")
	_expect_close(brush.m_Geometry.m_UVs[2].y, y_end, "stretch atlas second y")
	_expect_close(brush.m_Geometry.m_UVs[5].y, y_end, "stretch atlas final y")
	brush.finalize_solitary_brush()
	brush.free()

func _check_stretch_uv_live_preview_preserves_width_uv() -> void:
	var stretch_brush := QuadStripBrushStretchUV.new()
	stretch_brush.m_StoreWidthInTexcoord0Z = true
	var brush := _make_quad_brush(stretch_brush, false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.apply_changes_to_visuals()
	_expect_equal(brush.mesh_data.uv0_v2.size(), 0, "stretch preview does not export competing uv0 v2")
	_expect_equal(brush.mesh_data.uv0_v3.size(), 12, "stretch preview exports uv0 v3")
	_expect_close(brush.mesh_data.uv0_v3[0].z, 1.0, "stretch preview exports width in uv0 z")
	var arrays := brush.mesh_data.to_mesh_arrays()
	_expect(arrays[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array, "stretch preview exports uv0 z custom data")
	brush.finalize_solitary_brush()
	brush.free()

func _check_distance_uv_brush() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), false)
	_seed_two_quads(brush)
	brush.m_Geometry.m_Colors[5].a = 0.25
	brush.update_uvs(0, 2, 1.0)
	brush.flush_tangent_request()
	_expect_equal(brush.m_Geometry.m_UVs[0].x, brush.m_Geometry.m_UVs[2].x, "distance trailing u")
	_expect_close(brush.m_Geometry.m_UVs[1].x - brush.m_Geometry.m_UVs[0].x, 1.0, "distance first tile length")
	_expect_close(brush.m_Geometry.m_Colors[0].a, 0.0, "distance trailing start alpha")
	_expect_close(brush.m_Geometry.m_Colors[1].a, 1.0, "distance leading alpha")
	_expect_close(brush.m_Geometry.m_Tangents[0].length(), sqrt(2.0), "distance tangent length includes handedness")
	brush.finalize_solitary_brush()
	brush.free()

func _check_distance_uv_tangent_request_union_and_preview_reset() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), false)
	_seed_two_quads(brush)
	brush.lazy_update_tangents_for_segment(0, 1)
	brush.lazy_update_tangents_for_segment(0, 2)
	_expect_equal(brush._tangent_request_back, 0, "distance tangent request keeps same segment back")
	_expect_equal(brush._tangent_request_front, 2, "distance tangent request unions same segment front")
	brush.lazy_update_tangents_for_segment(1, 2)
	_expect_equal(brush._tangent_request_back, 1, "distance tangent request flushes when segment back changes")
	_expect_equal(brush._tangent_request_front, 2, "distance tangent request stores new segment front")
	_expect(brush.m_Geometry.m_Tangents[0].length() > 0.0, "distance tangent flush computed previous segment")
	brush.reset_brush_for_preview(TrTransform.identity())
	_expect(not brush.has_tangent_request(), "distance preview reset clears pending tangent request")
	brush.finalize_solitary_brush()
	brush.free()

func _check_distance_uv_finalize_flushes_tangents() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	_expect(brush.has_tangent_request(), "distance finalize starts with pending tangent request")
	brush.finalize_solitary_brush()
	_expect_equal(brush.mesh_data.tangents.size(), 12, "distance finalize exports tangents")
	_expect(brush.mesh_data.tangents[0].length() > 0.0, "distance finalize computes tangent")
	brush.free()

func _check_distance_uv_atlas_branch() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), false)
	brush.m_Desc.m_TextureAtlasV = 4
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.flush_tangent_request()
	var random01 := brush.m_rng.in01(0)
	var atlas := int(random01 * 3331.0) % brush.m_Desc.m_TextureAtlasV
	var y_start := atlas / float(brush.m_Desc.m_TextureAtlasV)
	var y_end := (atlas + 1) / float(brush.m_Desc.m_TextureAtlasV)
	_expect_close(brush.m_Geometry.m_UVs[0].x, random01, "distance atlas random u")
	_expect_close(brush.m_Geometry.m_UVs[0].y, y_start, "distance atlas first y")
	_expect_close(brush.m_Geometry.m_UVs[2].y, y_end, "distance atlas second y")
	_expect_close(brush.m_Geometry.m_UVs[5].y, y_end, "distance atlas final y")
	brush.finalize_solitary_brush()
	brush.free()

func _check_distance_uv_color32_alpha_quantization() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), false)
	_seed_two_short_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	var expected_alpha := 122.0 / 255.0
	_expect_close(brush.m_Geometry.m_Colors[6].a, expected_alpha, "distance fade alpha quantizes to Color32")
	_expect_close(brush.m_Geometry.m_Colors[8].a, expected_alpha, "distance fade mirrored trailing alpha quantizes to Color32")
	_expect_close(brush.m_Geometry.m_Colors[7].a, 0.0, "distance leading tip alpha remains zero")
	brush.finalize_solitary_brush()
	brush.free()

func _check_distance_uv_backfaces() -> void:
	var brush := _make_quad_brush(QuadStripBrushDistanceUV.new(), true)
	_seed_two_double_sided_solids(brush)
	brush.update_uvs(0, 4, 1.0)
	brush.flush_tangent_request()
	_expect_backface_uvs_match_front(brush, 0)
	_expect_backface_uvs_match_front(brush, 12)
	_expect_backface_colors_match_front(brush, 0)
	_expect_backface_colors_match_front(brush, 12)
	_expect_backface_tangents_match_front(brush, 0)
	_expect_backface_tangents_match_front(brush, 12)
	brush.finalize_solitary_brush()
	brush.free()

func _check_append_color32_quantization() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	brush.m_Color = Color(0.1, 0.5, 0.9, 0.8)
	brush.append_leading_quad(true, 0.25, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var expected := _color32(Color(0.1, 0.5, 0.9, 0.25))
	var colors := brush.m_Geometry.m_Colors
	_expect_color_close(colors[0], expected, "append color32 trailing 0")
	_expect_color_close(colors[1], expected, "append color32 leading 1")
	brush.append_leading_quad(true, 0.75, Vector3.RIGHT, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var next_expected := _color32(Color(0.1, 0.5, 0.9, 0.75))
	_expect_color_close(colors[6], expected, "append second carries previous edge color")
	_expect_color_close(colors[7], next_expected, "append second leading edge color32")
	brush.finalize_solitary_brush()
	brush.free()

func _check_backface_append_color_pattern() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	brush.m_Color = Color(0.2, 0.5, 1.0, 0.8)
	brush.append_leading_quad(true, 0.25, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var expected := _color32(Color(0.2, 0.5, 1.0, 0.25))
	var colors := brush.m_Geometry.m_Colors
	_expect_color_close(colors[6], expected, "backface append color 0")
	_expect_color_close(colors[7], expected, "backface append color 1")
	_expect_color_close(colors[8], expected, "backface append color 2")
	_expect_color_close(colors[9], expected, "backface append color 3")
	_expect_color_close(colors[10], expected, "backface append color 4")
	_expect_color_close(colors[11], expected, "backface append color 5")
	brush.append_leading_quad(true, 0.75, Vector3.RIGHT, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var next_expected := _color32(Color(0.2, 0.5, 1.0, 0.75))
	_expect_color_close(colors[18], expected, "backface second append color 0")
	_expect_color_close(colors[19], expected, "backface second append color 1")
	_expect_color_close(colors[20], next_expected, "backface second append color 2")
	_expect_color_close(colors[21], expected, "backface second append color 3")
	_expect_color_close(colors[22], next_expected, "backface second append color 4")
	_expect_color_close(colors[23], next_expected, "backface second append color 5")
	brush.finalize_solitary_brush()
	brush.free()

func _check_backface_append_hue_shift() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	brush.m_Color = Color(1.0, 0.0, 0.0, 0.8)
	brush.m_Desc.m_BackfaceHueShift = 120.0
	brush.append_leading_quad(true, 0.25, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, Vector3.UP)
	var shifted := HSLColor.from_color(brush.m_Color)
	shifted.set_hue_degrees(shifted.get_hue_degrees() + brush.m_Desc.m_BackfaceHueShift)
	var expected := _color32(shifted.to_color())
	var colors := brush.m_Geometry.m_Colors
	_expect_color_close(colors[6], expected, "backface hue color 0")
	_expect_color_close(colors[7], expected, "backface hue color 1")
	_expect_color_close(colors[8], expected, "backface hue color 2")
	_expect_color_close(colors[9], expected, "backface hue color 3")
	_expect_color_close(colors[10], expected, "backface hue color 4")
	_expect_color_close(colors[11], expected, "backface hue color 5")
	brush.finalize_solitary_brush()
	brush.free()

func _check_sharp_bend_shrinks_quad_strip() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	brush.m_Desc.m_BackIsInvisible = true
	brush.m_BaseSize_PS = 2.0
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(1.5, 1.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	_expect(brush.m_LastSizeShrink > 0.0, "sharp bend records size shrink")
	_expect(brush.m_LastQuadRight.length() < 1.0, "sharp bend narrows leading quad")
	brush.finalize_solitary_brush()
	brush.free()

func _check_double_back_creates_strip_break() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	brush.m_Desc.m_BackIsInvisible = true
	brush.m_BaseSize_PS = 2.0
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 1.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	_expect_equal(brush.m_InitialQuadIndex, 1, "double-back starts new strip segment")
	_expect_equal(brush.m_LastSegmentLengthSolids, 1, "double-back segment length starts at one")
	_expect_close(brush.m_LastSizeShrink, 0.0, "double-back does not record shrink")
	brush.finalize_solitary_brush()
	brush.free()

func _check_disabled_strip_break_keeps_single_segment() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	brush.m_AllowStripBreak = false
	brush.m_Desc.m_BackIsInvisible = true
	brush.m_BaseSize_PS = 2.0
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 1.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	_expect_equal(brush.m_InitialQuadIndex, 0, "disabled strip break keeps initial segment")
	_expect_equal(brush.m_LastSegmentLengthSolids, 2, "disabled strip break keeps connected segment length")
	_expect_close(brush.m_LastSizeShrink, 0.0, "disabled strip break does not shrink in skipped branch")
	brush.finalize_solitary_brush()
	brush.free()

func _check_backfaces_follow_fused_front_quads() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	brush.m_Desc.m_BackIsInvisible = true
	brush.m_BaseSize_PS = 0.5
	brush.update_position_ls(TrTransform.trs(Vector3(1.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(2.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	brush.update_position_ls(TrTransform.trs(Vector3(3.0, 0.0, 0.0), Quaternion.IDENTITY, 1.0), 1.0)
	for front_quad in range(0, brush.m_LeadingQuadIndex, 2):
		_expect_backface_matches_front(brush, front_quad * 6)
	brush.finalize_solitary_brush()
	brush.free()

func _check_batched_finalization_welds_single_sided_strip() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.flush_update_uv_request()
	brush.finalize_batched_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 6, "batched weld vertex count")
	_expect_equal(brush.mesh_data.triangles.size(), 12, "batched weld triangle index count")
	_expect_equal(brush.mesh_data.uv0_v2.size(), 6, "batched weld uv count")
	_expect_vec3_close(brush.mesh_data.vertices[0], Vector3(0.0, 0.5, 0.0), "batched weld first BR")
	_expect_vec3_close(brush.mesh_data.vertices[1], Vector3(0.0, -0.5, 0.0), "batched weld first BL")
	_expect_vec3_close(brush.mesh_data.vertices[2], Vector3(1.0, 0.5, 0.0), "batched weld first FR")
	_expect_vec3_close(brush.mesh_data.vertices[3], Vector3(1.0, -0.5, 0.0), "batched weld first FL")
	_expect_equal(brush.mesh_data.triangles.slice(0, 6), [0, 1, 3, 0, 3, 2], "batched weld first quad indices")
	_expect_equal(brush.mesh_data.triangles.slice(6, 12), [2, 3, 5, 2, 5, 4], "batched weld second quad indices")
	brush.free()

func _check_batched_weld_preserves_width_uvws() -> void:
	var stretch := QuadStripBrushStretchUV.new()
	stretch.m_StoreWidthInTexcoord0Z = true
	var brush := _make_quad_brush(stretch, false)
	_seed_two_quads(brush)
	brush.update_uvs(0, 2, 1.0)
	brush.flush_update_uv_request()
	brush.finalize_batched_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 6, "batched width weld vertex count")
	_expect_equal(brush.mesh_data.uv0_v2.size(), 0, "batched width weld does not export uv0 v2")
	_expect_equal(brush.mesh_data.uv0_v3.size(), 6, "batched width weld exports uv0 v3")
	_expect_close(brush.mesh_data.uv0_v3[0].z, 1.0, "batched width weld preserves first width")
	_expect_close(brush.mesh_data.uv0_v3[5].z, 1.0, "batched width weld preserves last width")
	brush.free()

func _check_batched_finalization_preserves_double_sided_strip() -> void:
	var brush := _make_quad_brush(QuadStripBrushStretchUV.new(), true)
	_seed_two_double_sided_solids(brush)
	brush.update_uvs(0, 4, 1.0)
	brush.flush_update_uv_request()
	brush.finalize_batched_brush()
	_expect_equal(brush.mesh_data.vertices.size(), 24, "double-sided batched vertex count is not welded")
	_expect_equal(brush.mesh_data.triangles.size(), 24, "double-sided batched index count is not welded")
	_expect_equal(brush.mesh_data.uv0_v2.size(), 24, "double-sided batched uv count")
	_expect_equal(brush.mesh_data.tangents.size(), 24, "double-sided batched tangent count")
	_expect_backface_mesh_data_matches_front(brush, 0)
	_expect_backface_mesh_data_matches_front(brush, 12)
	brush.free()

func _make_quad_brush(brush: QuadStripBrush, backfaces: bool) -> QuadStripBrush:
	var desc := BrushDescriptor.new()
	desc.m_DurableName = "Ink"
	desc.m_Guid = "c0012095-3ffd-4040-8ee1-fc180d346eaa"
	desc.m_RenderBackfaces = backfaces
	desc.m_BackIsInvisible = false
	desc.m_TextureAtlasV = 1
	desc.m_TileRate = 1.0
	desc.m_PressureSizeRange = Vector2(1.0, 1.0)
	desc.m_PressureOpacityRange = Vector2(1.0, 1.0)
	desc.m_Opacity = 1.0
	desc.m_SizeVariance = 0.0
	brush.m_BaseSize_PS = 1.0
	brush.m_Color = Color.WHITE
	brush.init_brush(desc, TrTransform.identity())
	return brush

func _seed_two_quads(brush: QuadStripBrush) -> void:
	brush.m_LeadingQuadIndex = 2
	brush.m_InitialQuadIndex = 0
	for index in range(12):
		brush.m_Geometry.m_Normals[index] = Vector3.BACK
		brush.m_Geometry.m_Colors[index] = Color.WHITE
		brush.m_Geometry.m_Tangents[index] = Vector4.ZERO
	brush.position_quad(brush.m_Geometry.m_Vertices, 0, Vector3(0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))
	brush.position_quad(brush.m_Geometry.m_Vertices, 6, Vector3(1.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))

func _seed_two_short_quads(brush: QuadStripBrush) -> void:
	brush.m_LeadingQuadIndex = 2
	brush.m_InitialQuadIndex = 0
	for index in range(12):
		brush.m_Geometry.m_Normals[index] = Vector3.BACK
		brush.m_Geometry.m_Colors[index] = Color.WHITE
		brush.m_Geometry.m_Tangents[index] = Vector4.ZERO
	brush.position_quad(brush.m_Geometry.m_Vertices, 0, Vector3(0.06, 0.0, 0.0), Vector3(0.06, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))
	brush.position_quad(brush.m_Geometry.m_Vertices, 6, Vector3(0.18, 0.0, 0.0), Vector3(0.06, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))

func _seed_two_double_sided_solids(brush: QuadStripBrush) -> void:
	brush.m_LeadingQuadIndex = 4
	brush.m_InitialQuadIndex = 0
	for index in range(24):
		brush.m_Geometry.m_Normals[index] = Vector3.BACK
		brush.m_Geometry.m_Colors[index] = Color.WHITE
		brush.m_Geometry.m_Tangents[index] = Vector4.ZERO
	brush.position_quad(brush.m_Geometry.m_Vertices, 0, Vector3(0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))
	BaseBrushScript.create_duplicate_quad(brush.m_Geometry.m_Vertices, brush.m_Geometry.m_Normals, 1, Vector3.BACK)
	brush.position_quad(brush.m_Geometry.m_Vertices, 12, Vector3(1.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.0, 0.5, 0.0))
	BaseBrushScript.create_duplicate_quad(brush.m_Geometry.m_Vertices, brush.m_Geometry.m_Normals, 3, Vector3.BACK)

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

func _expect_vec2_close(actual: Vector2, expected: Vector2, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)

func _expect_vec4_close(actual: Vector4, expected: Vector4, label: String) -> void:
	_expect_close(actual.x, expected.x, "%s x" % label)
	_expect_close(actual.y, expected.y, "%s y" % label)
	_expect_close(actual.z, expected.z, "%s z" % label)
	_expect_close(actual.w, expected.w, "%s w" % label)

func _expect_color_close(actual: Color, expected: Color, label: String) -> void:
	_expect_close(actual.r, expected.r, "%s r" % label)
	_expect_close(actual.g, expected.g, "%s g" % label)
	_expect_close(actual.b, expected.b, "%s b" % label)
	_expect_close(actual.a, expected.a, "%s a" % label)

func _expect_backface_matches_front(brush: QuadStripBrush, front_vert: int) -> void:
	var verts := brush.m_Geometry.m_Vertices
	var norms := brush.m_Geometry.m_Normals
	var back_vert := front_vert + 6
	_expect_vec3_close(verts[back_vert], verts[front_vert], "backface %d vertex 0" % front_vert)
	_expect_vec3_close(verts[back_vert + 1], verts[front_vert + 2], "backface %d vertex 1" % front_vert)
	_expect_vec3_close(verts[back_vert + 2], verts[front_vert + 1], "backface %d vertex 2" % front_vert)
	_expect_vec3_close(verts[back_vert + 3], verts[front_vert + 3], "backface %d vertex 3" % front_vert)
	_expect_vec3_close(verts[back_vert + 4], verts[front_vert + 5], "backface %d vertex 4" % front_vert)
	_expect_vec3_close(verts[back_vert + 5], verts[front_vert + 4], "backface %d vertex 5" % front_vert)
	_expect_vec3_close(norms[back_vert], -norms[front_vert], "backface %d normal 0" % front_vert)
	_expect_vec3_close(norms[back_vert + 1], -norms[front_vert + 2], "backface %d normal 1" % front_vert)
	_expect_vec3_close(norms[back_vert + 2], -norms[front_vert + 1], "backface %d normal 2" % front_vert)
	_expect_vec3_close(norms[back_vert + 3], -norms[front_vert + 3], "backface %d normal 3" % front_vert)
	_expect_vec3_close(norms[back_vert + 4], -norms[front_vert + 5], "backface %d normal 4" % front_vert)
	_expect_vec3_close(norms[back_vert + 5], -norms[front_vert + 4], "backface %d normal 5" % front_vert)

func _expect_backface_uvs_match_front(brush: QuadStripBrush, front_vert: int) -> void:
	var uvs := brush.m_Geometry.m_UVs
	var back_vert := front_vert + 6
	_expect_vec2_close(uvs[back_vert], uvs[front_vert], "backface %d uv 0" % front_vert)
	_expect_vec2_close(uvs[back_vert + 1], uvs[front_vert + 2], "backface %d uv 1" % front_vert)
	_expect_vec2_close(uvs[back_vert + 2], uvs[front_vert + 1], "backface %d uv 2" % front_vert)
	_expect_vec2_close(uvs[back_vert + 3], uvs[front_vert + 3], "backface %d uv 3" % front_vert)
	_expect_vec2_close(uvs[back_vert + 4], uvs[front_vert + 5], "backface %d uv 4" % front_vert)
	_expect_vec2_close(uvs[back_vert + 5], uvs[front_vert + 4], "backface %d uv 5" % front_vert)

func _expect_backface_colors_match_front(brush: QuadStripBrush, front_vert: int) -> void:
	var colors := brush.m_Geometry.m_Colors
	var back_vert := front_vert + 6
	_expect_color_close(colors[back_vert], colors[front_vert], "backface %d color 0" % front_vert)
	_expect_color_close(colors[back_vert + 1], colors[front_vert + 2], "backface %d color 1" % front_vert)
	_expect_color_close(colors[back_vert + 2], colors[front_vert + 1], "backface %d color 2" % front_vert)
	_expect_color_close(colors[back_vert + 3], colors[front_vert + 3], "backface %d color 3" % front_vert)
	_expect_color_close(colors[back_vert + 4], colors[front_vert + 5], "backface %d color 4" % front_vert)
	_expect_color_close(colors[back_vert + 5], colors[front_vert + 4], "backface %d color 5" % front_vert)

func _expect_backface_tangents_match_front(brush: QuadStripBrush, front_vert: int) -> void:
	var tangents := brush.m_Geometry.m_Tangents
	var back_vert := front_vert + 6
	_expect_vec4_close(tangents[back_vert], _mirrored_tangent(tangents[front_vert]), "backface %d tangent 0" % front_vert)
	_expect_vec4_close(tangents[back_vert + 1], _mirrored_tangent(tangents[front_vert + 2]), "backface %d tangent 1" % front_vert)
	_expect_vec4_close(tangents[back_vert + 2], _mirrored_tangent(tangents[front_vert + 1]), "backface %d tangent 2" % front_vert)
	_expect_vec4_close(tangents[back_vert + 3], _mirrored_tangent(tangents[front_vert + 3]), "backface %d tangent 3" % front_vert)
	_expect_vec4_close(tangents[back_vert + 4], _mirrored_tangent(tangents[front_vert + 5]), "backface %d tangent 4" % front_vert)
	_expect_vec4_close(tangents[back_vert + 5], _mirrored_tangent(tangents[front_vert + 4]), "backface %d tangent 5" % front_vert)

func _expect_backface_mesh_data_matches_front(brush: QuadStripBrush, front_vert: int) -> void:
	var verts := brush.mesh_data.vertices
	var norms := brush.mesh_data.normals
	var uvs := brush.mesh_data.uv0_v2
	var tangents := brush.mesh_data.tangents
	var back_vert := front_vert + 6
	_expect_vec3_close(verts[back_vert], verts[front_vert], "mesh backface %d vertex 0" % front_vert)
	_expect_vec3_close(verts[back_vert + 1], verts[front_vert + 2], "mesh backface %d vertex 1" % front_vert)
	_expect_vec3_close(verts[back_vert + 2], verts[front_vert + 1], "mesh backface %d vertex 2" % front_vert)
	_expect_vec3_close(verts[back_vert + 3], verts[front_vert + 3], "mesh backface %d vertex 3" % front_vert)
	_expect_vec3_close(verts[back_vert + 4], verts[front_vert + 5], "mesh backface %d vertex 4" % front_vert)
	_expect_vec3_close(verts[back_vert + 5], verts[front_vert + 4], "mesh backface %d vertex 5" % front_vert)
	_expect_vec3_close(norms[back_vert], -norms[front_vert], "mesh backface %d normal 0" % front_vert)
	_expect_vec3_close(norms[back_vert + 1], -norms[front_vert + 2], "mesh backface %d normal 1" % front_vert)
	_expect_vec3_close(norms[back_vert + 2], -norms[front_vert + 1], "mesh backface %d normal 2" % front_vert)
	_expect_vec2_close(uvs[back_vert], uvs[front_vert], "mesh backface %d uv 0" % front_vert)
	_expect_vec2_close(uvs[back_vert + 1], uvs[front_vert + 2], "mesh backface %d uv 1" % front_vert)
	_expect_vec2_close(uvs[back_vert + 2], uvs[front_vert + 1], "mesh backface %d uv 2" % front_vert)
	_expect_vec4_close(tangents[back_vert], _mirrored_tangent(tangents[front_vert]), "mesh backface %d tangent 0" % front_vert)
	_expect_vec4_close(tangents[back_vert + 1], _mirrored_tangent(tangents[front_vert + 2]), "mesh backface %d tangent 1" % front_vert)
	_expect_vec4_close(tangents[back_vert + 2], _mirrored_tangent(tangents[front_vert + 1]), "mesh backface %d tangent 2" % front_vert)

func _mirrored_tangent(value: Vector4) -> Vector4:
	return Vector4(value.x, value.y, value.z, -value.w)

func _color32_channel(value: float) -> float:
	return float(int(clamp(value, 0.0, 1.0) * 255.0)) / 255.0

func _color32(value: Color) -> Color:
	return Color(
		_color32_channel(value.r),
		_color32_channel(value.g),
		_color32_channel(value.b),
		_color32_channel(value.a)
	)

func _expect_close(actual: float, expected: float, label: String) -> void:
	if abs(actual - expected) > 1e-5:
		_fail("%s expected %.8f but got %.8f" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_QUADSTRIP: %s" % message)
