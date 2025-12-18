extends Package # health_package
## HealthPackage - Player health management
## Handles damage and healing
## Emits events: health.changed, player.died
## Doesn't know about input or FSM

const Adapter = preload("health_package_adapter.gd")
const Core = preload("src/health_package_core.gd")

var _core = null

func _loaded() -> void:
	emit_message("HealthPackage loaded successfully.")
	_core = Core.new()
	add_child(_core)
	_core.set_package_reference(self)
	_core.name = "HealthPackageCore"
	
	# Subscribe to weapon loading event
	subscribe_to_event("weapon.loaded", Callable(_core, "on_weapon_loaded"))

func _unloaded() -> void:
	emit_message("HealthPackage unloaded successfully.")
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
