class_name GDPackageValidator extends RefCounted

class ValidationResult:
	var is_valid: bool = false
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	func _init(valid: bool = false) -> void:
		is_valid = valid

# 1. Проверка структуры и конфига
static func validate_package(package_path: String) -> ValidationResult:
	var result = ValidationResult.new(true)
	
	var dir_access = DirAccess.open(package_path)
	if dir_access == null:
		result.is_valid = false
		result.errors.append("Package directory does not exist: " + package_path)
		return result
	
	var required_files = [
		"package_config.tres",
		package_path.get_file() + ".gd"
	]
	
	for file in required_files:
		var full_path = package_path.path_join(file)
		if not FileAccess.file_exists(full_path):
			result.is_valid = false
			result.errors.append("Missing required file: " + full_path)
	
	var adapter_file = package_path.path_join(package_path.get_file() + "_adapter.gd")
	if not FileAccess.file_exists(adapter_file):
		result.warnings.append("Recommended adapter file not found: " + adapter_file)
	
	var src_dir = package_path.path_join("src")
	var src_dir_access = DirAccess.open(src_dir)
	if src_dir_access == null:
		result.warnings.append("Recommended src directory not found: " + src_dir)
	
	var config_path = package_path.path_join("package_config.tres")
	if FileAccess.file_exists(config_path):
		var config_resource = load(config_path)
		if config_resource == null:
			result.is_valid = false
			result.errors.append("Could not load package config: " + config_path)
		else:
			if config_resource.name.is_empty():
				result.is_valid = false
				result.errors.append("Package config has empty name")
			
			if config_resource.version.is_empty():
				result.is_valid = false
				result.errors.append("Package config has empty version")
			
			# Проверка sub_adapters (поддержка Array)
			if "sub_adapters" in config_resource and config_resource.sub_adapters is Array:
				for sub_path in config_resource.sub_adapters:
					if sub_path is String and not sub_path.is_empty():
						var full_sub_path = package_path.path_join(sub_path)
						if not FileAccess.file_exists(full_sub_path):
							result.warnings.append("Sub-adapter file not found: " + full_sub_path)

	else:
		result.warnings.append("Package config file not found")
	
	return result

# 2. Проверка содержимого главного скрипта (исправлено имя функции и аргумент)
static func validate_package_script(script_path: String) -> ValidationResult:
	var result = ValidationResult.new(true)
	
	if not FileAccess.file_exists(script_path):
		result.is_valid = false
		result.errors.append("Package script does not exist: " + script_path)
		return result
	
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		result.is_valid = false
		result.errors.append("Could not open package script for reading: " + script_path)
		return result
	
	var content = file.get_as_text()
	file.close()
	
	if not content.contains("extends Package"):
		result.is_valid = false
		result.errors.append("Package script does not extend Package class: " + script_path)
	
	return result

# 3. Полная проверка (вызывает две предыдущие)
static func validate_package_complete(package_path: String) -> ValidationResult:
	var result = ValidationResult.new(true)
	
	# Проверяем структуру
	var structure_result = validate_package(package_path)
	if not structure_result.is_valid:
		result.is_valid = false
		result.errors.append_array(structure_result.errors)
	
	result.warnings.append_array(structure_result.warnings)
	
	# Проверяем скрипт
	var script_name = package_path.get_file() + ".gd"
	var script_result = validate_package_script(package_path.path_join(script_name))
	if not script_result.is_valid:
		result.is_valid = false
		result.errors.append_array(script_result.errors)
	
	result.warnings.append_array(script_result.warnings)
	
	return result
