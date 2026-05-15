class_name PackageLazyLoader extends RefCounted

const PackageConfigGlobal = preload("res://addons/gdpackages/classes/package_config.gd")

var _available_packages_cache: Dictionary[String, String] = {}
var _loaded_packages_cache: Dictionary[String, Package] = {}
var _package_dependencies_cache: Dictionary[String, PackedStringArray] = {}

# Эти переменные дублируют кэш, оставим для совместимости структуры
var _available_packages: Dictionary[String, String] = {}
var _loaded_packages: Dictionary[String, Package] = {}
var _package_dependencies: Dictionary[String, PackedStringArray] = {}

func register_package(package_path: String, package_name: String, dependencies: PackedStringArray = []) -> void:
	_available_packages[package_name] = package_path
	_available_packages_cache[package_name] = package_path
	_package_dependencies[package_name] = dependencies
	_package_dependencies_cache[package_name] = dependencies

func load_package(package_name: String) -> Package:
	if _loaded_packages_cache.has(package_name):
		return _loaded_packages_cache[package_name]
	
	if not _available_packages_cache.has(package_name):
		push_error("[PackageLazyLoader] Package not found: " + package_name)
		return null
	
	# Сначала загружаем зависимости
	var dependencies: PackedStringArray = _package_dependencies_cache.get(package_name, [])
	for dependency_name in dependencies:
		if not _loaded_packages_cache.has(dependency_name):
			load_package(dependency_name)
	
	var package_path: String = _available_packages_cache[package_name]
	var package: Package = _load_package_without_init(package_path)
	
	if package:
		package._loaded()
		if package.has_signal("ready_complete"):
			# Пустой коннект для инициализации сигнала, если нужно
			package.ready_complete.connect(func() -> void: pass, CONNECT_ONE_SHOT)
		
		_loaded_packages[package_name] = package
		_loaded_packages_cache[package_name] = package
	
	return package

func _load_package_without_init(directory: String) -> Package:
	var config: Dictionary = _get_package_config(directory)
	
	if config.is_empty():
		push_error("[PackageLazyLoader] Package at %s has no config." % directory)
		return null
	if !config.has("script"):
		push_error("[PackageLazyLoader] Config at %s missing 'script' path." % directory)
		return null
	if !config.has("name"):
		push_error("[PackageLazyLoader] Config at %s missing 'name'." % directory)
		return null

	var root: Package = _get_package_root(directory, config)
	if root == null:
		return null

	var package_name: String = config.get("name", "")
	
	# Регистрируем в глобальном менеджере
	PackageManager.packages[package_name] = root

	if not root.is_inside_tree():
		var root_node: Node = Engine.get_main_loop().get_root()
		if root_node:
			root_node.call_deferred("add_child", root)

	root._config = config
	
	# Загрузка адаптера
	var adapter_path_val: String = config.get("adapter", "")
	if adapter_path_val is String and not adapter_path_val.is_empty():
		var full_adapter_path: String = directory.path_join(adapter_path_val)
		if ResourceLoader.exists(full_adapter_path):
			var adapter_script: Script = ResourceLoader.load(full_adapter_path)
			if adapter_script:
				var adapter_instance: PackageAdapter = adapter_script.new()
				root.adapter = adapter_instance
				PackageManager._adapters[package_name] = adapter_instance

	return root

func _get_package_config(directory: String) -> Dictionary:
	var resource_path: String = directory.path_join("package_config.tres")
	
	# ИСПРАВЛЕНИЕ: Используем ResourceLoader.exists для билдов
	if ResourceLoader.exists(resource_path):
		var config_resource: Resource = ResourceLoader.load(resource_path, "Resource", ResourceLoader.CACHE_MODE_REUSE)
		if config_resource is PackageConfigGlobal:
			return config_resource.to_dict()
		elif config_resource is Resource:
			# Пытаемся прочитать данные из обычного ресурса, если это не PackageConfig
			var dict: Dictionary = {}
			for prop: String in ["name", "version", "script", "adapter", "dependencies"]:
				if prop in config_resource:
					dict[prop] = config_resource.get(prop)
			return dict
	
	# Запасной вариант - JSON (работает в билде только если *.json добавлен в фильтры экспорта)
	var json_path: String = directory.path_join("package.json")
	if FileAccess.file_exists(json_path):
		var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
		if file:
			var parsed: Dictionary = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				return parsed

	return {}

func _get_package_root(directory: String, config: Dictionary) -> Package:
	var script_rel_path: String = config.get("script", "")
	var path: String = directory.path_join(script_rel_path)
	
	# ИСПРАВЛЕНИЕ: Проверка через ResourceLoader
	if not ResourceLoader.exists(path):
		push_error("[PackageLazyLoader] Script file not found: " + path)
		return null
	
	var loaded_script: Script = ResourceLoader.load(path)
	if loaded_script:
		var instance: Package = loaded_script.new()
		if instance is Package:
			return instance
		else:
			push_error("[PackageLazyLoader] Script at %s does not extend Package." % path)
	
	return null

func is_package_loaded(package_name: String) -> bool:
	return _loaded_packages_cache.has(package_name)

func unload_package(package_name: String) -> void:
	if _loaded_packages_cache.has(package_name):
		PackageManager.unload_package(package_name)
		_loaded_packages.erase(package_name)
		_loaded_packages_cache.erase(package_name)

func unload_all_packages() -> void:
	var loaded_names: Array[String] = _loaded_packages_cache.keys()
	for package_name in loaded_names:
		PackageManager.unload_package(package_name)
	_loaded_packages.clear()
	_loaded_packages_cache.clear()
