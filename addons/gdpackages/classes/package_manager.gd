class_name PackageManager extends Node

const PackageConfig = preload("res://addons/gdpackages/classes/package_config.gd")

const PackageThreadedResourceManager = preload("res://addons/gdpackages/classes/package_threaded_resource_manager.gd")


static var packages: Dictionary[String, Package] = {}
static var lazy_packages: Dictionary = {}
static var package_groups: Dictionary[String, PackedStringArray] = {}
static var group_bit_registry: Dictionary = {}
static var _next_group_bit_index: int = 0
static var package_masks: Dictionary = {}
static var _adapters: Dictionary[String, PackageAdapter] = {}
static var lazy_loading_enabled: bool = true
static var auto_load_dependencies: bool = true
static var hot_reload_enabled: bool = false
static var _async_loader: PackageAsyncLoader = null
static var _async_loader_adding: bool = false
static var _file_mod_times: Dictionary = {}
static var _file_watcher: Node = null

static var _packages_cache = packages
static var _lazy_packages_cache = lazy_packages
static var _package_groups_cache = package_groups
static var _group_bit_registry_cache = group_bit_registry
static var _package_masks_cache = package_masks
static var _adapters_cache = _adapters
static var _file_mod_times_cache = _file_mod_times

static func get_async_loader() -> PackageAsyncLoader:
	if _async_loader == null:
		_async_loader = PackageAsyncLoader.new()
		_async_loader.name = "PackageAsyncLoader"
		_async_loader_adding = false

	if _async_loader.get_parent() == null and not _async_loader_adding:
		var root = Engine.get_main_loop().get_root()
		if root:
			if not root.has_node("PackageAsyncLoader"):
				_async_loader_adding = true
				root.call_deferred("add_child", _async_loader)
			
	return _async_loader

static func get_package(package_name: String) -> Package:
	return _packages_cache.get(package_name, null)

static func has_package_optimized(package_name: String) -> bool:
	return _packages_cache.has(package_name)

static func has_package_or_lazy_optimized(package_name: String) -> bool:
	return _packages_cache.has(package_name) or _lazy_packages_cache.has(package_name)

static func _add_package_to_tree(package_node: Node) -> void:
	if package_node.get_parent() != null:
		return

	var root = Engine.get_main_loop().get_root()
	if root:
		var node_name = package_node.name if package_node.name != "" else str(package_node.get_instance_id())
		if not root.has_node(node_name):
			root.call_deferred("add_child", package_node)

static func set_lazy_loading_enabled(enabled: bool) -> void:
	lazy_loading_enabled = enabled

static func get_lazy_loading_enabled() -> bool:
	return lazy_loading_enabled

static func set_auto_load_dependencies(enabled: bool) -> void:
	auto_load_dependencies = enabled

static func get_auto_load_dependencies() -> bool:
	return auto_load_dependencies

static func set_hot_reload_enabled(enabled: bool) -> void:
	hot_reload_enabled = enabled
	if enabled:
		_initialize_file_watcher()
	else:
		_cleanup_file_watcher()

static func get_hot_reload_enabled() -> bool:
	return hot_reload_enabled

static func get_hot_reload_config() -> Dictionary:
	return {
		"enabled": hot_reload_enabled,
		"watch_interval": _file_watcher.wait_time if _file_watcher else 1.0
	}

static func set_hot_reload_config(config: Dictionary) -> void:
	if config.has("enabled"):
		set_hot_reload_enabled(config.enabled)
	if config.has("watch_interval") and _file_watcher:
		_file_watcher.wait_time = config.watch_interval

static func get_lazy_package_names() -> PackedStringArray:
	return lazy_packages.keys() as PackedStringArray

static func get_all_package_names() -> PackedStringArray:
	var all_names: PackedStringArray = packages.keys() as PackedStringArray
	for lazy_name in lazy_packages.keys():
		all_names.append(lazy_name)
	return all_names

static func _get_package_config(directory: String) -> Dictionary:
	var resource_path: String = directory.path_join("package_config.tres")
	if FileAccess.file_exists(resource_path):
		var config_resource = ResourceLoader.load(resource_path, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
		if config_resource:
			if config_resource is PackageConfig:
				var dict_result = config_resource.to_dict()
				print("Loaded PackageConfig from Resource at ", directory, ": ", dict_result)
				return dict_result
			elif config_resource is Resource:
				var dict_result = {}
				if config_resource.has_meta("name") or ("name" in config_resource):
					dict_result["name"] = config_resource.get_meta("name") if config_resource.has_meta("name") else config_resource.name
					dict_result["script"] = config_resource.get_meta("script") if config_resource.has_meta("script") else ""
					dict_result["version"] = config_resource.get_meta("version") if config_resource.has_meta("version") else "1.0"
					dict_result["description"] = config_resource.get_meta("description") if config_resource.has_meta("description") else ""
					dict_result["adapter"] = config_resource.get_meta("adapter") if config_resource.has_meta("adapter") else ""
					dict_result["dependencies"] = config_resource.get_meta("dependencies") if config_resource.has_meta("dependencies") else []
					if dict_result.get("name") and dict_result.get("script"):
						print("Converted Resource to dict at ", directory, ": ", dict_result)
						return dict_result
				else:
					push_warning("Resource at %s doesn't have required properties (name, script)" % resource_path)
		else:
			push_warning("Failed to load resource at %s" % resource_path)
	
	var json_path: String = directory.path_join("package.json")
	if FileAccess.file_exists(json_path):
		var text: String = FileAccess.get_file_as_string(json_path)
		if text.is_empty():
			return {}
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			print("Loaded package.json from ", directory, ": ", parsed)
			return parsed
		else:
			push_warning("Failed to parse JSON at %s" % json_path)

	push_warning("No package configuration found in directory: %s" % directory)
	return {}

static func _get_type_index(value) -> int:
	if value is int:
		return 1
	elif value is String:
		return 2
	elif value is bool:
		return 3
	else:
		return 0

static func _get_package_root(directory: String, config: Dictionary) -> Package:
	var script_value = config.get("script", "")
	var path: String = ""

	if script_value is String:
		if script_value.begins_with("uid://"):
			var resource_path = script_value
			var resource = ResourceLoader.load(resource_path)
			if resource and resource.resource_path:
				path = resource.resource_path
			else:
				push_warning("Could not load resource by UID: " + script_value + ", trying to find in directory: " + directory)
				var dir_access = DirAccess.open(directory)
				if dir_access:
					dir_access.list_dir_begin()
					var file_name = dir_access.get_next()
					while file_name != "":
						if not dir_access.current_is_dir() and file_name.ends_with(".gd"):
							if file_name != "package_config.tres" and file_name != "package_config.gd":
								path = directory.path_join(file_name)
								break
						file_name = dir_access.get_next()
		else:
			path = directory.path_join(script_value)
	
	var result = load(path).new()
	if result is Package:
		return result
	else:
		return null

static func has_package(package_name: String) -> bool:
	return _packages_cache.has(package_name)

static func has_package_or_lazy(package_name: String) -> bool:
	return _packages_cache.has(package_name) or _lazy_packages_cache.has(package_name)

static func has_group(group_name: String) -> bool:
	return package_groups.has(group_name)

static func get_groups_with_package(package_name: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for group in _package_groups_cache.keys():
		if _package_groups_cache[group].has(package_name):
			result.append(group)
	return result

static func add_package_to_group(package_name: String, group: String) -> void:
	_package_groups_cache.get_or_add(group, PackedStringArray()).append(package_name)
	if not _group_bit_registry_cache.has(group):
		var bit = 1 << _next_group_bit_index
		_group_bit_registry_cache[group] = bit
		_next_group_bit_index += 1
	var bitval = _group_bit_registry_cache[group]
	var curmask = _package_masks_cache.get(package_name, 0)
	_package_masks_cache[package_name] = curmask | bitval

static func remove_package_from_group(package_name: String, group: String) -> void:
	if _package_groups_cache.has(group):
		var idx: int = _package_groups_cache[group].find(package_name)
		if idx > -1:
			_package_groups_cache[group].remove_at(idx)
			if _package_groups_cache[group].is_empty():
				_package_groups_cache.erase(group)
	if group in _group_bit_registry_cache and _package_masks_cache.has(package_name):
		var bitval = _group_bit_registry_cache[group]
		_package_masks_cache[package_name] = _package_masks_cache[package_name] & ~bitval
	if _package_masks_cache[package_name] == 0:
		_package_masks_cache.erase(package_name)

static func get_adapter(package_name: String) -> PackageAdapter:
	return _adapters_cache.get(package_name, null)

static func register_package(directory: String, group: String = "") -> bool:
	if not lazy_loading_enabled:
			load_package(directory, group, [])
			return true
	
	print("Registering package from directory: %s" % directory)
	var config := _get_package_config(directory)
	print("Got config: %s" % config)
	if config.is_empty():
		push_error("Error, package has no config at directory: %s" % directory)
		return false
	if !config.has("script"):
		push_error("Error, package config is missing script at %s. Config keys: %s" % [directory, config.keys()])
		return false
	if !config.has("name"):
		push_error("Error, package config is missing name at %s. Config keys: %s" % [directory, config.keys()])
		return false
	
	var package_name: String = config.get("name", "")
	
	if has_package(package_name) or _lazy_packages_cache.has(package_name):
		push_warning("Package '" + package_name + "' is already registered or loaded.")
		return false
	
	_lazy_packages_cache[package_name] = {
		"directory": directory,
		"config": config,
		"group": group
	}
	
	if !group.is_empty():
		_package_groups_cache.get_or_add(group, PackedStringArray()).append(package_name)
		if not _group_bit_registry_cache.has(group):
			var bit = 1 << _next_group_bit_index
			_group_bit_registry_cache[group] = bit
			_next_group_bit_index += 1
		var bitval = _group_bit_registry_cache[group]
		var curmask = _package_masks_cache.get(package_name, 0)
		_package_masks_cache[package_name] = curmask | bitval
	
	PackageLogger.log_info("PackageManager", "Registered package '" + package_name + "' for lazy loading")
	return true

static func register_packages_in_directory(directory_path: String, group: String = directory_path) -> void:
	if not lazy_loading_enabled:
		load_packages_in_directory(directory_path, group, [])
	return
	
	var dirs := DirAccess.get_directories_at(directory_path)
	for dir in dirs:
		register_package(directory_path.path_join(dir), group)

static func load_package(directory: String, group: String = "", dependency_chain: Array[String] = []) -> void:
	var config := _get_package_config(directory)
	if config.is_empty():
		push_error("error, package has no config.")
		return
	if !config.has("script"):
		push_error("error, package config is missing script.")
		return
	if !config.has("name"):
		push_error("error, package config is missing name.")
		return
	
	var package_name: String = config.get("name", "")
	
	if package_name in dependency_chain:
		var circular_chain = dependency_chain.duplicate()
		var package_index = circular_chain.find(package_name)
		if package_index != -1:
			var circular_part = circular_chain.slice(package_index, -1)
			circular_part.append(package_name)
			push_error("Circular dependency detected: " + " -> ".join(circular_part))
			
			var unique_packages_in_cycle = []
			for pkg in circular_part:
				if pkg not in unique_packages_in_cycle:
					unique_packages_in_cycle.append(pkg)
			
			if unique_packages_in_cycle.size() > 1:
				push_error("Packages involved in circular dependency: " + ", ".join(unique_packages_in_cycle))
		else:
			circular_chain.append(package_name)
			push_error("Circular dependency detected: " + " -> ".join(circular_chain))
		return
	
	var dependencies: Array = config.get("dependencies", [])
	var dependencies_str: Array[String] = []
	for dep in dependencies:
		dependencies_str.append(str(dep))
	
	for dep_str in dependencies_str:
		if not has_package(dep_str):
			if lazy_loading_enabled and auto_load_dependencies and lazy_packages.has(dep_str):
				var new_dependency_chain = dependency_chain.duplicate()
				new_dependency_chain.append(package_name)
				if not load_lazy_package(dep_str, new_dependency_chain):
					return
			else:
				push_error("error, package '" + config.get("name", "") + "' requires dependency '" + dep_str + "' which is not loaded.")
				return
	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("package_loading", {"directory": directory, "config": config, "group": group}, "PackageManager")
	
	var root := _get_package_root(directory, config)
	if root == null:
		push_error("error, failed to load package script.")
		return
	
	packages[package_name] = root
	if !group.is_empty():
		_package_groups_cache.get_or_add(group, PackedStringArray()).append(package_name)
	if _group_bit_registry_cache.has(group):
			var bitv = _group_bit_registry_cache[group]
			_package_masks_cache[package_name] = _package_masks_cache.get(package_name, 0) | bitv

	_add_package_to_tree(root)
	
	root._config = config
	
	var core_value = config.get("core", "")
	if core_value != "":
		var core_path = directory.path_join(core_value)
		var core_script = load(core_path)
		if core_script:
			root.core = core_script.new()
	
	var adapter_value = config.get("adapter", "")
	if adapter_value and adapter_value != "":
		var adapter_path: String = ""

		if adapter_value is String:
			if adapter_value.begins_with("uid://"):
				var resource_path = adapter_value
				var resource = ResourceLoader.load(resource_path)
				if resource and resource.resource_path:
					adapter_path = resource.resource_path
				else:
					push_warning("Could not load adapter resource by UID: " + adapter_value + ", trying to find in directory: " + directory)
					var dir_access = DirAccess.open(directory)
					if dir_access:
						dir_access.list_dir_begin()
						var file_name = dir_access.get_next()
						while file_name != "":
							if not dir_access.current_is_dir() and file_name.ends_with("_adapter.gd"):
								adapter_path = directory.path_join(file_name)
								break
							file_name = dir_access.get_next()
			else:
				adapter_path = directory.path_join(adapter_value)
		
		if adapter_path != "":
			var adapter_script = load(adapter_path)
			if adapter_script:
				var adapter_instance = adapter_script.new()
				root.adapter = adapter_instance
				_adapters_cache[package_name] = adapter_instance
				
				if ClassDB.class_exists("PackageEventBus") and adapter_instance.has_method("subscribe_to_events"):
					adapter_instance.subscribe_to_events()

	root._loaded()
	
	if root.has_signal("ready_complete"):
		root.ready_complete.connect(func(): pass, CONNECT_ONE_SHOT)
	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("package_loaded", {"package_name": package_name}, "PackageManager")
	
	if hot_reload_enabled:
		_add_package_to_watch(package_name)

static func load_packages_in_directory(directory_path: String, group: String = directory_path, dependency_chain: Array[String] = []) -> void:
	var dirs := DirAccess.get_directories_at(directory_path)
	print("Found directories in %s: %s" % [directory_path, dirs])
	
	for dir in dirs:
		var package_dir = directory_path.path_join(dir)
		print("Registering package from: %s" % package_dir)
		register_package(package_dir, group)
	
	var all_registered_packages = lazy_packages.keys()
	for package_name in all_registered_packages:
		if not has_package(package_name):
			if lazy_packages.has(package_name):
				if not load_lazy_package(package_name, dependency_chain):
					push_warning("Stopping package loading due to dependency error.")
					return

static func load_lazy_package(package_name: String, dependency_chain: Array[String] = []) -> bool:
	if not lazy_loading_enabled:
			push_warning("Lazy loading is disabled, cannot load lazy package '" + package_name + "'")
			return false
	
	if not lazy_packages.has(package_name):
		if has_package(package_name):
			push_warning("Package '" + package_name + "' is already loaded")
			return true
		else:
			push_error("Package '" + package_name + "' is not registered for lazy loading")
			return false
	
	if package_name in dependency_chain:
		var circular_chain = dependency_chain.duplicate()
		var package_index = circular_chain.find(package_name)
		if package_index != -1:
			var circular_part = circular_chain.slice(package_index, -1)
			circular_part.append(package_name)
			push_error("Circular dependency detected: " + " -> ".join(circular_part))
			
			var unique_packages_in_cycle = []
			for pkg in circular_part:
				if pkg not in unique_packages_in_cycle:
					unique_packages_in_cycle.append(pkg)
			
			if unique_packages_in_cycle.size() > 1:
				push_error("Packages involved in circular dependency: " + ", ".join(unique_packages_in_cycle))
		else:
			circular_chain.append(package_name)
			push_error("Circular dependency detected: " + " -> ".join(circular_chain))
		return false
	
	var package_info = lazy_packages[package_name]
	var directory = package_info.get("directory", "")
	var config = package_info.get("config", {})
	var group = package_info.get("group", "")
	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("package_loading", {"directory": directory, "config": config, "group": group, "lazy": true}, "PackageManager")
	
	if auto_load_dependencies:
		var dependencies: Array = config.get("dependencies", [])
		for dep in dependencies:
			if not has_package(str(dep)):
				if lazy_packages.has(str(dep)):
					var new_dependency_chain = dependency_chain.duplicate()
					new_dependency_chain.append(package_name)
					if not load_lazy_package(str(dep), new_dependency_chain):
						return false
				else:
					push_error("Error, package '" + package_name + "' requires dependency '" + str(dep) + "' which is not registered or loaded.")
					return false

	var root := _get_package_root(directory, config)
	if root == null:
		push_error("Error, failed to load package script for '" + package_name + "'.")
		return false
	
	packages[package_name] = root

	_add_package_to_tree(root)
	
	root._config = config
	
	var core_value = config.get("core", "")
	if core_value != "":
		var core_path = directory.path_join(core_value)
		var core_script = load(core_path)
		if core_script:
			root.core = core_script.new()
	
	_lazy_packages_cache.erase(package_name)
	
	var adapter_value = config.get("adapter", "")
	if adapter_value and adapter_value != "":
		var adapter_path: String = ""

		if adapter_value is String:
			if adapter_value.begins_with("uid://"):
				var resource_path = adapter_value
				var resource = ResourceLoader.load(resource_path)
				if resource and resource.resource_path:
					adapter_path = resource.resource_path
				else:
					push_warning("Could not load adapter resource by UID: " + adapter_value + ", trying to find in directory: " + directory)
					var dir_access = DirAccess.open(directory)
					if dir_access:
						dir_access.list_dir_begin()
						var file_name = dir_access.get_next()
						while file_name != "":
							if not dir_access.current_is_dir() and file_name.ends_with("_adapter.gd"):
								adapter_path = directory.path_join(file_name)
								break
							file_name = dir_access.get_next()
			else:
				adapter_path = directory.path_join(adapter_value)
		
		if adapter_path != "":
			var adapter_script = load(adapter_path)
			if adapter_script:
				var adapter_instance = adapter_script.new(package_name)
				root.adapter = adapter_instance
				_adapters_cache[package_name] = adapter_instance
				
				if ClassDB.class_exists("PackageEventBus") and adapter_instance.has_method("subscribe_to_events"):
					adapter_instance.subscribe_to_events()

	root._loaded()
	
	if root.has_signal("ready_complete"):
		root.ready_complete.connect(func(): pass, CONNECT_ONE_SHOT)
	
	PackageLogger.log_info("PackageManager", "Loaded lazy package '" + package_name + "'")
	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("package_loaded", {"package_name": package_name, "lazy": true}, "PackageManager")
	
	if hot_reload_enabled:
		_add_package_to_watch(package_name)
	
	return true

static func load_lazy_packages(package_names: Array[String]) -> Dictionary:
	var results: Dictionary = {}
	for package_name in package_names:
		results[package_name] = load_lazy_package(package_name)
	return results

static func is_package_registered_lazy(package_name: String) -> bool:
	return lazy_packages.has(package_name)

static func get_lazy_package_info(package_name: String) -> Dictionary:
	return lazy_packages.get(package_name, {})

static func load_all_lazy_packages() -> Dictionary:
	var results: Dictionary = {}
	for package_name in lazy_packages.keys():
		results[package_name] = load_lazy_package(package_name)
	return results

static func unload_package(package_name: String) -> bool:
	if not has_package(package_name):
		PackageLogger.log_warning("PackageManager", "Cannot unload package '" + package_name + "', it is not loaded")
		return false
	
	var dependents = get_packages_dependent_on(package_name)
	if dependents.size() > 0:
		PackageLogger.log_error("PackageManager", "Cannot unload package '" + package_name + "' because the following packages depend on it: " + str(dependents))
		return false
	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("package_unloading", {"package_name": package_name}, "PackageManager")
	
	var package = packages[package_name]
	
	for group in get_groups_with_package(package_name):
		remove_package_from_group(package_name, group)
	
	package._unloaded()

	if package.is_inside_tree():
		if package.get_parent():
			package.get_parent().remove_child(package)
	package.queue_free()
	
	packages.erase(package_name)
	
	if _package_masks_cache.has(package_name):
		_package_masks_cache.erase(package_name)
	if _adapters_cache.has(package_name):
		var adapter = _adapters_cache[package_name]
		if ClassDB.class_exists("PackageEventBus") and adapter.has_method("unsubscribe_from_events"):
			adapter.unsubscribe_from_events()
		_adapters_cache.erase(package_name)

	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("package_unloaded", {"package_name": package_name}, "PackageManager")
	
	if hot_reload_enabled:
		_remove_package_from_watch(package_name)
	
	PackageLogger.log_info("PackageManager", "Unloaded package '" + package_name + "'")
	return true

static func unload_packages_in_group(group: String) -> Array[String]:
	if not has_group(group):
		PackageLogger.log_warning("PackageManager", "Cannot unload packages in group '" + group + "', group does not exist")
		return []
	
	var names: PackedStringArray = package_groups[group].duplicate()
	var results: Array[String] = []
	for package_name in names:
		var dependents = get_packages_dependent_on(package_name)
		var external_dependents = []
		for dep in dependents:
			if dep not in names:
				external_dependents.append(dep)
		if external_dependents.size() > 0:
			PackageLogger.log_error("PackageManager", "Cannot unload package '" + package_name + "' from group '" + group + "' because the following external packages depend on it: " + str(external_dependents))
			return []

	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("packages_unloading_in_group", {"group": group, "package_names": names}, "PackageManager")
	
	for package_name in names:
		if unload_package(package_name):
			results.append(package_name)
	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("packages_unloaded_from_group", {"group": group, "package_names": results}, "PackageManager")
	
	return results

static func unload_all_packages() -> void:
	var results = unload_all_packages_safe()
	if results.is_empty():
		if ClassDB.class_exists("PackageEventBus"):
			PackageEventBus.emit("force_unloading_all_packages", {"package_count": packages.size()}, "PackageManager")
		
		for package in _packages_cache.values():
			package._unloaded()
		_packages_cache.clear()
		
		_lazy_packages_cache.clear()
		
		for group_name in _package_groups_cache.keys():
			_package_groups_cache[group_name] = PackedStringArray()

		if _async_loader:
			if _async_loader.is_inside_tree():
				if _async_loader.get_parent():
					_async_loader.get_parent().remove_child(_async_loader)
			_async_loader.queue_free()
			_async_loader = null
		_async_loader_adding = false
		
		if ClassDB.class_exists("PackageEventBus"):
			PackageEventBus.emit("all_packages_force_unloaded", {"package_count": packages.size()}, "PackageManager")

static func clear_lazy_packages() -> void:
	_lazy_packages_cache.clear()

static func emit_message(identity: StringName, message: String) -> void:
	for package in _packages_cache.values():
		package._message(str(identity), message)
	PackageLogger.log_info(str(identity), message)

static func emit_message_to_group(identity: StringName, message: String, group: String) -> void:
	var packages_in_group: PackedStringArray = _package_groups_cache.get(group, PackedStringArray([]))
	for package_name in packages_in_group:
		var package = _packages_cache.get(package_name, null)
		if package != null:
			package._message(str(identity), message)
	PackageLogger.log_info(str(identity) + "@" + group, message)

static func emit_message_to_group_mask(identity: StringName, message: String, mask: int) -> void:
	for package_name in _packages_cache.keys():
		var pmask = _package_masks_cache.get(package_name, 0)
		if pmask & mask != 0:
			_packages_cache[package_name]._message(str(identity), message)
	PackageLogger.log_info(str(identity) + "@mask", message)

static func emit_warning(identity: StringName, message: String) -> void:
	for package in _packages_cache.values():
		package._warning(str(identity), message)
	PackageLogger.log_warning(str(identity), message)

static func emit_warning_to_group(identity: String, message: String, group: String) -> void:
	var packages_in_group: PackedStringArray = _package_groups_cache.get(group, [])
	for package_name in packages_in_group:
		var package = _packages_cache.get(package_name, null)
		if package != null:
			package._warning(identity, message)
	PackageLogger.log_warning(identity + "@" + group, message)

static func emit_warning_to_group_mask(identity: String, message: String, mask: int) -> void:
	for package_name in _packages_cache.keys():
		var pmask = _package_masks_cache.get(package_name, 0)
		if pmask & mask != 0:
			var package = _packages_cache.get(package_name, null)
			if package != null:
				package._warning(identity, message)
	PackageLogger.log_warning(identity + "@mask", message)

static func emit_handled_error(identity: String, message: String) -> void:
	for package in _packages_cache.values():
		package._handled_error(identity, message)
	PackageLogger.log_handled_error(identity, message)

static func emit_handled_error_to_group(identity: String, message: String, group: String) -> void:
	var packages_in_group: PackedStringArray = _package_groups_cache.get(group, [])
	for package_name in packages_in_group:
		var package = _packages_cache.get(package_name, null)
		if package != null:
			package._handled_error(identity, message)
	PackageLogger.log_handled_error(identity + "@" + group, message)

static func emit_handled_error_to_group_mask(identity: String, message: String, mask: int) -> void:
	for package_name in _packages_cache.keys():
		var pmask = _package_masks_cache.get(package_name, 0)
		if pmask & mask != 0:
			var package = _packages_cache.get(package_name, null)
			if package != null:
				package._handled_error(identity, message)
	PackageLogger.log_handled_error(identity + "@mask", message)

static func emit_unhandled_error(identity: String, message: String) -> void:
	for package in _packages_cache.values():
		package._unhandled_error(identity, message)
	PackageLogger.log_error(identity, message)

static func emit_unhandled_error_to_group(identity: String, message: String, group: String) -> void:
	var packages_in_group: PackedStringArray = _package_groups_cache.get(group, [])
	for package_name in packages_in_group:
		var package = _packages_cache.get(package_name, null)
		if package != null:
			package._unhandled_error(identity, message)
	PackageLogger.log_error(identity + "@" + group, message)

static func emit_unhandled_error_to_group_mask(identity: String, message: String, mask: int) -> void:
	for package_name in _packages_cache.keys():
		var pmask = _package_masks_cache.get(package_name, 0)
		if pmask & mask != 0:
			var package = _packages_cache.get(package_name, null)
			if package != null:
				package._unhandled_error(identity, message)
	PackageLogger.log_error(identity + "@mask", message)

static func emit_error(identity: StringName, message: String) -> void:
	var handled: bool = false
	for package in _packages_cache.values():
		if package._error(str(identity), message):
			handled = true
			break
	
	if handled:
		for package in _packages_cache.values():
			package._handled_error(str(identity), message)
		PackageLogger.log_handled_error(str(identity), message)
	else:
		for package in _packages_cache.values():
			package._unhandled_error(str(identity), message)
		PackageLogger.log_error(str(identity), message)

static func emit_error_to_group(identity: String, message: String, group: String) -> void:
	var packages_in_group: PackedStringArray = _package_groups_cache.get(group, [])
	var handled: bool = false
	
	for package_name in packages_in_group:
		var package = _packages_cache.get(package_name, null)
		if package != null and package._error(identity, message):
			handled = true
			break
	
	if handled:
		for package_name in packages_in_group:
			var package = _packages_cache.get(package_name, null)
			if package != null:
				package._handled_error(identity, message)
		PackageLogger.log_handled_error(identity + "@" + group, message)
	else:
		for package_name in packages_in_group:
			var package = _packages_cache.get(package_name, null)
			if package != null:
				package._unhandled_error(identity, message)
		PackageLogger.log_error(identity + "@" + group, message)

static func emit_error_to_group_mask(identity: String, message: String, mask: int) -> void:
	var handled: bool = false
	for package_name in _packages_cache.keys():
		var pmask = _package_masks_cache.get(package_name, 0)
		if pmask & mask != 0:
			var package = _packages_cache.get(package_name, null)
			if package != null and package._error(identity, message):
				handled = true
				break
	if handled:
		for package_name in _packages_cache.keys():
			var pmask = _package_masks_cache.get(package_name, 0)
			if pmask & mask != 0:
				var package = _packages_cache.get(package_name, null)
				if package != null:
					package._handled_error(identity, message)
		PackageLogger.log_handled_error(identity + "@mask", message)
	else:
		for package_name in _packages_cache.keys():
			var pmask = _package_masks_cache.get(package_name, 0)
			if pmask & mask != 0:
				var package = _packages_cache.get(package_name, null)
				if package != null:
					package._unhandled_error(identity, message)
	PackageLogger.log_error(identity + "@mask", message)

static func emit_group_message_from_package(package_name: String, identity: String, message: String) -> void:
	var groups = get_groups_with_package(package_name)
	for group in groups:
		emit_message_to_group(identity, message, group)

static func emit_group_warning_from_package(package_name: String, identity: String, message: String) -> void:
	var groups = get_groups_with_package(package_name)
	for group in groups:
		emit_warning_to_group(identity, message, group)

static func emit_group_error_from_package(package_name: String, identity: String, message: String) -> void:
	var groups = get_groups_with_package(package_name)
	for group in groups:
		emit_error_to_group(identity, message, group)

static func load_package_async(package_path: String, group: String = "") -> void:
	var async_loader = get_async_loader()
	async_loader.queue_package_for_async_load(package_path, group)

static func load_packages_async(package_paths: PackedStringArray, group: String = "") -> void:
	var async_loader = get_async_loader()
	async_loader.load_packages_async(package_paths, group)

static func is_loading_async() -> bool:
	var async_loader = get_async_loader()
	if async_loader:
		return async_loader.is_loading()
	return false

static func get_async_load_progress() -> Dictionary:
	var async_loader = get_async_loader()
	if async_loader:
		return async_loader.get_load_progress()
	return {"current": 0, "total": 0, "percentage": 0.0}

static func clear_async_load_queue() -> void:
	var async_loader = get_async_loader()
	if async_loader:
		async_loader.clear_load_queue()

static func reload_package(package_name: String) -> bool:
	if not has_package(package_name):
		push_warning("Package '" + package_name + "' is not loaded, cannot reload")
		return false
	
	var package = packages[package_name]
	var package_directory = ""
	
	if package._config.has("script"):
		var script_path = package._config.get("script", "")
		package_directory = script_path.get_base_dir()
	
	if package_directory.is_empty():
		push_error("Could not determine directory for package '" + package_name + "'")
		return false
	
	unload_package(package_name)
	
	load_package(package_directory, _get_package_group(package_name), [])
	
	if packages.has(package_name):
		var reloaded_package = packages[package_name]
		if reloaded_package._config.has("script"):
			var script_path = reloaded_package._config.get("script", "")
			if FileAccess.file_exists(script_path):
				var current_mod_time = FileAccess.get_modified_time(script_path)
				_file_mod_times[script_path] = current_mod_time
	
	if hot_reload_enabled:
		_add_package_to_watch(package_name)
	
	_handle_package_reload_events(package_name)
	
	_reload_package_dependencies(package_name)
	
	return true

static func reload_packages_in_group(group: String) -> void:
	if package_groups.has(group):
		var names: PackedStringArray = package_groups[group].duplicate()
		for package_name in names:
			reload_package(package_name)

static func reload_all_packages() -> void:
	var package_names: PackedStringArray = packages.keys() as PackedStringArray
	for package_name in package_names:
		reload_package(package_name)

static func _get_package_group(package_name: String) -> String:
	for group_name in package_groups.keys():
		if package_groups[group_name].has(package_name):
			return group_name
	return ""

static func _initialize_file_watcher() -> void:
	if _file_watcher:
		return
	
	_file_watcher = Timer.new()
	_file_watcher.name = "PackageManagerFileWatcher"
	_file_watcher.wait_time = 1.0
	_file_watcher.timeout.connect(_check_file_changes)
	_file_watcher.autostart = true
	
	var root = Engine.get_main_loop().get_root()
	if root:
		if _file_watcher.get_parent() == null:
			root.call_deferred("add_child", _file_watcher)

static func _cleanup_file_watcher() -> void:
	if _file_watcher:
		_file_watcher.stop()
		if _file_watcher.is_inside_tree():
			_file_watcher.get_parent().remove_child(_file_watcher)
		_file_watcher = null

static func _check_file_changes() -> void:
	if not hot_reload_enabled:
		return
	
	for package_name in packages.keys():
		var package = packages[package_name]
		if package._config.has("script"):
			var script_path = package._config.get("script", "")
			if FileAccess.file_exists(script_path):
				var current_mod_time = FileAccess.get_modified_time(script_path)
				var previous_mod_time = _file_mod_times.get(script_path, 0)
				
				if current_mod_time > previous_mod_time:
					PackageLogger.log_info("PackageManager", "Detected change in package '" + package_name + "', reloading...")
					_file_mod_times[script_path] = current_mod_time
					reload_package(package_name)

static func _add_file_to_watch(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		var mod_time = FileAccess.get_modified_time(file_path)
		_file_mod_times[file_path] = mod_time

static func _add_package_to_watch(package_name: String) -> void:
	if has_package(package_name):
		var package = packages[package_name]
		if package._config.has("script"):
			var script_path = package._config.get("script", "")
			if FileAccess.file_exists(script_path):
				_add_file_to_watch(script_path)
				
				var adapter_path = package._config.get("adapter", "")
				if not adapter_path.is_empty() and FileAccess.file_exists(adapter_path):
					_add_file_to_watch(adapter_path)
				
				var watch_files = package._config.get("watch_files", [])
				if watch_files is Array:
					for watch_file in watch_files:
						if watch_file is String and FileAccess.file_exists(watch_file):
							_add_file_to_watch(watch_file)

static func _reload_package_dependencies(package_name: String) -> void:
	if has_package(package_name):
		var package = packages[package_name]
		var dependencies: Array = package._config.get("dependencies", [])
		for dep in dependencies:
			if has_package(str(dep)):
				var dep_package = packages[str(dep)]
				var dep_dependencies: Array = dep_package._config.get("dependencies", [])
				if package_name in dep_dependencies:
					reload_package(str(dep))

static func _handle_package_reload_events(package_name: String) -> void:
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("package_reloading", {"package_name": package_name}, "PackageManager")
	
static func get_packages_dependent_on(package_name: String) -> PackedStringArray:
	var dependents: PackedStringArray = []
	for pkg_name in packages.keys():
		var pkg = packages[pkg_name]
		if pkg._config.has("dependencies"):
			var dependencies: Array = pkg._config.get("dependencies", [])
			for dep in dependencies:
				if str(dep) == package_name:
					dependents.append(pkg_name)
	return dependents

static func can_unload_package(package_name: String) -> bool:
	var dependents = get_packages_dependent_on(package_name)
	return dependents.is_empty()

static func are_dependencies_loaded(package_name: String) -> bool:
	if not packages.has(package_name):
		return false
	
	var pkg = packages[package_name]
	if not pkg._config.has("dependencies"):
		return true
	
	var dependencies: Array = pkg._config.get("dependencies", [])
	for dep in dependencies:
		if not packages.has(str(dep)):
			return false

	return true

static func get_missing_dependencies(package_name: String) -> Array[String]:
	if not has_package_or_lazy(package_name):
		return []
	
	var config = {}
	if has_package(package_name):
		config = packages[package_name]._config
	elif lazy_packages.has(package_name):
		config = lazy_packages[package_name].get("config", {})
	
	if not config.has("dependencies"):
		return []
	
	var dependencies: Array = config.get("dependencies", [])
	var missing_deps: PackedStringArray = []
	for dep in dependencies:
		var dep_str = str(dep)
		if not has_package(dep_str) and not is_package_registered_lazy(dep_str):
			missing_deps.append(dep_str)
	
	return missing_deps

static func get_package_dependencies(package_name: String) -> PackedStringArray:
	if not has_package(package_name):
		return PackedStringArray([])
	var pkg = packages[package_name]
	if pkg._config.has("dependencies"):
		var deps_array = pkg._config.get("dependencies", [])
		var deps_string_array: PackedStringArray = []
		for dep in deps_array:
			deps_string_array.append(str(dep))
		return deps_string_array
	return PackedStringArray([])

static func _remove_package_from_watch(package_name: String) -> void:
	if has_package(package_name):
		var package = packages[package_name]
		if package._config.has("script"):
			var script_path = package._config.get("script", "")
			if script_path in _file_mod_times:
				_file_mod_times.erase(script_path)
			
			var adapter_path = package._config.get("adapter", "")
			if not adapter_path.is_empty() and adapter_path in _file_mod_times:
				_file_mod_times.erase(adapter_path)
			
			var watch_files = package._config.get("watch_files", [])
			if watch_files is Array:
				for watch_file in watch_files:
					if watch_file is String and watch_file in _file_mod_times:
						_file_mod_times.erase(watch_file)

static func unload_all_packages_safe() -> Array[String]:
	var results: Array[String] = []
	
	var package_names: Array = packages.keys()
	
	for package_name in package_names:
		var dependents = get_packages_dependent_on(package_name)
		if dependents.size() > 0:
			PackageLogger.log_error("PackageManager", "Cannot unload all packages: package '" + package_name + "' has dependents: " + str(dependents))
			return []
	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("all_packages_unloading", {"package_count": package_names.size()}, "PackageManager")
	
	for package_name in package_names:
		if unload_package(package_name):
			results.append(package_name)
	
	lazy_packages.clear()
	
	for group_name in package_groups.keys():
		package_groups[group_name] = PackedStringArray()
	
	if _async_loader:
		if _async_loader.is_inside_tree():
			if _async_loader.get_parent():
				_async_loader.get_parent().remove_child(_async_loader)
		_async_loader.queue_free()
		_async_loader = null
	_async_loader_adding = false
	
	if ClassDB.class_exists("PackageEventBus"):
		PackageEventBus.emit("all_packages_unloaded", {"unloaded_count": results.size()}, "PackageManager")
	
	return results

func _exit_tree() -> void:
	unload_all_packages()
	packages.clear()
	lazy_packages.clear()
	package_groups.clear()
	group_bit_registry.clear()
	package_masks.clear()
	_adapters.clear()
	if _file_watcher:
		_file_watcher.stop()
		if _file_watcher.is_inside_tree():
			_file_watcher.get_parent().remove_child(_file_watcher)
		_file_watcher = null
	if _async_loader:
		if _async_loader.get_parent():
			_async_loader.get_parent().remove_child(_async_loader)
		_async_loader.queue_free()
		_async_loader = null
	_async_loader_adding = false

static func get_reverse_dependency_graph() -> Dictionary:
	var reverse_deps: Dictionary = {}
	
	for pkg_name in packages.keys():
		var pkg = packages[pkg_name]
		if pkg._config.has("dependencies"):
			var dependencies: Array = pkg._config.get("dependencies", [])
			for dep in dependencies:
				var dep_name = str(dep)
				if not reverse_deps.has(dep_name):
					reverse_deps[dep_name] = []
				reverse_deps[dep_name].append(pkg_name)
	
	return reverse_deps

static func get_package_dependency_info(package_name: String) -> Dictionary:
	var info = {
	"package": package_name,
		"dependencies": get_package_dependencies(package_name),
		"dependents": get_packages_dependent_on(package_name),
		"can_unload": can_unload_package(package_name),
		"missing_dependencies": get_missing_dependencies(package_name)
	}
	return info

static func validate_dependency_chain(package_name: String) -> Dictionary:
	var result = {
		"valid": true,
		"errors": [],
		"missing_packages": []
	}
	
	if not has_package_or_lazy(package_name):
		result.valid = false
		result.errors.append("Package '%s' does not exist" % package_name)
		return result
	
	var missing_deps = get_missing_dependencies(package_name)
	if missing_deps.size() > 0:
		result.valid = false
		result.missing_packages += missing_deps
		result.errors.append("Package '%s' has missing dependencies: %s" % [package_name, str(missing_deps)])
	
	var all_deps = _get_all_dependencies_recursive(package_name, [])
	for dep_name in all_deps:
		if not has_package_or_lazy(dep_name):
			result.valid = false
			if not result.missing_packages.has(dep_name):
				result.missing_packages.append(dep_name)
			result.errors.append("Dependency '%s' of package '%s' does not exist" % [dep_name, package_name])
	return result

static func load_resource_threaded(key: String, path: String, type_hint: String = "", cache_mode: int = 1) -> void:
	var manager = PackageThreadedResourceManager.get_instance()
	manager.loader.add([[key, path, type_hint, cache_mode]]).start()

static func load_resources_threaded(resources: Array[Array]) -> void:
	var manager = PackageThreadedResourceManager.get_instance()
	manager.loader.add(resources).start()

static func load_resources_group_threaded(group_name: String, resources: Array[Array], ignore_in_finished: bool = false) -> void:
	var manager = PackageThreadedResourceManager.get_instance()
	manager.loader.add_group(group_name, resources, ignore_in_finished).start()

static func queue_load_resources_threaded(resources: Array[Array]) -> void:
	var manager = PackageThreadedResourceManager.get_instance()
	manager.loader.add(resources)

static func start_loading_threaded(threads_amount: int = -1) -> void:
	if threads_amount == -1:
		threads_amount = max(1, OS.get_processor_count() - 1)
	var manager = PackageThreadedResourceManager.get_instance()
	manager.loader.start(threads_amount)

static func is_loader_idle_threaded() -> bool:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader.is_idle()

static func get_loader_threads_count_threaded() -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader.get_current_threads_amount()

static func connect_load_finished_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader.loadFinished.connect(callable, flags)

static func connect_load_progress_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader.loadProgress.connect(callable, flags)

static func connect_load_group_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader.loadGroup.connect(callable, flags)

static func connect_load_error_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader.loadError.connect(callable, flags)

static func connect_load_started_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader.loadStarted.connect(callable, flags)

static func connect_loader_idle_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader.becameIdle.connect(callable, flags)

static func save_resource_threaded(resource: Resource, path: String = "", flags: int = 0) -> void:
	var manager = PackageThreadedResourceManager.get_instance()
	if path.is_empty():
		path = resource.resource_path
	manager.saver.add([[resource, path, flags]]).start()

static func save_resources_threaded(resources: Array[Array]) -> void:
	var manager = PackageThreadedResourceManager.get_instance()
	manager.saver.add(resources).start()

static func queue_save_resources_threaded(resources: Array[Array]) -> void:
	var manager = PackageThreadedResourceManager.get_instance()
	manager.saver.add(resources)

static func start_saving_threaded(verify_files_access: bool = false, threads_amount: int = -1) -> void:
	if threads_amount == -1:
		threads_amount = max(1, OS.get_processor_count() - 1)
	var manager = PackageThreadedResourceManager.get_instance()
	manager.saver.start(verify_files_access, threads_amount)

static func is_saver_idle_threaded() -> bool:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.saver.is_idle()

static func get_saver_threads_count_threaded() -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.saver.get_current_threads_amount()

static func connect_save_finished_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.saver.saveFinished.connect(callable, flags)

static func connect_save_progress_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.saver.saveProgress.connect(callable, flags)

static func connect_save_error_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.saver.saveError.connect(callable, flags)

static func connect_save_started_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.saver.saveStarted.connect(callable, flags)

static func connect_saver_idle_threaded(callable: Callable, flags: int = 0) -> int:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.saver.becameIdle.connect(callable, flags)

static func connect_all_finished_threaded(callable: Callable, flags: int = 0) -> Array[int]:
	var manager = PackageThreadedResourceManager.get_instance()
	var ids: Array[int] = []
	ids.append(manager.loader.loadFinished.connect(callable, flags))
	ids.append(manager.saver.saveFinished.connect(callable, flags))
	return ids

static func get_loaded_resource_threaded(key: String) -> Resource:
	var manager = PackageThreadedResourceManager.get_instance()
	if manager.loader._loadedFiles.has(key):
		return manager.loader._loadedFiles[key]
	return null

static func get_all_loaded_resources_threaded() -> Dictionary:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.loader._loadedFiles.duplicate()

static func get_saved_paths_threaded() -> Array[String]:
	var manager = PackageThreadedResourceManager.get_instance()
	return manager.saver._savedPaths.duplicate()

static func _get_all_dependencies_recursive(package_name: String, visited: Array[String]) -> Array[String]:
	if visited.has(package_name):
		return []
	
	visited.append(package_name)
	var all_deps: Array[String] = []
	
	if has_package(package_name) or lazy_packages.has(package_name):
		var deps = get_package_dependencies(package_name)
		for dep in deps:
			var dep_name = str(dep)
			if not all_deps.has(dep_name):
				all_deps.append(dep_name)
			
			var sub_deps = _get_all_dependencies_recursive(dep_name, visited.duplicate())
			for sub_dep in sub_deps:
				if not all_deps.has(sub_dep):
					all_deps.append(sub_dep)
	
	visited.pop_back()
	return all_deps

static func get_package_info_with_deps(package_name: String) -> Dictionary:
	var result = {
		"exists": false,
		"has_deps": false,
		"deps": PackedStringArray([])
	}
	
	if packages.has(package_name):
		result.exists = true
		var pkg = packages[package_name]
		if pkg._config.has("dependencies"):
			result.has_deps = true
			var dependencies: Array = pkg._config.get("dependencies", [])
			for dep in dependencies:
				result.deps.append(str(dep))
	
	return result
