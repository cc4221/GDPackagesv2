extends Package

const Adapter = preload("logger_package_adapter.gd")
const Core = preload("src/logger_package_core.gd")

var _core = null

func _loaded() -> void:
	emit_message("LoggerPackage loaded successfully.")
	_core = Core.new()
	add_child(_core)
	_core.set_package_reference(self)
	_core.name = "LoggerPackageCore"

func _unloaded() -> void:
	emit_message("LoggerPackage unloaded successfully.")
	if _core:
		_core.queue_free()
		_core = null

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