extends Node
## PlayerPackageCore - Core of the player management system
## Contains FSM for state management
## Processing input events and generating requests to HealthPackage

class_name PlayerPackageCore

# FSM States
enum STATE {IDLE, ATTACKING, HEALING}

var _package: Package = null
var _current_state: STATE = STATE.IDLE
var _is_frozen: bool = false  # Freeze status effect blocks actions

func set_package_reference(package: Package) -> void:
	_package = package
	print("[PlayerPackageCore] set_package_reference() called, package: ", package.config_get_name())
	# Subscribe to input events
	print("[PlayerPackageCore] Subscribing to input.attack...")
	_package.subscribe_to_event("input.attack", Callable(self, "_on_input_attack"))
	_package.subscribe_to_event("input.heal", Callable(self, "_on_input_heal"))
	_package.subscribe_to_event("input.freeze", Callable(self, "_on_input_freeze"))
	_package.subscribe_to_event("input.poison", Callable(self, "_on_input_poison"))
	
	# Подписываемся на статус-эффекты
	_package.subscribe_to_event("status.freeze_applied", Callable(self, "_on_freeze_applied"))
	_package.subscribe_to_event("status.freeze_removed", Callable(self, "_on_freeze_removed"))
	print("[PlayerPackageCore] Все подписки установлены через пакет")

func _on_input_attack(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.attack received, frozen: ", _is_frozen)
	# Freeze blocks attack
	if _is_frozen:
		print("[PlayerPackageCore] Attack blocked by Freeze")
		return
	
	# Transition to Attacking state
	_set_state(STATE.ATTACKING)
	print("[PlayerPackageCore] Emitting player.request_attack")
	_package.emit_event("player.request_attack", {})
	# Immediately return to Idle
	_set_state(STATE.IDLE)

func _on_input_heal(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.heal received, frozen: ", _is_frozen)
	# Freeze blocks healing
	if _is_frozen:
		print("[PlayerPackageCore] Healing blocked by Freeze")
		return
	
	# Transition to Healing state
	_set_state(STATE.HEALING)
	print("[PlayerPackageCore] Emitting player.request_heal")
	_package.emit_event("player.request_heal", {})
	# Immediately return to Idle
	_set_state(STATE.IDLE)

func _on_input_freeze(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.freeze received")
	# Request to apply freeze to self
	_package.emit_event("status.request_freeze_self", {})

func _on_input_poison(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.poison received")
	# Request to apply poison to self
	_package.emit_event("status.request_poison_self", {})

func _on_freeze_applied(_data: Variant = null) -> void:
	print("[PlayerPackageCore] Freeze applied")
	_is_frozen = true
	_set_state(STATE.IDLE)  # Freeze forces return to Idle

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