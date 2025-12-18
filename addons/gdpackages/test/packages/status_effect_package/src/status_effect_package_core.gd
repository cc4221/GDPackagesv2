extends Node
## StatusEffectPackageCore - Ядро системы статус-эффектов
## Управляет Freeze и Poison эффектами независимо от FSM

class_name StatusEffectPackageCore

var _package: Package = null
var _health_adapter = null

# Freeze параметры
const FREEZE_DURATION = 4.0
var _freeze_timer: Timer = null
var _is_frozen: bool = false

# Poison параметры
const POISON_DURATION = 5.0
var _poison_timer: Timer = null
var _poison_damage_timer: Timer = null
var _is_poisoned: bool = false

func set_package_reference(package: Package) -> void:
	_package = package
	print("[StatusEffectPackageCore] set_package_reference() вызвана, пакет: ", package.config_get_name())
	# Подписываемся на запросы эффектов
	print("[StatusEffectPackageCore] Подписываемся на запросы статус-эффектов...")
	_package.subscribe_to_event("status.request_freeze_self", Callable(self, "_on_request_freeze"))
	_package.subscribe_to_event("status.request_poison_self", Callable(self, "_on_request_poison"))
	print("[StatusEffectPackageCore] Подписки установлены")

func _on_request_freeze(_data: Variant = null) -> void:
	print("[StatusEffectPackageCore] Запрос на заморозку получен")
	if not _is_frozen:
		apply_freeze()
	else:
		print("[StatusEffectPackageCore] Уже заморожено, игнорируем")

func _on_request_poison(_data: Variant = null) -> void:
	print("[StatusEffectPackageCore] Запрос на яд получен")
	if not _is_poisoned:
		apply_poison()
	else:
		print("[StatusEffectPackageCore] Уже отравлено, игнорируем")

func apply_freeze() -> void:
	print("[StatusEffectPackageCore] apply_freeze() выполняется")
	_is_frozen = true
	_package.emit_event("status.freeze_applied", {"duration": FREEZE_DURATION})
	
	if not _freeze_timer:
		_freeze_timer = Timer.new()
		add_child(_freeze_timer)
	
	_freeze_timer.wait_time = FREEZE_DURATION
	_freeze_timer.one_shot = true
	if not _freeze_timer.timeout.is_connected(_on_freeze_ended):
		_freeze_timer.timeout.connect(_on_freeze_ended)
	_freeze_timer.start()
	print("[StatusEffectPackageCore] Заморозка применена на %.1f сек" % FREEZE_DURATION)

func _on_freeze_ended() -> void:
	print("[StatusEffectPackageCore] Заморозка окончена")
	_is_frozen = false
	if _freeze_timer and _freeze_timer.timeout.is_connected(_on_freeze_ended):
		_freeze_timer.timeout.disconnect(_on_freeze_ended)
	_package.emit_event("status.freeze_removed", {})

func apply_poison() -> void:
	print("[StatusEffectPackageCore] apply_poison() выполняется")
	_is_poisoned = true
	_package.emit_event("status.poison_applied", {"duration": POISON_DURATION})
	
	# Таймер для отслеживания окончания яда
	if not _poison_timer:
		_poison_timer = Timer.new()
		add_child(_poison_timer)
	else:
		# Если таймер уже существует, отключаем старые подключения
		if _poison_timer.timeout.is_connected(Callable(self, "_on_poison_ended")):
			_poison_timer.timeout.disconnect(Callable(self, "_on_poison_ended"))
		_poison_timer.stop()
	
	_poison_timer.wait_time = POISON_DURATION
	_poison_timer.one_shot = true
	# Проверяем, не подключен ли уже сигнал
	if not _poison_timer.timeout.is_connected(Callable(self, "_on_poison_ended")):
		_poison_timer.timeout.connect(Callable(self, "_on_poison_ended"))
	_poison_timer.start()
	
	# Таймер для ежесекундного урона
	if not _poison_damage_timer:
		_poison_damage_timer = Timer.new()
		add_child(_poison_damage_timer)
	
	_poison_damage_timer.wait_time = 1.0
	# Проверяем, не подключен ли уже сигнал
	if not _poison_damage_timer.timeout.is_connected(Callable(self, "_on_poison_tick")):
		_poison_damage_timer.timeout.connect(Callable(self, "_on_poison_tick"))
	_poison_damage_timer.start()
	print("[StatusEffectPackageCore] Яд применен на %.1f сек" % POISON_DURATION)

func _on_poison_tick() -> void:
	# Наносим 1 HP урона в секунду через событие
	print("[StatusEffectPackageCore] Ежесекундный урон от яда")
	_package.emit_event("health.take_damage", {"amount": 1, "source": "poison"})

func _on_poison_ended() -> void:
	print("[StatusEffectPackageCore] Яд окончен")
	_is_poisoned = false
	if _poison_damage_timer:
		if _poison_damage_timer.timeout.is_connected(Callable(self, "_on_poison_tick")):
			_poison_damage_timer.timeout.disconnect(Callable(self, "_on_poison_tick"))
		_poison_damage_timer.stop()
	_package.emit_event("status.poison_removed", {})

func is_frozen() -> bool:
	return _is_frozen

func is_poisoned() -> bool:
	return _is_poisoned

func example_method() -> void:
	print("[StatusEffectPackageCore] Example method called")