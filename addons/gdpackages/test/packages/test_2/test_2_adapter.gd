extends PackageAdapter

class_name Test2Adapter

const PackageEventBus = preload("res://addons/gdpackages/classes/package_event_bus.gd")

static func say_hello() -> void:
	print("Example method called from test_2 adapter")

# Вывод результата
static func print_result(value: int) -> void:
	print("84 * 9 = ", value)
