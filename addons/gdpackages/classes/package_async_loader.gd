class_name PackageAsyncLoader extends Node

const PackageConfigGlobal = preload("res://addons/gdpackages/classes/package_config.gd")

var _package_event_bus: Script = null

signal package_load_started(package_name: String)
signal package_loaded(package: Package)
signal package_load_failed(package_name: String, error_message: String)
signal batch_load_progress(current: int, total: int)
signal batch_load_completed

@export var max_packages_per_frame: int = 1
@export var process_in_physics_frame: bool = false

static var _packages_cache: Dictionary = PackageManager.packages
static var _package_groups_cache: Dictionary = PackageManager.package_groups
static var _group_bit_registry_cache: Dictionary = PackageManager.group_bit_registry
static var _package_masks_cache: Dictionary = PackageManager.package_masks
static var _adapters_cache: Dictionary = PackageManager._adapters

var _batch_load_queue: Array[Dictionary] = []
var _current_batch_total: int = 0
var _current_batch_loaded: int = 0
var _loading_batch: bool = false
var _config_cache: Dictionary[String, Dictionary] = {}
var _max_config_cache_size: int = 100

func _get_package_config_cached(directory: String) -> Dictionary:
	if _config_cache.has(directory):
		return _config_cache[directory]

	var config: Dictionary = _get_package_config(directory)

	if _config_cache.size() >= _max_config_cache_size:
		var keys: Array[String] = _config_cache.keys()
		_config_cache.erase(keys[0])

	_config_cache[directory] = config
	return config

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if not process_in_physics_frame:
		_process_batch_load(delta)
		
	if _package_event_bus == null:
		if ClassDB.class_exists("PackageEventBus"):
			_package_event_bus = preload("res://addons/gdpackages/classes/package_event_bus.gd")

func _physics_process(delta: float) -> void:
	if process_in_physics_frame:
		_process_batch_load(delta)

func queue_package_for_async_load(package_path: String, group: String = "") -> void:
	var queue_item: Dictionary[String, Variant] = {
		"path": package_path,
		"group": group,
		"dependencies_loaded": false
	}
	_batch_load_queue.append(queue_item)
	
	if not _loading_batch:
		start_batch_load()

func load_packages_async(package_paths: PackedStringArray, group: String = "") -> void:
	for path: String in package_paths:
		queue_package_for_async_load(path, group)

	if not _loading_batch:
		start_batch_load()

func start_batch_load() -> void:
	if _batch_load_queue.is_empty():
		return
	
	_loading_batch = true
	_current_batch_total = _batch_load_queue.size()
	_current_batch_loaded = 0

func _process_batch_load(_delta: float) -> void:
	_process_completed_loads()
	
	if not _loading_batch or _batch_load_queue.is_empty():
		if _loading_batch and _batch_load_queue.is_empty():
			if _threaded_load_requests.is_empty():
				_loading_batch = false
				batch_load_completed.emit()
				if _package_event_bus:
					_package_event_bus.emit("package_async_batch_load_completed", {"total_loaded": _current_batch_loaded, "total_count": _current_batch_total}, "PackageAsyncLoader")
			return
	
	var processed_count: int = 0
	
	while processed_count < max_packages_per_frame and not _batch_load_queue.is_empty():
		var load_info: Dictionary = _batch_load_queue[0]
		
		if not load_info.get("dependencies_loaded", false):
			if _load_dependencies_async(load_info.get("path", "")):
				load_info["dependencies_loaded"] = true
			else:
				_batch_load_queue.push_back(_batch_load_queue.pop_front())
				continue
		else:
			var result: bool = _load_single_package_async(load_info.get("path", ""), load_info.get("group", ""))
			if result:
				_batch_load_queue.pop_front()
				_current_batch_loaded += 1
				batch_load_progress.emit(_current_batch_loaded, _current_batch_total)
				if _package_event_bus:
					_package_event_bus.emit("package_async_load_progress", {"current": _current_batch_loaded, "total": _current_batch_total, "percentage": float(_current_batch_loaded) / float(_current_batch_total) * 100.0}, "PackageAsyncLoader")
	
		processed_count += 1

func _process_completed_loads() -> void:
	var completed_requests: Array[String] =[]
	var requests_count: int = _threaded_load_requests.size()

	if requests_count > 0:
		# ИСПРАВЛЕНО: добавлена типизация массива, возвращаемого .keys()
		var request_ids: Array = _threaded_load_requests.keys()
		for request_id: String in request_ids:
			if not _threaded_load_requests.has(request_id):
				continue

			var request_info: Dictionary[String, Variant] = _threaded_load_requests[request_id]
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(request_id)

			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var loaded_resource: Resource = ResourceLoader.load_threaded_get(request_id)

				if loaded_resource:
					if request_info["type"] == "main_script":
						_finish_package_load(request_info, loaded_resource)
					elif request_info["type"] == "adapter":
						_finish_adapter_load(request_info, loaded_resource)
				else:
					package_load_failed.emit(request_info["package_path"], "Failed to load " + request_info["type"] + " script")
					if _package_event_bus:
						_package_event_bus.emit("package_async_load_failed", {"package_name": request_info["package_path"], "error": "Failed to load " + request_info["type"] + " script"}, "PackageAsyncLoader")
				completed_requests.append(request_id)

			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				package_load_failed.emit(request_info["package_path"], "Failed to load " + request_info["type"] + " script")
				if _package_event_bus:
					_package_event_bus.emit("package_async_load_failed", {"package_name": request_info["package_path"], "error": "Failed to load " + request_info["type"] + " script"}, "PackageAsyncLoader")
				completed_requests.append(request_id)
	
	for request_id: String in completed_requests:
		_threaded_load_requests.erase(request_id)

func _finish_package_load(request_info: Dictionary[String, Variant], loaded_resource: Resource) -> void:
	var package_path: String = request_info["package_path"]
	var group: String = request_info["group"]
	var config: Dictionary = request_info["config"]

	var package_name: String = config.get("name", "")

	if PackageManager.has_package(package_name):
		package_loaded.emit(_packages_cache[package_name])
		if _package_event_bus:
			_package_event_bus.emit("package_async_load_completed", {"package": _packages_cache[package_name], "package_name": package_name}, "PackageAsyncLoader")
		return

	var result: Package = loaded_resource.new()
	if not result is Package:
		package_load_failed.emit(package_path, "Package script does not extend Package class")
		return

	_packages_cache[package_name] = result

	if not group.is_empty():
		_package_groups_cache.get_or_add(group, PackedStringArray()).append(package_name)
	if _group_bit_registry_cache.has(group):
		var bitv: int = _group_bit_registry_cache[group]
		_package_masks_cache[package_name] = _package_masks_cache.get(package_name, 0) | bitv

	_add_package_to_tree_safe(result)

	result._config = config

	var local_adapter_path: String = config.get("adapter", "")
	if not local_adapter_path.is_empty():
		var adapter_path_full: String = package_path.path_join(local_adapter_path)
		ResourceLoader.load_threaded_request(adapter_path_full, "", true, ResourceLoader.CACHE_MODE_REUSE)

		var adapter_request_id: String = adapter_path_full
		_threaded_load_requests[adapter_request_id] = {
			"package_path": package_path,
			"group": group,
			"config": config,
			"package_instance": result,
			"type": "adapter"
		} as Dictionary[String, Variant]
		return

	result._loaded()

	if result.has_signal("ready_complete"):
		result.ready_complete.connect(func() -> void:
			package_loaded.emit(result)
			if _package_event_bus:
				_package_event_bus.emit("package_async_load_completed", {"package": result, "package_name": result.config_get_name()}, "PackageAsyncLoader")
		, CONNECT_ONE_SHOT)
	else:
		package_loaded.emit(result)
		if _package_event_bus:
			_package_event_bus.emit("package_async_load_completed", {"package": result, "package_name": result.config_get_name()}, "PackageAsyncLoader")
	
	if local_adapter_path.is_empty():
		_current_batch_loaded += 1
		batch_load_progress.emit(_current_batch_loaded, _current_batch_total)

func _finish_adapter_load(request_info: Dictionary[String, Variant], loaded_resource: Resource) -> void:
	var _package_path: String = request_info["package_path"]
	var config: Dictionary = request_info["config"]
	var package_instance: Package = request_info["package_instance"]
	var package_name: String = config.get("name", "")

	if loaded_resource:
		var adapter_instance: PackageAdapter = loaded_resource.new()
		if adapter_instance:
			package_instance.adapter = adapter_instance
			_adapters_cache[package_name] = adapter_instance

	package_instance._loaded()

	if package_instance.has_signal("ready_complete"):
		package_instance.ready_complete.connect(func() -> void:
			package_loaded.emit(package_instance)
			if _package_event_bus:
				_package_event_bus.emit("package_async_load_completed", {"package": package_instance, "package_name": package_instance.config_get_name()}, "PackageAsyncLoader")
		, CONNECT_ONE_SHOT)
	else:
		package_loaded.emit(package_instance)
		if _package_event_bus:
			_package_event_bus.emit("package_async_load_completed", {"package": package_instance, "package_name": package_instance.config_get_name()}, "PackageAsyncLoader")
	
	_current_batch_loaded += 1
	batch_load_progress.emit(_current_batch_loaded, _current_batch_total)

func _load_dependencies_async(package_path: String) -> bool:
	var config: Dictionary = _get_package_config_cached(package_path)
	if config.is_empty():
		return false

	var dependencies: Array[String] = config.get("dependencies", [])
	for dep: String in dependencies:
		if not PackageManager.has_package(dep):
			if PackageManager.is_package_registered_lazy(dep):
				if not PackageManager.load_lazy_package(dep):
					return false
			else:
				return false

	return true

var _threaded_load_requests: Dictionary[String, Dictionary] = {}

func _load_single_package_async(package_path: String, group: String = "") -> bool:
	package_load_started.emit(package_path)
	if _package_event_bus:
		_package_event_bus.emit("package_async_load_started", {"package_name": package_path, "path": package_path}, "PackageAsyncLoader")

	var config: Dictionary = _get_package_config_cached(package_path)
	if config.is_empty() or not config.has("script") or not config.has("name"):
		return false

	var package_name: String = config.get("name", "")
	if PackageManager.has_package(package_name):
		package_loaded.emit(PackageManager.packages[package_name])
		return true

	var script_path: String = package_path.path_join(config.get("script", ""))
	
	# ЗАМЕНА: ResourceLoader.exists вместо FileAccess для работы в билде
	if not ResourceLoader.exists(script_path):
		return false

	ResourceLoader.load_threaded_request(script_path, "", true, ResourceLoader.CACHE_MODE_REUSE)

	_threaded_load_requests[script_path] = {
		"package_path": package_path,
		"group": group,
		"config": config,
		"type": "main_script"
	} as Dictionary[String, Variant]

	return false

func _get_package_config(directory: String) -> Dictionary:
	var resource_path: String = directory.path_join("package_config.tres")
	
	# ЗАМЕНА: ResourceLoader.exists
	if ResourceLoader.exists(resource_path):
		var config_resource: PackageConfig = ResourceLoader.load(resource_path, "Resource", ResourceLoader.CACHE_MODE_REUSE) as PackageConfig
		if config_resource:
			return config_resource.to_dict()
	
	var json_path: String = directory.path_join("package.json")
	if FileAccess.file_exists(json_path):
		var text: String = FileAccess.get_file_as_string(json_path)
		var parsed: Dictionary = JSON.parse_string(text)
		if parsed is Dictionary:
			return parsed

	return {}

func _get_package_root(directory: String, config: Dictionary) -> Package:
	var path: String = directory.path_join(config.get("script", ""))
	
	# ЗАМЕНА: ResourceLoader.exists
	if not ResourceLoader.exists(path):
		return null
	
	var loaded_resource: Resource = ResourceLoader.load(path)
	if loaded_resource:
		var result: Package = loaded_resource.new()
		if result is Package:
			return result
	return null

func is_loading() -> bool:
	return _loading_batch

func get_load_progress() -> Dictionary:
	if _current_batch_total == 0:
		return {"current": 0, "total": 0, "percentage": 0.0}
	
	var percentage: float = float(_current_batch_loaded) / float(_current_batch_total) * 100.0
	return {
		"current": _current_batch_loaded,
		"total": _current_batch_total,
		"percentage": percentage
	}

func clear_load_queue() -> void:
	_batch_load_queue.clear()
	_loading_batch = false
	_current_batch_total = 0
	_current_batch_loaded = 0

func _add_package_to_tree_safe(package_node: Node) -> void:
	var root: Node = Engine.get_main_loop().get_root()
	if package_node.get_parent() != null:
		return 
		
	var node_name: String = str(package_node.name) if str(package_node.name) != "" else str(package_node.get_instance_id())
	if not root.has_node(node_name):
		root.call_deferred("add_child", package_node)
