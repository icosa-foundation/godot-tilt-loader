class_name GeniusParticlesBrush
extends GeometryBrush

const K_SPAWN_INTERVAL_PS := 0.0025 * App.METERS_TO_UNITS
const K_SINGLE_PARTICLE_TRIGGER_PRESSURE := 0.8
const K_VERTS_IN_SOLID := 4
const K_TRIS_IN_SOLID := 2

const K_SALT_MAX_PARTICLES_PER_KNOT := 16
const K_SALT_MAX_SALTS_PER_PARTICLE := 16
const K_SALT_PRESSURE := 0
const K_SALT_ALPHA := K_SALT_PRESSURE + 1
const K_SALT_ON_SPHERE := K_SALT_ALPHA + 1
const K_SALT_ROTATION := K_SALT_ON_SPHERE + 2
const K_SALT_ROLL := K_SALT_ROTATION + 3
const K_SALT_ATLAS := K_SALT_ROLL + 1

const BR := 0
const BL := 1
const FR := 2
const FL := 3

const TEXTURE_ATLAS_00 := Vector4(0.0, 0.0, 0.0, 0.0)
const TEXTURE_ATLAS_05 := Vector4(0.0, 0.5, 0.0, 0.0)
const TEXTURE_ATLAS_50 := Vector4(0.5, 0.0, 0.0, 0.0)
const TEXTURE_ATLAS_55 := Vector4(0.5, 0.5, 0.0, 0.0)

var m_DecayTimers: Array[float] = []
var m_DecayedKnots := 0
var m_DistancePointerTravelled := -1.0
var m_LastPos := Vector3.ZERO
var m_LengthsAtKnot: Array[float] = [0.0]
var m_SpawnInterval := 0.0
var m_ParticleSizeScale := 1.0
var m_LastDecayTimeSeconds := -1.0

func _init() -> void:
	setup_geometry_brush(true, K_VERTS_IN_SOLID, false, false)

func calculate_salt(knot_index: int, particle_index: int) -> int:
	var pretend_knot_index := knot_index + m_DecayedKnots
	return K_SALT_MAX_SALTS_PER_PARTICLE * (pretend_knot_index * K_SALT_MAX_PARTICLES_PER_KNOT + particle_index)

func get_spawn_interval(_pressure01: float) -> float:
	return m_SpawnInterval

func distance_from_knot(knot_index: int, position: Vector3) -> float:
	var distance := super.distance_from_knot(knot_index, position)
	if knot_index == m_knots.size() - 2:
		distance = m_DistancePointerTravelled
	return distance

func always_rebuild_preview_brush() -> bool:
	return false

func init_brush(desc: BrushDescriptor, local_pointer_xf: TrTransform) -> void:
	super.init_brush(desc, local_pointer_xf)
	m_DecayTimers.clear()
	m_geometry.set_layout(get_vertex_layout(desc))
	m_SpawnInterval = (K_SPAWN_INTERVAL_PS * pointer_to_local()) / m_Desc.m_ParticleRate
	m_ParticleSizeScale = m_Desc.m_ParticleSpeed / m_Desc.m_BrushSizeRange.x
	m_LengthsAtKnot = [0.0]
	m_DecayedKnots = 0
	m_DistancePointerTravelled = -1.0
	m_LastDecayTimeSeconds = _current_decay_time_seconds()

func get_vertex_layout(_desc: BrushDescriptor) -> GeometryPool.VertexLayout:
	var layout := GeometryPool.VertexLayout.create(
		GeometryPool.TexcoordInfo.create(4, GeometryPool.Semantic.XY_IS_UV),
		GeometryPool.TexcoordInfo.create(3, GeometryPool.Semantic.POSITION),
		null,
		true,
		true,
		false
	)
	layout.normalSemantic = GeometryPool.Semantic.POSITION
	layout.bUseVertexIds = true
	layout.bFbxExportNormalAsTexcoord1 = true
	return layout

func decay_brush() -> void:
	var now := _current_decay_time_seconds()
	var delta := maxf(0.0, now - m_LastDecayTimeSeconds) if m_LastDecayTimeSeconds >= 0.0 else 0.0
	m_LastDecayTimeSeconds = now
	var knots_to_shift := 0
	for index in range(m_DecayTimers.size()):
		m_DecayTimers[index] += delta
		if m_DecayTimers[index] > K_PREVIEW_DURATION:
			knots_to_shift += 1
	if knots_to_shift <= 0:
		return
	m_DecayTimers = m_DecayTimers.slice(knots_to_shift)
	remove_initial_knots(knots_to_shift)
	if knots_to_shift > 0:
		var length_reduction := floorf(m_LengthsAtKnot[knots_to_shift] / m_SpawnInterval) * m_SpawnInterval
		var new_count := m_LengthsAtKnot.size() - knots_to_shift
		for index in range(1, new_count):
			m_LengthsAtKnot[index] = m_LengthsAtKnot[index + knots_to_shift] - length_reduction
		ListUtils.set_count(m_LengthsAtKnot, new_count, 0.0)
	m_DecayedKnots += knots_to_shift

func update_position_impl(position: Vector3, orientation: Quaternion, pressure: float) -> bool:
	var result := super.update_position_impl(position, orientation, pressure)
	if m_DistancePointerTravelled < 0.0:
		m_DistancePointerTravelled = 0.0
	else:
		m_DistancePointerTravelled += (position - m_LastPos).length()
	m_LastPos = position
	if m_PreviewMode and result:
		m_DecayTimers.append(0.0)
	return result

func reset_brush_for_preview(local_pointer_xf: TrTransform) -> void:
	super.reset_brush_for_preview(local_pointer_xf)
	m_DecayTimers.clear()
	m_LastDecayTimeSeconds = _current_decay_time_seconds()

func control_points_changed(first_knot_index: int) -> void:
	var num_knots := m_knots.size()
	var previous_index := 0 if first_knot_index == 0 else first_knot_index - 1
	invalidate_lengths_from_knot(first_knot_index)

	var particles_at_prev := total_particles_at_knot(previous_index)
	for knot_index in range(first_knot_index, num_knots):
		var particles_at_cur := total_particles_at_knot(knot_index)
		var particles_for_knot := particles_at_cur - particles_at_prev
		if knot_index == num_knots - 1:
			particles_for_knot += 1
		set_geometry_space_for_knot(knot_index, particles_for_knot)
		particles_at_prev = particles_at_cur

	resize_geometry()

	var prev := m_knots[previous_index]
	particles_at_prev = total_particles_at_knot(previous_index)
	var prev_length := stroke_length_at_knot(previous_index)
	for knot_index in range(first_knot_index, num_knots):
		var cur := m_knots[knot_index]
		var particles_for_knot := int(cur.nTri / K_TRIS_IN_SOLID)
		var cur_length := stroke_length_at_knot(knot_index)
		for particle_index in range(particles_for_knot):
			var particle_dist_on_stroke := (particles_at_prev + particle_index) * m_SpawnInterval
			var lerp_ratio := _inverse_lerp(prev_length, cur_length, particle_dist_on_stroke)
			var particle_pos := prev.point.m_Pos.lerp(cur.point.m_Pos, lerp_ratio)
			if knot_index == num_knots - 1 and particle_index == particles_for_knot - 1:
				particle_pos = cur.point.m_Pos
			var salt := calculate_salt(knot_index, particle_index)
			var size := pressured_random_size(cur.smoothedPressure, salt + K_SALT_PRESSURE)
			create_particle_geometry(knot_index, particle_index, particle_pos, size)
		particles_at_prev = int(floorf(cur_length / m_SpawnInterval)) + 1
		prev_length = cur_length
		prev = cur

func needs_straight_edge_proxy() -> bool:
	return true

func finalize_solitary_brush() -> void:
	finalize_particle_mesh()
	super.finalize_solitary_brush()

func finalize_batched_brush() -> void:
	finalize_particle_mesh()
	super.finalize_batched_brush()

func stroke_length_at_knot(knot_index: int) -> float:
	if knot_index < m_LengthsAtKnot.size():
		return m_LengthsAtKnot[knot_index]
	var num_lengths := m_LengthsAtKnot.size()
	ListUtils.set_count(m_LengthsAtKnot, knot_index + 1, 0.0)
	var prev := m_knots[num_lengths - 1]
	var length := m_LengthsAtKnot[num_lengths - 1]
	for index in range(num_lengths, knot_index + 1):
		var cur := m_knots[index]
		length += (cur.point.m_Pos - prev.point.m_Pos).length()
		m_LengthsAtKnot[index] = length
		prev = cur
	return length

func invalidate_lengths_from_knot(knot_index: int) -> void:
	ListUtils.set_count(m_LengthsAtKnot, maxi(knot_index, 1), 0.0)

func total_particles_at_knot(knot_index: int) -> int:
	if knot_index == 0:
		return 0
	return int(floorf(stroke_length_at_knot(knot_index) / m_SpawnInterval)) + 1

func finalize_particle_mesh() -> void:
	var final := m_knots[m_knots.size() - 1]
	if final.nTri <= K_TRIS_IN_SOLID * NS:
		m_knots = m_knots.slice(0, m_knots.size() - 1)
	else:
		final.nTri -= K_TRIS_IN_SOLID * NS
		final.nVert -= K_VERTS_IN_SOLID * NS
		m_knots[m_knots.size() - 1] = final
	resize_geometry()

	if m_knots.size() == 2:
		final = m_knots[1]
		var last_particle := int(final.nTri / K_TRIS_IN_SOLID) - 1
		var pressure: float = maxf(K_SINGLE_PARTICLE_TRIGGER_PRESSURE, final.smoothedPressure)
		var salt := calculate_salt(1, last_particle)
		var size := pressured_random_size(pressure, salt)
		create_particle_geometry(1, last_particle, m_knots[0].point.m_Pos, size)

func set_geometry_space_for_knot(knot_index: int, particle_count: int) -> void:
	var cur := m_knots[knot_index]
	var prev := m_knots[knot_index - 1] if knot_index > 0 else Knot.new()
	cur.iTri = prev.iTri + prev.nTri
	cur.iVert = prev.iVert + prev.nVert
	cur.length = (cur.point.m_Pos - prev.point.m_Pos).length()
	cur.nRight = Vector3.RIGHT
	cur.nTri = K_TRIS_IN_SOLID * particle_count
	cur.nVert = K_VERTS_IN_SOLID * particle_count
	m_knots[knot_index] = cur

func create_particle_geometry(knot_index: int, particle_index: int, position: Vector3, size: float) -> void:
	var cur := m_knots[knot_index]
	var vert_index := cur.iVert + particle_index * K_VERTS_IN_SOLID * NS
	var tri_index := cur.iTri + particle_index * K_TRIS_IN_SOLID * NS
	var salt := calculate_salt(knot_index, particle_index)
	var alpha: float
	if m_Desc.m_RandomizeAlpha:
		alpha = m_rng.in01(salt + K_SALT_ALPHA)
	else:
		alpha = m_Desc.m_Opacity * lerpf(m_Desc.m_PressureOpacityRange.x, m_Desc.m_PressureOpacityRange.y, cur.smoothedPressure)
	var random_offset := m_rng.on_unit_sphere(salt + K_SALT_ON_SPHERE) * size * m_ParticleSizeScale
	var center := position + random_offset
	var random_direction := m_rng.rotation(salt + K_SALT_ROTATION)
	var up_offset := random_direction * (Vector3.UP * size * 0.5)
	var right_offset := random_direction * (Vector3.RIGHT * size * 0.5)

	set_tri(tri_index, vert_index, 0, BR, BL, FL)
	set_tri(tri_index, vert_index, 1, BR, FL, FR)
	set_vert(vert_index, BR, center - up_offset + right_offset, center, m_Color, alpha)
	set_vert(vert_index, BL, center - up_offset - right_offset, center, m_Color, alpha)
	set_vert(vert_index, FR, center + up_offset + right_offset, center, m_Color, alpha)
	set_vert(vert_index, FL, center + up_offset - right_offset, center, m_Color, alpha)

	var knot_creation_time_since_level_load := _knot_creation_time_since_level_load(cur)
	var time := -knot_creation_time_since_level_load if m_PreviewMode else knot_creation_time_since_level_load
	var half_rotate_range := m_Desc.m_ParticleInitialRotationRange * 0.5
	var rotation := deg_to_rad(m_rng.in_range(salt + K_SALT_ROLL, -half_rotate_range, half_rotate_range))
	var uv0 := Vector4(0.0, 0.0, rotation, time)
	var uv1 := position

	if m_Desc.m_TextureAtlasV > 1:
		var rand := m_rng.in_int_range(salt + K_SALT_ATLAS, 0, 4)
		var offset := TEXTURE_ATLAS_00
		if rand == 1:
			offset = TEXTURE_ATLAS_50
		elif rand == 2:
			offset = TEXTURE_ATLAS_05
		elif rand == 3:
			offset = TEXTURE_ATLAS_55
		set_uv0(vert_index, BL, TEXTURE_ATLAS_00 + offset + uv0)
		set_uv0(vert_index, FL, TEXTURE_ATLAS_50 + offset + uv0)
		set_uv0(vert_index, BR, TEXTURE_ATLAS_05 + offset + uv0)
		set_uv0(vert_index, FR, TEXTURE_ATLAS_55 + offset + uv0)
	else:
		set_uv0(vert_index, BL, uv0 + (TEXTURE_ATLAS_00 * 2.0))
		set_uv0(vert_index, FL, uv0 + (TEXTURE_ATLAS_50 * 2.0))
		set_uv0(vert_index, BR, uv0 + (TEXTURE_ATLAS_05 * 2.0))
		set_uv0(vert_index, FR, uv0 + (TEXTURE_ATLAS_55 * 2.0))
	set_uv1(vert_index, BL, uv1)
	set_uv1(vert_index, FL, uv1)
	set_uv1(vert_index, BR, uv1)
	set_uv1(vert_index, FR, uv1)

static func _inverse_lerp(a: float, b: float, value: float) -> float:
	if absf(b - a) < 0.000001:
		return 0.0
	return clampf((value - a) / (b - a), 0.0, 1.0)

static func _knot_creation_time_since_level_load(knot: Knot) -> float:
	if App.force_deterministic_birth_time_for_export:
		return 0.0
	return App.sketch_time_to_level_load_time(float(knot.point.m_TimestampMs) * 0.001)

static func _current_decay_time_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
