# PackageAdapter - простой ссылочно-подсчитываемый класс, хранящий информацию о пакете
# Используется для предоставления дополнительной функциональности или доступа к пакету без раскрытия всего пакета
class_name PackageAdapter extends RefCounted

# Имя пакета, которому принадлежит этот адаптер
var _owner_package_name: String = ""

# Конструктор, устанавливающий имя владельца пакета
func _init(owner_name: String = "") -> void:
	_owner_package_name = owner_name

# Получить имя пакета, которому принадлежит этот адаптер
func get_owner_package_name() -> String:
	return _owner_package_name
