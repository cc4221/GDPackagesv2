class_name PackageEventAdapter extends RefCounted

var PackageEventBus = preload("res://addons/gdpackages/classes/package_event_bus.gd")

var _package_event_bus_cache = PackageEventBus

var _package_name: String
var _subscriptions: Array = []

func _init(package_name: String = "") -> void:
	_package_name = package_name

func subscribe(event_name: String, callback: Callable, filter: Callable = Callable()) -> void:
	_package_event_bus_cache.subscribe(event_name, callback, _package_name, filter)
	_subscriptions.append({"event": event_name, "callback": callback})

func unsubscribe(event_name: String, callback: Callable) -> void:
	_package_event_bus_cache.unsubscribe(event_name, callback)
	
	var index_to_remove: int = -1
	for i in range(_subscriptions.size()):
		var sub = _subscriptions[i]
		if sub.event == event_name and sub.callback == callback:
			index_to_remove = i
			break
	
	if index_to_remove >= 0:
		_subscriptions.remove_at(index_to_remove)

func unsubscribe_all() -> void:
	var bus = _package_event_bus_cache
	for sub in _subscriptions:
		bus.unsubscribe(sub.event, sub.callback)
	_subscriptions.clear()

func emit(event_name: String, data: Variant = null) -> void:
	_package_event_bus_cache.emit(event_name, data, _package_name)

func get_cached_events(event_name: String, count: int = 10) -> Array:
	return _package_event_bus_cache.get_cached_events(event_name, count)