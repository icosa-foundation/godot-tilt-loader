class_name SerializableGuid
extends RefCounted

var storage := ""

static func create(value: String = "") -> SerializableGuid:
	var guid := SerializableGuid.new()
	guid.storage = canonicalize(value)
	return guid

static func empty() -> SerializableGuid:
	return SerializableGuid.create("")

static func canonicalize(value: String) -> String:
	var stripped := value.strip_edges().to_lower()
	if stripped == "":
		return "00000000-0000-0000-0000-000000000000"
	stripped = stripped.replace("-", "")
	if stripped.length() != 32:
		return "00000000-0000-0000-0000-000000000000"
	return "%s-%s-%s-%s-%s" % [
		stripped.substr(0, 8),
		stripped.substr(8, 4),
		stripped.substr(12, 4),
		stripped.substr(16, 4),
		stripped.substr(20, 12)
	]

func to_format(format: String = "D") -> String:
	if format == "N":
		return storage.replace("-", "")
	return storage

func _to_string() -> String:
	return to_format("D")
