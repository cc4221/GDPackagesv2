extends Package # input_package
## InputPackage - Input management
## Handles key presses 1,2,3,4
## Emits events: input.attack, input.heal, input.freeze, input.poison
## Does not contain game logic

const Adapter = preload("input_package_adapter.gd")
const Core = preload("src/input_package_core.gd")

var _core: Node = null

func _loaded() -> void:
	emit_message("InputPackage loaded successfully.")
	_core = Core.new()
	add_child(_core)
	_core.set_package_reference(self)
	_core.name = "InputPackageCore"

func _unloaded() -> void:
	emit_message("InputPackage unloaded successfully.")
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
