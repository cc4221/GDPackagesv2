class_name PackageEventBus extends RefCounted

class EventSubscription:
	var callback: Callable
	var filter: Callable
	var package_name: String

	func _init(cb: Callable, pkg: String, flt: Callable = Callable()) -> void:
		callback = cb
		package_name = pkg
		filter = flt

static var _subscribers: Dictionary = {}

static var _name_to_id: Dictionary[StringName, int] = {}
static var _id_to_name: Dictionary[int, StringName] = {}
static var _next_event_id: int = 1

static var _event_cache: Dictionary[StringName, Array] = {}

static var max_cache_size: int = 50

static var log_events: bool = false

static var track_stats: bool = true

static var _stats: Dictionary[StringName, Dictionary] = {}

static var buffered: bool = false
static var _buffer: Array[Dictionary] = []
static var _runner: Node = null
static var _flush_in_progress: bool = false
static var _max_flush_items_per_tick: int = 1024

class EventRunner:
	extends Node
	func _process(delta: float) -> void:
		PackageEventBus._flush_buffer()

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


static func _get_event_id(event_name: StringName) -> int:
	if _name_to_id.has(event_name):
		return _name_to_id[event_name]
	var id = _next_event_id
	_next_event_id += 1
	_name_to_id[event_name] = id
	_id_to_name[id] = event_name
	if max_cache_size > 0:
		_event_cache[event_name] = []
	return id

static func subscribe(event_name: StringName, callback: Callable, package_name: String = "",
					  filter: Callable = Callable()) -> String:
	var id = _get_event_id(event_name)
	if not _subscribers.has(id):
		_subscribers[id] = []
	var sub = EventSubscription.new(callback, package_name, filter)
	_subscribers[id].append(sub)
	return str(id) + "::" + str(_subscribers[id].size() - 1)


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


static func unsubscribe_all(event_name: StringName) -> void:
	if _name_to_id.has(event_name):
		var id = _name_to_id[event_name]
		_subscribers.erase(id)


static func emit(event_name: StringName, data: Variant = null, source: String = "") -> void:
	if track_stats:
		if not _stats.has(event_name):
			_stats[event_name] = {"count": 0, "last_emitted": 0.0}
		_stats[event_name]["count"] += 1
		_stats[event_name]["last_emitted"] = Time.get_ticks_msec() / 1000.0
	
	if max_cache_size > 0 and _event_cache.has(event_name):
		_event_cache[event_name].append({
			"data": data,
			"source": source,
			"timestamp": Time.get_ticks_msec()
		})
		if _event_cache[event_name].size() > max_cache_size:
			_event_cache[event_name].remove_at(0)
	
	if log_events:
		PackageLogger.log_info(source, "Event: " + str(event_name))
	
	if not _name_to_id.has(event_name):
		return
	var id = _name_to_id[event_name]
	if not _subscribers.has(id):
		return

	if buffered:
		_buffer.append({"id": id, "data": data, "source": source})
		_ensure_runner()
		return

	var subs = _subscribers[id]
	var subs_count = subs.size()
	if subs_count > 0:
		for i in range(subs_count):
			var subscription = subs[i]
			if subscription.filter.is_valid():
				if not subscription.filter.call(data):
					continue
			subscription.callback.call(data)


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


static func get_cached_events(event_name: StringName, count: int = 10) -> Array:
	if not _event_cache.has(event_name):
		return []
	var cache = _event_cache[event_name]
	var start = max(0, cache.size() - count)
	return cache.slice(start)


static func get_all_cached_events(event_name: StringName) -> Array:
	if not _event_cache.has(event_name):
		return []
	return _event_cache[event_name].duplicate()


static func clear_cache(event_name: StringName = "") -> void:
	if event_name.is_empty():
		_event_cache.clear()
	elif _event_cache.has(event_name):
		_event_cache[event_name].clear()


static func get_event_stats(event_name: StringName = "") -> Dictionary:
	if event_name.is_empty():
		return _stats.duplicate()
	return _stats.get(event_name, {})


static func clear_stats() -> void:
	_stats.clear()


static func has_subscribers(event_name: StringName) -> bool:
	if not _name_to_id.has(event_name):
		return false
	var id = _name_to_id[event_name]
	return _subscribers.has(id) and not _subscribers[id].is_empty()


static func get_subscriber_count(event_name: StringName) -> int:
	if not _name_to_id.has(event_name):
		return 0
	var id = _name_to_id[event_name]
	if not _subscribers.has(id):
		return 0
	return _subscribers[id].size()


static func get_registered_events() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for id in _subscribers.keys():
		var name = _id_to_name.get(id, "")
		if name != "":
			result.append(str(name))
	return result


static func get_registered_events_with_counts() -> Dictionary:
	var result: Dictionary = {}
	for id in _subscribers.keys():
		var name = _id_to_name.get(id, "")
		if name != "":
			result[str(name)] = get_subscriber_count(name)
	return result


static func clear_all() -> void:
	_subscribers.clear()
	_event_cache.clear()
	_stats.clear()
	_name_to_id.clear()
	_id_to_name.clear()
	_next_event_id = 1
	_buffer.clear()

static func _flush_buffer() -> void:
	if _buffer.size() == 0:
		return
	if _flush_in_progress:
		return
	_flush_in_progress = true
	var processed = 0
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