extends "res://addons/gd-plug/plug.gd"

func _plugging() -> void:
	plug("file:///C:/Users/andyb/Documents/icosa-godot-addon/.git", {
		"include": ["addons/icosa"],
	})
