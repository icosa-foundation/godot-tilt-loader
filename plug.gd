extends "res://addons/gd-plug/plug.gd"

func _plugging() -> void:
	plug("https://github.com/icosa-foundation/icosa-godot-addon.git", {
		"commit": "d567cc8bf56a56b9b64765de653d5490525505e3",
		"include": ["addons/icosa"],
	})
