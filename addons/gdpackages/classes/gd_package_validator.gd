# GDPackageValidator provides validation functionality for gdpackages
# It checks the structure and required files of a package
class_name GDPackageValidator extends RefCounted

# Validation result structure
class ValidationResult:
	var is_valid: bool = false
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	func _init(valid: bool = false) -> void:
		is_valid = valid

# Validate a package structure by checking for required files and structure
static func validate_package(package_path: String) -> ValidationResult:
	var result = ValidationResult.new(true)
	
	# Check if the package directory exists
	var dir_access = DirAccess.open(package_path)
	if dir_access == null:
		result.is_valid = false
		result.errors.append("Package directory does not exist: " + package_path)
		return result
	
	# Check for required files in the package
	var required_files = [
		"package_config.tres",
		package_path.get_file() + ".gd"
	]
	
	for file in required_files:
		var full_path = package_path.path_join(file)
		if not FileAccess.file_exists(full_path):
			result.is_valid = false
			result.errors.append("Missing required file: " + full_path)
	
	# Check if the adapter file exists (optional but recommended)
	var adapter_file = package_path.path_join(package_path.get_file() + "_adapter.gd")
	if not FileAccess.file_exists(adapter_file):
		result.warnings.append("Recommended adapter file not found: " + adapter_file)
	
	# Check if the src directory exists (recommended)
	var src_dir = package_path.path_join("src")
	var src_dir_access = DirAccess.open(src_dir)
	if src_dir_access == null:
		result.warnings.append("Recommended src directory not found: " + src_dir)
	
	# Validate package config resource if it exists
	var config_path = package_path.path_join("package_config.tres")
	if FileAccess.file_exists(config_path):
		var config_resource = load(config_path)
		if config_resource == null:
			result.is_valid = false
			result.errors.append("Could not load package config: " + config_path)
		else:
			# Validate config properties
			if config_resource.name.is_empty():
				result.is_valid = false
				result.errors.append("Package config has empty name")
			
			if config_resource.version.is_empty():
				result.is_valid = false
				result.errors.append("Package config has empty version")
	
	return result

# Validate a package script to ensure it extends Package class
static func validate_package_script(script_path: String) -> ValidationResult:
	var result = ValidationResult.new(true)
	
	if not FileAccess.file_exists(script_path):
		result.is_valid = false
		result.errors.append("Package script does not exist: " + script_path)
	return result
	
	# Read the file content to check if it extends Package
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		result.is_valid = false
		result.errors.append("Could not open package script for reading: " + script_path)
	return result
	
	var content = file.get_as_text()
	file.close()
	
	# Check if the script extends Package
	if not content.contains("extends Package"):
		result.is_valid = false
	result.errors.append("Package script does not extend Package class: " + script_path)
	
	return result

# Validate all components of a package
static func validate_package_complete(package_path: String) -> ValidationResult:
	var result = ValidationResult.new(true)
	
	# Validate package structure
	var structure_result = validate_package(package_path)
	if not structure_result.is_valid:
		result.is_valid = false
		result.errors.append_array(structure_result.errors)
	
	result.warnings.append_array(structure_result.warnings)
	
	# Validate package script
	var script_name = package_path.get_file() + ".gd"
	var script_result = validate_package_script(package_path.path_join(script_name))
	if not script_result.is_valid:
		result.is_valid = false
		result.errors.append_array(script_result.errors)
	
	result.warnings.append_array(script_result.warnings)
	
	return result