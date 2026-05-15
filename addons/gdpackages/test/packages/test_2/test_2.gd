extends Package # test_2

const Core: Script = preload("src/test_2_core.gd")
const Test2AdapterClass: Script = preload("test_2_adapter.gd")

func _loaded() -> void:
	emit_message("loaded successfully.")

	# Получаем адаптер как Variant. Если бы мы типизировали как PackageAdapter,
	# статический анализатор выдал бы ошибку на get_result(), так как у базового класса нет этого метода.
	var test_adapter: Variant = PackageManager.get_adapter("test")
	if test_adapter != null:
		var value: int = test_adapter.get_result()
		if value != 0:
			# Передаём значение в наш core для бизнес-логики
			var core_instance: Test2Core = Core.new()
			var result: int = core_instance.multiply(value)

			# print_result - это статический метод!
			# Вызов статического метода от инстанса 'adapter' в Godot 4 некорректен.
			Test2AdapterClass.print_result(result)

func _unloaded() -> void:
	emit_message("unloaded successfully.")

func _message(_identity: String, _msg: String) -> void:
	pass

func _warning(_identity: String, _msg: String) -> void:
	pass

func _error(_identity: String, _msg: String) -> bool:
	return false

func _unhandled_error(_identity: String, _msg: String) -> void:
	pass

func _handled_error(_identity: String, _msg: String) -> void:
	pass
