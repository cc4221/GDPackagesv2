extends Package # test

const Core = preload("src/test_core.gd")


func _loaded() -> void:
	var core = Core.new()
	var result = core.add(42, 42)
	adapter.send_result(result)
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
