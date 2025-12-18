class_name PackageConfig extends Resource

@export_category("Package Info")
@export var name: String = ""

@export var version: String = "1.0"

@export_multiline var description: String = ""

@export_file("*.gd") var script_path: String = ""

@export_file("*.gd") var adapter_path: String = ""

@export var dependencies: PackedStringArray = []

func to_dict() -> Dictionary:
	return {
		"name": name,
		"version": version,
		"description": description,
		"script": script_path,
		"adapter": adapter_path,
		"dependencies": dependencies
	}

func from_dict(dict: Dictionary) -> void:
	name = dict.get("name", "")
	version = dict.get("version", "1.0")
	description = dict.get("description", "")
	script_path = dict.get("script", "")
	adapter_path = dict.get("adapter", "")
	var deps_array = dict.get("dependencies", [])
	dependencies = PackedStringArray(deps_array)