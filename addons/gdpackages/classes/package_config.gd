# PackageConfig - Resource для хранения конфигурации пакета
# Заменяет package.json файл для хранения метаданных пакета
class_name PackageConfig extends Resource

@export_category("Package Info")
# Имя пакета
@export var name: String = ""

# Версия пакета
@export var version: String = "1.0"

# Описание пакета
@export_multiline var description: String = ""

# Путь к скрипту пакета
@export_file("*.gd") var script_path: String = ""

# Путь к адаптеру пакета (опционально)
@export_file("*.gd") var adapter_path: String = ""

# Зависимости пакета
@export var dependencies: PackedStringArray = []

# Метод для преобразования в словарь (для совместимости)
func to_dict() -> Dictionary:
	return {
		"name": name,
		"version": version,
		"description": description,
		"script": script_path,
		"adapter": adapter_path,
		"dependencies": dependencies
	}

# Метод для инициализации из словаря
func from_dict(dict: Dictionary) -> void:
	name = dict.get("name", "")
	version = dict.get("version", "1.0")
	description = dict.get("description", "")
	script_path = dict.get("script", "")
	adapter_path = dict.get("adapter", "")
	var deps_array = dict.get("dependencies", [])
	# Преобразуем массив в PackedStringArray
	dependencies = PackedStringArray(deps_array)
