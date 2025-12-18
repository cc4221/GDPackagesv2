extends Node
class_name PackageThreadedResourceManager

static var _instance: PackageThreadedResourceManager = null

var loader: PackageThreadedLoader = null

var saver: PackageThreadedSaver = null

var _thread_pool: Array[Thread] = []
var _thread_pool_size: int = 0
var _max_thread_pool_size: int = 8
var _active_tasks: int = 0
var _task_queue: Array[Dictionary] = []
var _thread_pool_enabled: bool = true

@export var performance_config: Dictionary = {
	"max_concurrent_loads": 4,
	"max_concurrent_saves": 2,
	"batch_size": 10,
	"timeout_ms": 30000,
	"memory_limit_mb": 512,
	"progress_update_interval": 0.1,
	"use_compression": false,
	"verify_after_save": false,
	"cache_resources": true,
	"thread_priority": 1,
	"cache_size_limit": 100
}

var _resource_cache: Dictionary = {}
var _cache_access_order: Array[String] = []
var _cache_size_limit: int = 100

func _cache_resource(key: String, resource: Resource) -> void:
	if not performance_config.get("cache_resources", true):
		return

	if _resource_cache.has(key):
		_cache_access_order.erase(key)

	_resource_cache[key] = resource
	_cache_access_order.append(key)

	if _cache_access_order.size() > performance_config.get("cache_size_limit", 100):
		var oldest_key = _cache_access_order[0]
		_resource_cache.erase(oldest_key)
		_cache_access_order.remove_at(0)

func _get_cached_resource(key: String) -> Resource:
	if _resource_cache.has(key):
		_cache_access_order.erase(key)
		_cache_access_order.append(key)
		return _resource_cache[key]
	return null

func _clear_resource_cache() -> void:
	_resource_cache.clear()
	_cache_access_order.clear()

func _get_cache_stats() -> Dictionary:
	return {
		"size": _resource_cache.size(),
		"limit": performance_config.get("cache_size_limit", 100),
		"keys": _resource_cache.keys()
	}

func _init() -> void:
	if _instance != null:
		push_error("PackageThreadedResourceManager: instance already exists!")
		queue_free()
		return

	_instance = self
	name = "PackageThreadedResourceManager"

	loader = PackageThreadedLoader.new()
	loader.name = "PackageThreadedLoader"
	add_child(loader)
	
	saver = PackageThreadedSaver.new()
	saver.name = "PackageThreadedSaver"
	add_child(saver)

	_initialize_thread_pool()

static func get_instance() -> PackageThreadedResourceManager:
	if _instance == null:
		var manager = PackageThreadedResourceManager.new()
		var root = Engine.get_main_loop().get_root()
		if root:
			root.call_deferred("add_child", manager)

	return _instance

static var _cached_instance: PackageThreadedResourceManager = null

static func _get_cached_instance() -> PackageThreadedResourceManager:
	if _cached_instance == null:
		_cached_instance = get_instance()
	return _cached_instance

static func set_ignore_warnings(value: bool) -> void:
	PackageThreadedLoader.ignoreWarnings = value
	PackageThreadedSaver.ignoreWarnings = value

static func load_resource(key: String, path: String, type_hint: String = "", cache_mode: int = 1) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()

	var cached_resource = manager._get_cached_resource(key)
	if cached_resource != null:
		manager.loader._loadedFiles[key] = cached_resource
		return manager
	
	manager.loader.add([[key, path, type_hint, cache_mode]]).start()
	return manager

static func load_resource_simple(path: String, type_hint: String = "", cache_mode: int = 1) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	var key = path.get_file()

	var cached_resource = manager._get_cached_resource(key)
	if cached_resource != null:
		manager.loader._loadedFiles[key] = cached_resource
		return manager
	
	manager.loader.add([["", path, type_hint, cache_mode]]).start()
	return manager

static func load_resources(resources: Array) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()

	var resources_to_load = []
	for resource_data in resources:
		var key = resource_data[0] if resource_data[0] != "" else resource_data[1].get_file()
		var cached_resource = manager._get_cached_resource(key)
		if cached_resource != null:
			manager.loader._loadedFiles[key] = cached_resource
		else:
			resources_to_load.append(resource_data)
	
	if resources_to_load.size() > 0:
		manager.loader.add(resources_to_load).start()
	
	return manager

static func load_resources_group(group_name: String, resources: Array, ignore_in_finished: bool = false) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.loader.add_group(group_name, resources, ignore_in_finished).start()
	return manager

static func queue_load_resources(resources: Array) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.loader.add(resources)
	return manager

static func queue_load_group(group_name: String, resources: Array, ignore_in_finished: bool = false) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.loader.add_group(group_name, resources, ignore_in_finished)
	return manager

static func start_loading(threads_amount: int = -1) -> PackageThreadedResourceManager:
	if threads_amount == -1:
		threads_amount = max(1, OS.get_processor_count() - 1)
	var manager = _get_cached_instance()
	manager.loader.start(threads_amount)
	return manager

static func is_loader_idle() -> bool:
	return _get_cached_instance().loader.is_idle()

static func get_loader_threads_count() -> int:
	return _get_cached_instance().loader.get_current_threads_amount()

static func connect_load_finished(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadFinished.connect(callable, flags)

static func connect_load_progress(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadProgress.connect(callable, flags)

static func connect_load_group(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadGroup.connect(callable, flags)

static func connect_load_error(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadError.connect(callable, flags)

static func connect_load_started(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadStarted.connect(callable, flags)

static func connect_loader_idle(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.becameIdle.connect(callable, flags)

static func save_resource(resource: Resource, path: String = "", flags: int = 0) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	if path.is_empty():
		path = resource.resource_path
	manager.saver.add([[resource, path, flags]]).start()
	return manager

static func save_resource_simple(resource: Resource, flags: int = 0) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	if resource.resource_path.is_empty():
		push_error("PackageThreadedResourceManager: resource_path пуст, используйте save_resource() с явным путем")
		return manager
	manager.saver.add([[resource, "", flags]]).start()
	return manager

static func save_resources(resources: Array) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.saver.add(resources).start()
	return manager

static func queue_save_resources(resources: Array) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.saver.add(resources)
	return manager

static func start_saving(verify_files_access: bool = false, threads_amount: int = -1) -> PackageThreadedResourceManager:
	if threads_amount == -1:
		threads_amount = max(1, OS.get_processor_count() - 1)
	var manager = _get_cached_instance()
	manager.saver.start(verify_files_access, threads_amount)
	return manager

static func is_saver_idle() -> bool:
	return _get_cached_instance().saver.is_idle()

static func get_saver_threads_count() -> int:
	return _get_cached_instance().saver.get_current_threads_amount()

static func connect_save_finished(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.saveFinished.connect(callable, flags)

static func connect_save_progress(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.saveProgress.connect(callable, flags)

static func connect_save_error(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.saveError.connect(callable, flags)

static func connect_save_started(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.saveStarted.connect(callable, flags)

static func connect_saver_idle(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.becameIdle.connect(callable, flags)

static func connect_all_finished(callable: Callable, flags: int = 0) -> Array[int]:
	var manager = _get_cached_instance()
	var ids: Array[int] = []
	ids.append(manager.loader.loadFinished.connect(callable, flags))
	ids.append(manager.saver.saveFinished.connect(callable, flags))
	return ids

static func disconnect_signal(signal_obj: Signal, callable: Callable) -> void:
	if signal_obj.is_connected(callable):
		signal_obj.disconnect(callable)

static func await_load_finished() -> Signal:
	return _get_cached_instance().loader.loadFinished

static func await_save_finished() -> Signal:
	return _get_cached_instance().saver.saveFinished

static func get_loaded_resource(key: String) -> Resource:
	var manager = _get_cached_instance()
	if manager.loader._loadedFiles.has(key):
		return manager.loader._loadedFiles[key]

	return manager._get_cached_resource(key)

static func get_all_loaded_resources() -> Dictionary:
	var all_resources = _get_cached_instance().loader._loadedFiles.duplicate()

	var cache_resources = _get_cached_instance()._resource_cache
	for key in cache_resources:
		if not all_resources.has(key):
			all_resources[key] = cache_resources[key]
	
	return all_resources

static func get_saved_paths() -> Array[String]:
	return _get_cached_instance().saver._savedPaths.duplicate()

func _initialize_thread_pool() -> void:
	_thread_pool_size = min(_max_thread_pool_size, OS.get_processor_count())
	_thread_pool.resize(_thread_pool_size)

	for i in range(_thread_pool_size):
		_thread_pool[i] = Thread.new()

func execute_task_in_pool(task_func: Callable, task_data: Dictionary = {}) -> void:
	if not _thread_pool_enabled:
		task_func.call(task_data)
		return

	var task = {
		"function": task_func,
		"data": task_data,
		"thread_index": -1
	}
	_task_queue.append(task)

	_process_task_queue()

func _process_task_queue() -> void:
	if _task_queue.is_empty() or _active_tasks >= _thread_pool_size:
		return

	var task = _task_queue.pop_front()
	
	var available_thread_index = -1
	for i in range(_thread_pool_size):
		if _thread_pool[i] and _thread_pool[i].is_active() == false:
			available_thread_index = i
			break

	if available_thread_index == -1:
		_task_queue.push_front(task)
		return

	task.thread_index = available_thread_index
	_active_tasks += 1

	var thread_func = func(data):
		var task_data = data["task"]
		task_data["function"].call(task_data["data"])
		_active_tasks -= 1
		_process_task_queue()

	var task_data = {"task": task}
	_thread_pool[available_thread_index].start(thread_func, task_data)

func get_thread_pool_stats() -> Dictionary:
	return {
		"pool_size": _thread_pool_size,
		"active_tasks": _active_tasks,
		"queued_tasks": _task_queue.size(),
		"pool_enabled": _thread_pool_enabled
	}

func set_thread_pool_size(size: int) -> void:
	if size <= 0:
		push_warning("Thread pool size must be greater than 0")
		return
	
	_max_thread_pool_size = size
	_thread_pool_enabled = true
	_initialize_thread_pool()

func stop_thread_pool() -> void:
	_thread_pool_enabled = false
	_task_queue.clear()

	while _active_tasks > 0:
		OS.delay_msec(10)

func set_performance_config(config: Dictionary) -> void:
	for key in config:
		if performance_config.has(key):
			performance_config[key] = config[key]

func get_performance_config() -> Dictionary:
	return performance_config.duplicate()

func update_performance_setting(key: String, value) -> void:
	if performance_config.has(key):
		performance_config[key] = value
	else:
		push_warning("Unknown performance setting: " + key)

func get_performance_setting(key: String):
	return performance_config.get(key, null)