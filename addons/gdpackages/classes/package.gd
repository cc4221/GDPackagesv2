@abstract
class_name Package extends Node

const PackageConfigGlobal: Script = preload("res://addons/gdpackages/classes/package_config.gd")

var PackageEventBusGlobal: Script = preload("res://addons/gdpackages/classes/package_event_bus.gd")

var PackageThreadedResourceManagerGlobal: Script = preload("res://addons/gdpackages/classes/package_threaded_resource_manager.gd")

@export var _config: Dictionary = {}

var adapter: PackageAdapter = null

var sub_adapters: Dictionary = {}

var core: RefCounted = null

@abstract func _loaded() -> void

@abstract func _unloaded() -> void

@abstract func _message(identity: String, message: String) -> void

@abstract func _warning(identity: String, message: String) -> void

@abstract func _error(identity: String, message: String) -> bool

@abstract func _unhandled_error(identity: String, message: String) -> void
@abstract func _handled_error(identity: String, message: String) -> void

func config_get_name() -> String:
	return _config.get("name", "")

func config_get_version() -> String:
	return _config.get("version", "0.0")

func config_get_description() -> String:
	return _config.get("description", "")

func config_get_dependencies() -> PackedStringArray:
	return _config.get("dependencies", [])

func config_set_dependencies(dependencies: PackedStringArray) -> void:
	_config["dependencies"] = dependencies


func emit_message(message: String, identity: String = config_get_name()) -> void:
	PackageManager.emit_message(identity, message)
func emit_group_message(message: String, identity: String = config_get_name()) -> void:
	var package_name: String = config_get_name()
	PackageManager.emit_group_message_from_package(package_name, identity, message)

func emit_warning(message: String, identity: String = config_get_name()) -> void:
	PackageManager.emit_warning(identity, message)

func emit_group_warning(message: String, identity: String = config_get_name()) -> void:
	var package_name: String = config_get_name()
	PackageManager.emit_group_warning_from_package(package_name, identity, message)

func emit_error(message: String, identity: String = config_get_name()) -> void:
	PackageManager.emit_error(identity, message)
func emit_group_error(message: String, identity: String = config_get_name()) -> void:
	var package_name: String = config_get_name()
	PackageManager.emit_group_error_from_package(package_name, identity, message)

func emit_group_mask_message(message: String, mask: int, identity: String = config_get_name()) -> void:
	PackageManager.emit_message_to_group_mask(identity, message, mask)
func log_entry(identity: String, message: String, stack: Array[Dictionary] = []) -> void:
	PackageLogger.log_entry(PackageLogger.EntryType.Message, PackageLogger.LogLevel.INFO, identity, message, stack)


func emit_event(event_name: String, data: Dictionary = {}) -> void:
	PackageEventBusGlobal.emit(event_name, data, config_get_name())

func subscribe_to_event(event_name: String, callback: Callable,
						filter: Callable = Callable()) -> void:
	PackageEventBusGlobal.subscribe(event_name, callback, config_get_name(), filter)

func unsubscribe_from_event(event_name: String, callback: Callable) -> void:
	PackageEventBusGlobal.unsubscribe(event_name, callback)

func get_cached_events(event_name: String, count: int = 10) -> Array:
	return PackageEventBusGlobal.get_cached_events(event_name, count)

func get_package_adapter(target_package_name: String) -> PackageAdapter:
	return PackageManager.get_adapter(target_package_name)

func has_package_or_lazy(package_name: String) -> bool:
	return PackageManager.has_package_or_lazy(package_name)

func load_lazy_package(package_name: String) -> bool:
	return PackageManager.load_lazy_package(package_name)

func register_package(directory: String, group: String = "") -> bool:
	return PackageManager.register_package(directory, group)


func load_resource_async(key: String, path: String, type_hint: String = "", cache_mode: int = 1) -> void:
	PackageThreadedResourceManagerGlobal.load_resource(key, path, type_hint, cache_mode)

func load_resources_async(resources: Array[Array]) -> void:
	PackageThreadedResourceManagerGlobal.load_resources(resources)

func load_resources_group_async(group_name: String, resources: Array[Array], ignore_in_finished: bool = false) -> void:
	PackageThreadedResourceManagerGlobal.load_resources_group(group_name, resources, ignore_in_finished)

func queue_load_resources(resources: Array[Array]) -> void:
	PackageThreadedResourceManagerGlobal.queue_load_resources(resources)

func start_loading(threads_amount: int = -1) -> void:
	PackageThreadedResourceManagerGlobal.start_loading(threads_amount)

func is_loader_idle() -> bool:
	return PackageThreadedResourceManagerGlobal.is_loader_idle()

func get_loader_threads_count() -> int:
	return PackageThreadedResourceManagerGlobal.get_loader_threads_count()

func connect_load_finished(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_load_finished(callable, flags)

func connect_load_progress(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_load_progress(callable, flags)

func connect_load_group(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_load_group(callable, flags)

func connect_load_error(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_load_error(callable, flags)

func connect_load_started(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_load_started(callable, flags)

func connect_loader_idle(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_loader_idle(callable, flags)



func save_resource_async(resource: Resource, path: String = "", flags: int = 0) -> void:
	PackageThreadedResourceManagerGlobal.save_resource(resource, path, flags)

func save_resources_async(resources: Array[Array]) -> void:
	PackageThreadedResourceManagerGlobal.save_resources(resources)

func queue_save_resources(resources: Array[Array]) -> void:
	PackageThreadedResourceManagerGlobal.queue_save_resources(resources)

func start_saving(verify_files_access: bool = false, threads_amount: int = -1) -> void:
	PackageThreadedResourceManagerGlobal.start_saving(verify_files_access, threads_amount)

func is_saver_idle() -> bool:
	return PackageThreadedResourceManagerGlobal.is_saver_idle()

func get_saver_threads_count() -> int:
	return PackageThreadedResourceManagerGlobal.get_saver_threads_count()

func connect_save_finished(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_save_finished(callable, flags)

func connect_save_progress(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_save_progress(callable, flags)

func connect_save_error(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_save_error(callable, flags)

func connect_save_started(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_save_started(callable, flags)

func connect_saver_idle(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManagerGlobal.connect_saver_idle(callable, flags)
