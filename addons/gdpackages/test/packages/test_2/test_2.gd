extends Package # test_2

const Core = preload("src/test_2_core.gd")


func _loaded() -> void:
	emit_message("loaded successfully.")
	# Получаем адаптер test для получения значения
	var test_adapter = PackageManager.get_adapter("test")
	if test_adapter:
		var value = test_adapter.get_result()
		if value != 0:
			# Передаём значение в наш core для бизнес-логики
			var core = Core.new()
			var result = core.multiply(value)
			# Выводим результат через наш адаптер
			adapter.print_result(result)

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
