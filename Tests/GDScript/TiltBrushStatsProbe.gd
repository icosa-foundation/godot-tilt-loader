extends SceneTree

const TILT_READER_PATH := "res://addons/open_brush_stroke_integration/open_brush_tilt_reader.gd"
const OPEN_BRUSH_PATH := "res://addons/icosa/open_brush/open_brush.gd"

func _init() -> void:
	var tilt_path := "res://Temp/TiltEvidence/brush_cafe_experimental.tilt"
	var brush_filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		tilt_path = args[0]
	if args.size() > 1:
		brush_filter = args[1]
	var reader_script := load(TILT_READER_PATH)
	var open_brush_script := load(OPEN_BRUSH_PATH)
	var data: Dictionary = reader_script.new().load_tilt(tilt_path)
	var ob = open_brush_script.new()
	ob.ensure_loaded()

	var groups := {}
	for stroke in data.get("strokes", []):
		if not stroke is Dictionary:
			continue
		var brush_name: String = ob.resolve_brush_name(stroke.get("brush_guid", ""))
		if not groups.has(brush_name):
			groups[brush_name] = {
				"count": 0,
				"control_points": 0,
				"color": Color(0, 0, 0, 0),
				"bounds": {"valid": false, "min": Vector3.ZERO, "max": Vector3.ZERO},
			}
		var group: Dictionary = groups[brush_name]
		group.count += 1
		var color: Color = stroke.get("color", Color.WHITE)
		group.color += color
		for cp in stroke.get("control_points", []):
			if not cp is Dictionary:
				continue
			group.control_points += 1
			_expand_bounds(group.bounds, cp.get("position", Vector3.ZERO))

	var names: Array = groups.keys()
	names.sort_custom(func(a, b):
		var ca: Color = groups[a].color / float(maxi(groups[a].count, 1))
		var cb: Color = groups[b].color / float(maxi(groups[b].count, 1))
		var score_a := ca.r - maxf(ca.g, ca.b)
		var score_b := cb.r - maxf(cb.g, cb.b)
		return score_a > score_b
	)
	var printed := 0
	for i in range(names.size()):
		var name: String = names[i]
		if not brush_filter.is_empty() and name != brush_filter:
			continue
		var group: Dictionary = groups[name]
		var avg: Color = group.color / float(maxi(group.count, 1))
		print("TILT_BRUSH_STATS\t%s\tstrokes=%d\tcp=%d\tavg=%s\tbounds_min=%s\tbounds_max=%s" % [
			name,
			group.count,
			group.control_points,
			avg,
			group.bounds.min,
			group.bounds.max,
		])
		printed += 1
		if brush_filter.is_empty() and printed >= 20:
			break
	quit(0)

func _expand_bounds(bounds: Dictionary, point: Vector3) -> void:
	if not bounds.valid:
		bounds.valid = true
		bounds.min = point
		bounds.max = point
	else:
		bounds.min = bounds.min.min(point)
		bounds.max = bounds.max.max(point)
