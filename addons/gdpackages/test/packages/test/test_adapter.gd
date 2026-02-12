extends PackageAdapter

const PackageEventBus = preload("res://addons/gdpackages/classes/package_event_bus.gd")

var _last_result: int = 0

static func say_hello() -> void:
	print("Example method called from test adapter")

# Сохраняем результат
func send_result(value: int) -> void:
	_last_result = value
	print("Test adapter sending result: ", value)

# Получаем сохранённый результат
func get_result() -> int:
	return _last_result
