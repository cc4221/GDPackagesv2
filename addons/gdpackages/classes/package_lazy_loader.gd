# PackageLazyLoader handles loading packages on demand rather than at startup
# This helps reduce initial loading time and memory usage by only loading packages when needed
class_name PackageLazyLoader extends RefCounted

# Preload the PackageConfig class
const PackageConfig = preload("res://addons/gdpackages/classes/package_config.gd")

# Кэшированные ссылки на часто используемые словари для оптимизации производительности
var _available_packages_cache: Dictionary = {}
var _loaded_packages_cache: Dictionary = {}
var _package_dependencies_cache: Dictionary = {}

# Dictionary mapping package names to their file paths
var _available_packages: Dictionary = {}
# Dictionary of packages that have been loaded
var _loaded_packages: Dictionary = {}
# Dictionary mapping package names to their dependencies
var _package_dependencies: Dictionary = {}

# Register a package with its path and dependencies for lazy loading
func register_package(package_path: String, package_name: String, dependencies: PackedStringArray = []) -> void:
	_available_packages[package_name] = package_path
	_available_packages_cache[package_name] = package_path
	_package_dependencies[package_name] = dependencies
	_package_dependencies_cache[package_name] = dependencies

# Load a package and its dependencies if not already loaded
func load_package(package_name: String) -> Package:
	if _loaded_packages_cache.has(package_name):
		return _loaded_packages_cache[package_name]
	
	if not _available_packages_cache.has(package_name):
		push_error("Package not found: " + package_name)
		return null
	
	# Load dependencies first
	var dependencies = _package_dependencies_cache[package_name] or []
	for dependency_name in dependencies:
		if not _loaded_packages_cache.has(dependency_name):
			load_package(dependency_name)
	
	var package_path = _available_packages_cache[package_name]
	var package = _load_package_without_init(package_path)
	if package:
		package._loaded()
		if package.has_signal("ready_complete"):
			package.ready_complete.connect(func(): pass, CONNECT_ONE_SHOT)
		_loaded_packages[package_name] = package
		_loaded_packages_cache[package_name] = package
	
	return package

# Internal function to load a package without calling its initialization methods
func _load_package_without_init(directory: String) -> Package:
	var config := _get_package_config(directory)
	if config.is_empty():
		push_error("error, package has no config.")
		return null
	if !config.has("script"):
		push_error("error, package config is missing script.")
		return null
	if !config.has("name"):
		push_error("error, package config is missing name.")
		return null

	var root := _get_package_root(directory, config)
	if root == null:
		push_error("error, failed to load package script.")
		return null

	var package_name: String = config.get("name", "")
	PackageManager.packages[package_name] = root

	# ДОБАВИТЬ ПАКЕТ В ДЕРЕВО СЦЕНЫ
	if not root.is_inside_tree():
		var root_node = Engine.get_main_loop().get_root()
		if root_node:
			root_node.call_deferred("add_child", root)

	root._config = config
	
	var adapter_path = config.get("adapter", "")
	if !adapter_path.is_empty():
		var adapter_script = load(directory.path_join(adapter_path))
		if adapter_script:
			var adapter_instance = adapter_script.new(package_name)
			root.adapter = adapter_instance
			PackageManager._adapters[package_name] = adapter_instance

	return root

# Get the configuration for a package - first try Resource, then fallback to JSON
func _get_package_config(directory: String) -> Dictionary:
	# Try to load from Resource file first
	var resource_path: String = directory.path_join("package_config.tres")
	if FileAccess.file_exists(resource_path):
		var config_resource = ResourceLoader.load(resource_path, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as PackageConfig
		if config_resource:
			return config_resource.to_dict()
	
	# Fallback to JSON file
	var json_path: String = directory.path_join("package.json")
	if FileAccess.file_exists(json_path):
		var text: String = FileAccess.get_file_as_string(json_path)
		if text.is_empty():
			return {}
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			return parsed

	return {}

# Load the root script file for a package and return an instance of it
func _get_package_root(directory: String, config: Dictionary) -> Package:
	var path: String = directory.path_join(config.get("script", ""))
	var result = load(path).new()
	if result is Package:
		return result
	else:
		return null

# Check if a package is already loaded
func is_package_loaded(package_name: String) -> bool:
	return _loaded_packages_cache.has(package_name)

# Unload a package and remove it from the loaded packages list
func unload_package(package_name: String) -> void:
	if _loaded_packages_cache.has(package_name):
		PackageManager.unload_package(package_name)
		_loaded_packages.erase(package_name)
		_loaded_packages_cache.erase(package_name)

# Unload all loaded packages
func unload_all_packages() -> void:
	for package_name in _loaded_packages_cache.keys():
		PackageManager.unload_package(package_name)
	_loaded_packages.clear()
	_loaded_packages_cache.clear()
