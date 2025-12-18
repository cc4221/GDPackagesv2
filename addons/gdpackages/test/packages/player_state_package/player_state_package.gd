extends Package # player_state_package

const Adapter = preload("player_state_package_adapter.gd")

const Core = preload("src/player_state_package_core.gd")

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
