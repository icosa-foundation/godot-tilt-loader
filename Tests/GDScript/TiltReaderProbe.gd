extends SceneTree

const TILT_READER_PATH := "res://addons/icosa/open_brush/open_brush_tilt_reader.gd"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var reader_script := load(TILT_READER_PATH)
	if reader_script == null:
		push_error("TiltReaderProbe: missing tilt reader")
		quit(1)
		return
	for path in args:
		var data: Dictionary = reader_script.new().load_tilt(path)
		var error := String(data.get("error", ""))
		if not error.is_empty():
			print("TILT_PROBE\tERROR\t%s\t%s" % [path, error])
			continue
		var strokes: Array = data.get("strokes", [])
		var cps := 0
		for stroke in strokes:
			if stroke is Dictionary:
				cps += stroke.get("control_points", []).size()
		print("TILT_PROBE\tOK\t%s\tstrokes=%d\tcontrol_points=%d" % [path, strokes.size(), cps])
	quit(0)
