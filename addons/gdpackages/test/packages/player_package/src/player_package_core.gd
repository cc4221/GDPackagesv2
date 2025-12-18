extends Node

class_name PlayerPackageCore

enum STATE {IDLE, ATTACKING, HEALING}

var _package: Package = null
var _current_state: STATE = STATE.IDLE
var _is_frozen: bool = false

func set_package_reference(package: Package) -> void:
	_package = package
	print("[PlayerPackageCore] set_package_reference() called, package: ", package.config_get_name())
	print("[PlayerPackageCore] Subscribing to input.attack...")
	_package.subscribe_to_event("input.attack", Callable(self, "_on_input_attack"))
	_package.subscribe_to_event("input.heal", Callable(self, "_on_input_heal"))
	_package.subscribe_to_event("input.freeze", Callable(self, "_on_input_freeze"))
	_package.subscribe_to_event("input.poison", Callable(self, "_on_input_poison"))
	
	_package.subscribe_to_event("status.freeze_applied", Callable(self, "_on_freeze_applied"))
	_package.subscribe_to_event("status.freeze_removed", Callable(self, "_on_freeze_removed"))
	print("[PlayerPackageCore] All subscriptions established through package")

func _on_input_attack(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.attack received, frozen: ", _is_frozen)
	if _is_frozen:
		print("[PlayerPackageCore] Attack blocked by Freeze")
		return
	
	_set_state(STATE.ATTACKING)
	print("[PlayerPackageCore] Emitting player.request_attack")
	_package.emit_event("player.request_attack", {})
	_set_state(STATE.IDLE)

func _on_input_heal(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.heal received, frozen: ", _is_frozen)
	if _is_frozen:
		print("[PlayerPackageCore] Healing blocked by Freeze")
		return
	
	_set_state(STATE.HEALING)
	print("[PlayerPackageCore] Emitting player.request_heal")
	_package.emit_event("player.request_heal", {})
	_set_state(STATE.IDLE)

func _on_input_freeze(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.freeze received")
	_package.emit_event("status.request_freeze_self", {})

func _on_input_poison(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.poison received")
	_package.emit_event("status.request_poison_self", {})

func _on_freeze_applied(_data: Variant = null) -> void:
	print("[PlayerPackageCore] Freeze applied")
	_is_frozen = true
	_set_state(STATE.IDLE)

func _on_freeze_removed(_data: Variant = null) -> void:
	print("[PlayerPackageCore] Freeze removed")
	_is_frozen = false

func _set_state(new_state: STATE) -> void:
	if _current_state != new_state:
		var old_state = _current_state
		_current_state = new_state
		var state_name = STATE.keys()[new_state]
		var data = {"from": STATE.keys()[old_state], "to": state_name}
		print("[PlayerPackageCore] FSM state change: %s → %s" % [STATE.keys()[old_state], state_name])
		_package.emit_event("player.state_changed", data)

func get_current_state() -> String:
	return STATE.keys()[_current_state]

func is_frozen() -> bool:
	return _is_frozen

func example_method() -> void:
	print("[PlayerPackageCore] Example method called")