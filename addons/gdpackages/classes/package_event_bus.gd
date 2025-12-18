# PackageEventBus is a global event system that allows packages to communicate with each other
# It provides event emission, subscription, filtering, caching, and statistics
class_name PackageEventBus extends RefCounted

# Internal class to represent an event subscription with callback, package name, and optional filter
class EventSubscription:
	var callback: Callable
	var filter: Callable
	var package_name: String

	# Initialize a subscription with callback, package name, and optional filter
	func _init(cb: Callable, pkg: String, flt: Callable = Callable()) -> void:
		callback = cb
		package_name = pkg
		filter = flt


# Dictionary mapping event IDs to arrays of subscribers
static var _subscribers: Dictionary = {}

# Dictionaries for mapping event names to IDs and vice versa (for efficient lookup)
static var _name_to_id: Dictionary[StringName, int] = {}
static var _id_to_name: Dictionary[int, StringName] = {}
static var _next_event_id: int = 1

# Cache of recent events for retrieval by listeners
static var _event_cache: Dictionary[StringName, Array] = {}

# Maximum number of events to keep in cache for each event type
static var max_cache_size: int = 50

# Flag to enable logging of all events
static var log_events: bool = false

# Flag to enable tracking of event statistics
static var track_stats: bool = true

# Dictionary storing statistics for each event (count, last emission time)
static var _stats: Dictionary[StringName, Dictionary] = {}

# Flag to enable buffered event emission (useful for performance in high-frequency scenarios)
static var buffered: bool = false
# Buffer for storing events when buffered mode is enabled
static var _buffer: Array[Dictionary] = []
# Runner node for processing buffered events in the game loop
static var _runner: Node = null
# Flag to prevent re-entrancy during buffer flushing
static var _flush_in_progress: bool = false
# Maximum number of events to process per tick when flushing the buffer
static var _max_flush_items_per_tick: int = 1024

# Internal class for running buffer flush in the game loop
class EventRunner:
	extends Node
	# Process function that flushes the event buffer
	func _process(delta: float) -> void:
		PackageEventBus._flush_buffer()

# Ensure the EventRunner node exists and is added to the scene tree
static func _ensure_runner() -> void:
	if _runner == null:
		if Engine.is_editor_hint():
			return
		var r = EventRunner.new()
		_runner = r
		var ml = Engine.get_main_loop()
		if ml and ml is SceneTree:
			var root = ml.get_root()
			if root:
				root.add_child(r)


# Get or create an event ID for the given event name
static func _get_event_id(event_name: StringName) -> int:
	if _name_to_id.has(event_name):
		return _name_to_id[event_name]
	var id = _next_event_id
	_next_event_id += 1
	_name_to_id[event_name] = id
	_id_to_name[id] = event_name
	# Initialize cache for this event if caching is enabled
	if max_cache_size > 0:
		_event_cache[event_name] = []
	return id

# Subscribe to an event with a callback, optional package name, and optional filter
# Returns a subscription ID that can be used for unsubscribing
static func subscribe(event_name: StringName, callback: Callable, package_name: String = "",
					  filter: Callable = Callable()) -> String:
	var id = _get_event_id(event_name)
	if not _subscribers.has(id):
		_subscribers[id] = []
	var sub = EventSubscription.new(callback, package_name, filter)
	_subscribers[id].append(sub)
	return str(id) + "::" + str(_subscribers[id].size() - 1)


# Unsubscribe a specific callback from an event
static func unsubscribe(event_name: StringName, callback: Callable) -> void:
	if not _name_to_id.has(event_name):
		return
	var id = _name_to_id[event_name]
	if not _subscribers.has(id):
		return
	var subs = _subscribers[id]
	var subs_count = subs.size()
	for i in range(subs_count - 1, -1, -1):
		if subs[i].callback == callback:
			subs.remove_at(i)
			break
	if subs.is_empty():
		_subscribers.erase(id)


# Unsubscribe all callbacks from a specific event
static func unsubscribe_all(event_name: StringName) -> void:
	if _name_to_id.has(event_name):
		var id = _name_to_id[event_name]
		_subscribers.erase(id)


# Emit an event to all subscribers
# Updates statistics and cache if enabled, and applies filters
static func emit(event_name: StringName, data: Variant = null, source: String = "") -> void:
	if track_stats:
		if not _stats.has(event_name):
			_stats[event_name] = {"count": 0, "last_emitted": 0.0}
		_stats[event_name]["count"] += 1
		_stats[event_name]["last_emitted"] = Time.get_ticks_msec() / 1000.0
	
	# Add event to cache if caching is enabled
	if max_cache_size > 0 and _event_cache.has(event_name):
		_event_cache[event_name].append({
			"data": data,
			"source": source,
			"timestamp": Time.get_ticks_msec()
		})
		if _event_cache[event_name].size() > max_cache_size:
			_event_cache[event_name].remove_at(0)
	
	# Log the event if logging is enabled
	if log_events:
		PackageLogger.log_info(source, "Event: " + str(event_name))
	
	if not _name_to_id.has(event_name):
		return
	var id = _name_to_id[event_name]
	if not _subscribers.has(id):
		return

	# Add to buffer if buffered mode is enabled
	if buffered:
		_buffer.append({"id": id, "data": data, "source": source})
		_ensure_runner()
		return

	# Execute the event for all subscribers
	var subs = _subscribers[id]
	var subs_count = subs.size()
	if subs_count > 0:
		# Оптимизируем обработку событий для большого количества подписчиков
		for i in range(subs_count):
			var subscription = subs[i]
			if subscription.filter.is_valid():
				if not subscription.filter.call(data):
					continue
			subscription.callback.call(data)


# Emit an event to a specific package only
static func emit_to_package(event_name: StringName, package_name: String, data: Variant = null,
						   source: String = "") -> void:
	if not _name_to_id.has(event_name):
		return
	var id = _name_to_id[event_name]
	if not _subscribers.has(id):
		return
	
	var subs = _subscribers[id]
	var subs_count = subs.size()
	if subs_count > 0:
		for i in range(subs_count):
			var subscription = subs[i]
			if subscription.package_name == package_name:
				if subscription.filter.is_valid():
					if not subscription.filter.call(data):
						continue
				subscription.callback.call(data)


# Get the last 'count' cached events for an event name
static func get_cached_events(event_name: StringName, count: int = 10) -> Array:
	if not _event_cache.has(event_name):
		return []
	var cache = _event_cache[event_name]
	var start = max(0, cache.size() - count)
	return cache.slice(start)


# Get all cached events for an event name
static func get_all_cached_events(event_name: StringName) -> Array:
	if not _event_cache.has(event_name):
		return []
	return _event_cache[event_name].duplicate()


# Clear the event cache, either for a specific event or all events
static func clear_cache(event_name: StringName = "") -> void:
	if event_name.is_empty():
		_event_cache.clear()
	elif _event_cache.has(event_name):
		_event_cache[event_name].clear()


# Get statistics for an event or all events
static func get_event_stats(event_name: StringName = "") -> Dictionary:
	if event_name.is_empty():
		return _stats.duplicate()
	return _stats.get(event_name, {})


# Clear all event statistics
static func clear_stats() -> void:
	_stats.clear()


# Check if an event has any subscribers
static func has_subscribers(event_name: StringName) -> bool:
	if not _name_to_id.has(event_name):
		return false
	var id = _name_to_id[event_name]
	return _subscribers.has(id) and not _subscribers[id].is_empty()


# Get the number of subscribers for an event
static func get_subscriber_count(event_name: StringName) -> int:
	if not _name_to_id.has(event_name):
		return 0
	var id = _name_to_id[event_name]
	if not _subscribers.has(id):
		return 0
	return _subscribers[id].size()


# Get a list of all registered event names
static func get_registered_events() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for id in _subscribers.keys():
		var name = _id_to_name.get(id, "")
		if name != "":
			result.append(str(name))
	return result


# Get registered events with their subscriber counts
static func get_registered_events_with_counts() -> Dictionary:
	var result: Dictionary = {}
	for id in _subscribers.keys():
		var name = _id_to_name.get(id, "")
		if name != "":
			result[str(name)] = get_subscriber_count(name)
	return result


# Clear all subscribers, cache, and statistics (resets the event bus)
static func clear_all() -> void:
	_subscribers.clear()
	_event_cache.clear()
	# Convert stats keys to StringName if needed before clearing
	_stats.clear()
	_name_to_id.clear()
	_id_to_name.clear()
	_next_event_id = 1
	_buffer.clear()

# Internal function to flush the event buffer in chunks to prevent performance issues
static func _flush_buffer() -> void:
	if _buffer.size() == 0:
		return
	if _flush_in_progress:
		return
	_flush_in_progress = true
	var processed = 0
	# Process up to _max_flush_items_per_tick events per tick to maintain performance
	while _buffer.size() > 0 and processed < _max_flush_items_per_tick:
		var item = _buffer.pop_front()
		processed += 1
		var id = item.get("id")
		var data = item.get("data")
		if _subscribers.has(id):
			var subs = _subscribers[id]
			var subs_count = subs.size()
			if subs_count > 0:
				for i in range(subs_count):
					var subscription = subs[i]
					if subscription.filter.is_valid():
						if not subscription.filter.call(data):
							continue
					subscription.callback.call(data)
	_flush_in_progress = false
	if _buffer.size() > 0:
		_ensure_runner()
