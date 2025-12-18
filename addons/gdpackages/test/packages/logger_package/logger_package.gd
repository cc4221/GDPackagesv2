extends Package # logger_package

const Adapter = preload("logger_package_adapter.gd")

const Core = preload("src/logger_package_core.gd")

func _loaded() -> void:
	emit_message("loaded successfully.")
	var core_instance = Core.new()
	core_instance.example_method()

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
