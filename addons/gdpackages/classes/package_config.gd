# PackageConfig - Resource for storing package configuration
# Replaces package.json file for storing package metadata
class_name PackageConfig extends Resource

@export_category("Package Info")
# Package name
@export var name: String = ""

# Package version
@export var version: String = "1.0"

# Package description
@export_multiline var description: String = ""

# Path to package script
@export_file("*.gd") var script_path: String = ""

# Path to package adapter (optional)
@export_file("*.gd") var adapter_path: String = ""

# Package dependencies
@export var dependencies: PackedStringArray = []

# Method for converting to dictionary (for compatibility)
func to_dict() -> Dictionary:
	return {
		"name": name,
		"version": version,
		"description": description,
		"script": script_path,
		"adapter": adapter_path,
		"dependencies": dependencies
	}

# Method for initializing from dictionary
func from_dict(dict: Dictionary) -> void:
	name = dict.get("name", "")
	version = dict.get("version", "1.0")
	description = dict.get("description", "")
	script_path = dict.get("script", "")
	adapter_path = dict.get("adapter", "")
	var deps_array = dict.get("dependencies", [])
	# Convert array to PackedStringArray
	dependencies = PackedStringArray(deps_array)
