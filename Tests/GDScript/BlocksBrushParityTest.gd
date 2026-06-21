extends SceneTree

var _failures := 0

func _init() -> void:
	_run()
	quit(1 if _failures > 0 else 0)

func _run() -> void:
	_check_blocks_brush_noop_contract()
	if _failures == 0:
		print("GDSCRIPT_PARITY_BLOCKSBRUSH: all checks passed")

func _check_blocks_brush_noop_contract() -> void:
	var desc := BrushDescriptor.new()
	var brush := BlocksBrushScript.new()
	brush.m_BaseSize_PS = 1.0
	brush.init_brush(desc, TrTransform.identity())

	var layout := brush.get_vertex_layout(desc)
	_expect(layout.bUseColors, "blocks layout colors")
	_expect(layout.bUseNormals, "blocks layout normals")
	_expect(not layout.bUseTangents, "blocks layout no tangents")
	_expect(not layout.bUseVertexIds, "blocks layout no vertex ids")
	_expect_equal(layout.texcoord0.size, 0, "blocks layout texcoord0")
	_expect_equal(brush.get_num_used_verts(), 0, "blocks used verts")
	_expect_equal(brush.get_spawn_interval(0.5), 0.0, "blocks spawn interval")
	_expect(brush.update_position_ls(TrTransform.t(Vector3.RIGHT), 0.5), "blocks update returns true")
	brush.apply_changes_to_visuals()
	brush.finalize_solitary_brush()
	brush.finalize_for_runtime()
	_expect_equal(brush.mesh_data.vertex_count(), 0, "blocks runtime finalize remains no-op")
	brush.free()

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)

func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s but got %s" % [label, expected, actual])

func _fail(message: String) -> void:
	_failures += 1
	push_error("GDSCRIPT_PARITY_BLOCKSBRUSH: %s" % message)
