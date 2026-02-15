class_name PackageConfig extends Resource

@export_category("Package Info")
@export var name: String = ""

@export var version: String = "1.0"

@export_multiline var description: String = ""

@export_file("*.gd") var script_path: String = ""

@export_file("*.gd") var adapter_path: String = ""

@export_file("*.gd") var core_path: String = ""

# ИЗМЕНЕНИЕ: Используем Array[String] вместо PackedStringArray
# Это стабильнее работает в инспекторе и позволяет сохранять значения корректно.
@export var sub_adapters: Array[String] = []

@export var dependencies: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"name": name,
		"version": version,
		"description": description,
		"script": script_path,
		"adapter": adapter_path,
		"core": core_path,
		"sub_adapters": sub_adapters,
		"dependencies": dependencies
	}

func from_dict(dict: Dictionary) -> void:
	name = dict.get("name", "")
	version = dict.get("version", "1.0")
	description = dict.get("description", "")
	script_path = dict.get("script", "")
	adapter_path = dict.get("adapter", "")
	core_path = dict.get("core", "")
	
	# Конвертация для безопасности типов
	var sub_adapters_array = dict.get("sub_adapters", [])
	sub_adapters = []
	for item in sub_adapters_array:
		sub_adapters.append(str(item))
		
	var deps_array = dict.get("dependencies", [])
	dependencies = []
	for item in deps_array:
		dependencies.append(str(item))
