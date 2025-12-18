# PackageEventAdapter provides a convenient interface for packages to interact with the event bus
# It handles subscription management and event emission with automatic tracking of subscriptions
class_name PackageEventAdapter extends RefCounted

# Reference to the PackageEventBus for communication
var PackageEventBus = preload("res://addons/gdpackages/classes/package_event_bus.gd")

# Cached reference to PackageEventBus for improved performance
var _package_event_bus_cache = PackageEventBus

# Name of the package that owns this adapter
var _package_name: String
# Track all subscriptions made through this adapter for easy cleanup
var _subscriptions: Array = []

# Constructor that sets the owning package name
func _init(package_name: String = "") -> void:
	_package_name = package_name

# Subscribe to an event with an optional filter
# The subscription is tracked internally for easy cleanup
func subscribe(event_name: String, callback: Callable, filter: Callable = Callable()) -> void:
	_package_event_bus_cache.subscribe(event_name, callback, _package_name, filter)
	_subscriptions.append({"event": event_name, "callback": callback})

# Unsubscribe from a specific event
# Removes the subscription from internal tracking
func unsubscribe(event_name: String, callback: Callable) -> void:
	_package_event_bus_cache.unsubscribe(event_name, callback)
	
	# Using more efficient removal while preserving order
	var index_to_remove: int = -1
	for i in range(_subscriptions.size()):
		var sub = _subscriptions[i]
		if sub.event == event_name and sub.callback == callback:
			index_to_remove = i
			break
	
	if index_to_remove >= 0:
		_subscriptions.remove_at(index_to_remove)

# Unsubscribe from all events that were subscribed through this adapter
func unsubscribe_all() -> void:
	# Using cached reference for improved performance
	var bus = _package_event_bus_cache
	for sub in _subscriptions:
		bus.unsubscribe(sub.event, sub.callback)
	_subscriptions.clear()

# Emit an event through the PackageEventBus
func emit(event_name: String, data: Variant = null) -> void:
	_package_event_bus_cache.emit(event_name, data, _package_name)

# Get cached events from the PackageEventBus
func get_cached_events(event_name: String, count: int = 10) -> Array:
	return _package_event_bus_cache.get_cached_events(event_name, count)
