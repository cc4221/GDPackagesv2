extends Package # test

const Core: Script = preload("src/test_core.gd")
const TestAdapterClass: Script = preload("test_adapter.gd")

func _loaded() -> void:
	var core_instance: TestCore = Core.new()
	var result: int = core_instance.add(42, 42)

	# adapter - это PackageAdapter базово, у которого нет метода send_result.
	# Необходимо кастовать к конкретному классу, чтобы не было ошибки статической типизации
	var typed_adapter: TestAdapterClass = adapter as TestAdapterClass
	if typed_adapter:
		typed_adapter.send_result(result)

	emit_message("loaded successfully.")

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
