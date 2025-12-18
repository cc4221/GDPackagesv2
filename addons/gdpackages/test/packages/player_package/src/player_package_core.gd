extends Node
## PlayerPackageCore - Ядро системы управления игроком
## Содержит FSM для управления состояниями
## Обработка входных событий и генерация запросов к HealthPackage

class_name PlayerPackageCore

# Состояния FSM
enum STATE {IDLE, ATTACKING, HEALING}

var _package: Package = null
var _current_state: STATE = STATE.IDLE
var _is_frozen: bool = false  # Статус-эффект freeze блокирует действия

func set_package_reference(package: Package) -> void:
	_package = package
	print("[PlayerPackageCore] set_package_reference() вызвана, пакет: ", package.config_get_name())
	# Подписываемся на события ввода
	print("[PlayerPackageCore] Подписываемся на input.attack...")
	_package.subscribe_to_event("input.attack", Callable(self, "_on_input_attack"))
	_package.subscribe_to_event("input.heal", Callable(self, "_on_input_heal"))
	_package.subscribe_to_event("input.freeze", Callable(self, "_on_input_freeze"))
	_package.subscribe_to_event("input.poison", Callable(self, "_on_input_poison"))
	
	# Подписываемся на статус-эффекты
	_package.subscribe_to_event("status.freeze_applied", Callable(self, "_on_freeze_applied"))
	_package.subscribe_to_event("status.freeze_removed", Callable(self, "_on_freeze_removed"))
	print("[PlayerPackageCore] Все подписки установлены через пакет")

func _on_input_attack(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.attack получено, заморожен: ", _is_frozen)
	# Freeze блокирует атаку
	if _is_frozen:
		print("[PlayerPackageCore] Атака заблокирована Freeze")
		return
	
	# Переходим в состояние Attacking
	_set_state(STATE.ATTACKING)
	print("[PlayerPackageCore] Эмитим player.request_attack")
	_package.emit_event("player.request_attack", {})
	# Сразу возвращаемся в Idle
	_set_state(STATE.IDLE)

func _on_input_heal(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.heal получено, заморожен: ", _is_frozen)
	# Freeze блокирует лечение
	if _is_frozen:
		print("[PlayerPackageCore] Лечение заблокировано Freeze")
		return
	
	# Переходим в состояние Healing
	_set_state(STATE.HEALING)
	print("[PlayerPackageCore] Эмитим player.request_heal")
	_package.emit_event("player.request_heal", {})
	# Сразу возвращаемся в Idle
	_set_state(STATE.IDLE)

func _on_input_freeze(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.freeze получено")
	# Запрос на применение freeze к себе
	_package.emit_event("status.request_freeze_self", {})

func _on_input_poison(_data: Variant = null) -> void:
	print("[PlayerPackageCore] input.poison получено")
	# Запрос на применение poison к себе
	_package.emit_event("status.request_poison_self", {})

func _on_freeze_applied(_data: Variant = null) -> void:
	print("[PlayerPackageCore] Freeze применен")
	_is_frozen = true
	_set_state(STATE.IDLE)  # Freeze заставляет вернуться в Idle

func _on_freeze_removed(_data: Variant = null) -> void:
	print("[PlayerPackageCore] Freeze снят")
	_is_frozen = false

func _set_state(new_state: STATE) -> void:
	if _current_state != new_state:
		var old_state = _current_state
		_current_state = new_state
		var state_name = STATE.keys()[new_state]
		var data = {"from": STATE.keys()[old_state], "to": state_name}
		print("[PlayerPackageCore] Смена FSM состояния: %s → %s" % [STATE.keys()[old_state], state_name])
		_package.emit_event("player.state_changed", data)

func get_current_state() -> String:
	return STATE.keys()[_current_state]

func is_frozen() -> bool:
	return _is_frozen

func example_method() -> void:
	print("[PlayerPackageCore] Example method called")