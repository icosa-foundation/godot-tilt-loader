class_name Pool
extends RefCounted

var _free: Array = []
var _max_free := -1
var _factory: Callable

static func create(factory: Callable, max_free: int = -1) -> Pool:
	var pool := Pool.new()
	pool._factory = factory
	pool._max_free = max_free
	return pool

func get_instance() -> Variant:
	if _free.is_empty():
		return _factory.call()
	var instance: Variant = _free.pop_back()
	if instance != null and instance.has_method("on_pool_get"):
		instance.on_pool_get()
	return instance

func put(instance: Variant) -> void:
	if instance != null and instance.has_method("on_pool_put"):
		instance.on_pool_put()
	if _max_free < 0 or _free.size() < _max_free:
		_free.append(instance)

func put_and_clear(holder: Array) -> void:
	if holder.is_empty():
		return
	var instance: Variant = holder[0]
	holder[0] = null
	put(instance)

func free_count() -> int:
	return _free.size()
