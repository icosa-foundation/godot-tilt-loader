extends "res://addons/gd-plug/plug.gd"

func _plugging() -> void:
	plug("https://github.com/icosa-foundation/icosa-godot-addon.git", {
		"include": ["addons/icosa"],
	})
