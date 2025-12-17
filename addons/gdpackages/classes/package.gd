# Abstract base class for all packages in the GDPackages system
# This class defines the interface that all packages must implement
@abstract
class_name Package extends Node

# Reference to the PackageConfig class
const PackageConfig = preload("res://addons/gdpackages/classes/package_config.gd")

# Reference to the PackageEventBus for communication between packages
var PackageEventBus = preload("res://addons/gdpackages/classes/package_event_bus.gd")

# Reference to the PackageThreadedResourceManager for async resource loading/saving
var PackageThreadedResourceManager = preload("res://addons/gdpackages/classes/package_threaded_resource_manager.gd")

# Signal emitted when the package is fully loaded and ready
signal ready_complete

# Configuration dictionary containing package metadata (name, version, dependencies, etc.)
@export var _config: Dictionary

# Adapter instance for this package (optional, used for additional functionality)
var adapter: PackageAdapter = null

# Abstract method called when the package is loaded - must be implemented by subclasses
@abstract func _loaded() -> void

# Abstract method called when the package is unloaded - must be implemented by subclasses
@abstract func _unloaded() -> void

# Abstract method for handling messages - must be implemented by subclasses
@abstract func _message(identity: String, message: String) -> void

# Abstract method for handling warnings - must be implemented by subclasses
@abstract func _warning(identity: String, message: String) -> void

# Abstract method for handling errors - must be implemented by subclasses
# Returns true if the error was handled, false if it should be treated as unhandled
@abstract func _error(identity: String, message: String) -> bool

# Abstract method for handling unhandled errors - must be implemented by subclasses
@abstract func _unhandled_error(identity: String, message: String) -> void
# Abstract method for handling handled errors - must be implemented by subclasses
@abstract func _handled_error(identity: String, message: String) -> void

# Get the name of this package from its configuration
func config_get_name() -> String:
	return _config.get("name", "")

# Get the version of this package from its configuration
func config_get_version() -> String:
	return _config.get("version", "0.0")

# Get the description of this package from its configuration
func config_get_description() -> String:
	return _config.get("description", "")

# Get the dependencies of this package from its configuration
func config_get_dependencies() -> PackedStringArray:
	return _config.get("dependencies", [])

# Set the dependencies of this package in its configuration
func config_set_dependencies(dependencies: PackedStringArray) -> void:
	_config["dependencies"] = dependencies


# Emit a message to all packages through the PackageManager
func emit_message(message: String, identity: String = config_get_name()) -> void:
	PackageManager.emit_message(identity, message)
# Emit a message to packages in the same group
func emit_group_message(message: String, identity: String = config_get_name()) -> void:
	var package_name = config_get_name()
	PackageManager.emit_group_message_from_package(package_name, identity, message)

# Emit a warning to all packages through the PackageManager
func emit_warning(message: String, identity: String = config_get_name()) -> void:
	PackageManager.emit_warning(identity, message)

# Emit a warning to packages in the same group
func emit_group_warning(message: String, identity: String = config_get_name()) -> void:
	var package_name = config_get_name()
	PackageManager.emit_group_warning_from_package(package_name, identity, message)

# Emit an error to all packages through the PackageManager
func emit_error(message: String, identity: String = config_get_name()) -> void:
	PackageManager.emit_error(identity, message)
# Emit an error to packages in the same group
func emit_group_error(message: String, identity: String = config_get_name()) -> void:
	var package_name = config_get_name()
	PackageManager.emit_group_error_from_package(package_name, identity, message)

# Emit a message to packages that match the specified group mask
func emit_group_mask_message(message: String, mask: int, identity: String = config_get_name()) -> void:
	PackageManager.emit_message_to_group_mask(identity, message, mask)
# Log an entry using the PackageLogger
func log_entry(identity: String, message: String, stack: Array[Dictionary] = []) -> void:
	PackageLogger.log_entry(PackageLogger.EntryType.Message, PackageLogger.LogLevel.INFO, identity, message, stack)


# Emit an event through the PackageEventBus
func emit_event(event_name: String, data: Variant = null) -> void:
	PackageEventBus.emit(event_name, data, config_get_name())

# Subscribe to an event through the PackageEventBus
# Can optionally include a filter callable to only receive events that match certain criteria
func subscribe_to_event(event_name: String, callback: Callable,
						filter: Callable = Callable()) -> void:
	PackageEventBus.subscribe(event_name, callback, config_get_name(), filter)

# Unsubscribe from an event through the PackageEventBus
func unsubscribe_from_event(event_name: String, callback: Callable) -> void:
	PackageEventBus.unsubscribe(event_name, callback)

# Get cached events from the PackageEventBus
func get_cached_events(event_name: String, count: int = 10) -> Array:
	return PackageEventBus.get_cached_events(event_name, count)

# Get the adapter for another package
func get_package_adapter(target_package_name: String) -> PackageAdapter:
	return PackageManager.get_adapter(target_package_name)

# Check if a package or lazy package exists
func has_package_or_lazy(package_name: String) -> bool:
	return PackageManager.has_package_or_lazy(package_name)

# Load a lazy package by name
func load_lazy_package(package_name: String) -> bool:
	return PackageManager.load_lazy_package(package_name)

# Register a package for lazy loading
func register_package(directory: String, group: String = "") -> bool:
	return PackageManager.register_package(directory, group)

# ================================================================================
# THREADED RESOURCE LOADING - Асинхронная загрузка ресурсов
# ================================================================================

# Load a single resource asynchronously
func load_resource_async(key: String, path: String, type_hint: String = "", cache_mode: int = 1) -> void:
	PackageThreadedResourceManager.load_resource(key, path, type_hint, cache_mode)

# Load multiple resources asynchronously
func load_resources_async(resources: Array[Array]) -> void:
	PackageThreadedResourceManager.load_resources(resources)

# Load resources in a group asynchronously
func load_resources_group_async(group_name: String, resources: Array[Array], ignore_in_finished: bool = false) -> void:
	PackageThreadedResourceManager.load_resources_group(group_name, resources, ignore_in_finished)

# Queue resources for loading without starting
func queue_load_resources(resources: Array[Array]) -> void:
	PackageThreadedResourceManager.queue_load_resources(resources)

# Start loading all queued resources
func start_loading(threads_amount: int = -1) -> void:
	PackageThreadedResourceManager.start_loading(threads_amount)

# Check if loader is idle
func is_loader_idle() -> bool:
	return PackageThreadedResourceManager.is_loader_idle()

# Get loader threads count
func get_loader_threads_count() -> int:
	return PackageThreadedResourceManager.get_loader_threads_count()

# Connect to load finished signal
func connect_load_finished(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_load_finished(callable, flags)

# Connect to load progress signal
func connect_load_progress(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_load_progress(callable, flags)

# Connect to load group signal
func connect_load_group(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_load_group(callable, flags)

# Connect to load error signal
func connect_load_error(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_load_error(callable, flags)

# Connect to load started signal
func connect_load_started(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_load_started(callable, flags)

# Connect to loader idle signal
func connect_loader_idle(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_loader_idle(callable, flags)


# ================================================================================
# THREADED RESOURCE SAVING - Асинхронное сохранение ресурсов
# ================================================================================

# Save a single resource asynchronously
func save_resource_async(resource: Resource, path: String = "", flags: int = 0) -> void:
	PackageThreadedResourceManager.save_resource(resource, path, flags)

# Save multiple resources asynchronously
func save_resources_async(resources: Array[Array]) -> void:
	PackageThreadedResourceManager.save_resources(resources)

# Queue resources for saving without starting
func queue_save_resources(resources: Array[Array]) -> void:
	PackageThreadedResourceManager.queue_save_resources(resources)

# Start saving all queued resources
func start_saving(verify_files_access: bool = false, threads_amount: int = -1) -> void:
	PackageThreadedResourceManager.start_saving(verify_files_access, threads_amount)

# Check if saver is idle
func is_saver_idle() -> bool:
	return PackageThreadedResourceManager.is_saver_idle()

# Get saver threads count
func get_saver_threads_count() -> int:
	return PackageThreadedResourceManager.get_saver_threads_count()

# Connect to save finished signal
func connect_save_finished(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_save_finished(callable, flags)

# Connect to save progress signal
func connect_save_progress(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_save_progress(callable, flags)

# Connect to save error signal
func connect_save_error(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_save_error(callable, flags)

# Connect to save started signal
func connect_save_started(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_save_started(callable, flags)

# Connect to saver idle signal
func connect_saver_idle(callable: Callable, flags: int = 0) -> int:
	return PackageThreadedResourceManager.connect_saver_idle(callable, flags)
