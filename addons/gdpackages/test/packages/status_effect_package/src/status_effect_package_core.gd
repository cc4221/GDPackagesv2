extends Node

class_name StatusEffectPackageCore

var _package: Package = null
var _health_adapter = null

const FREEZE_DURATION = 4.0
var _freeze_timer: Timer = null
var _is_frozen: bool = false

const POISON_DURATION = 5.0
var _poison_timer: Timer = null
var _poison_damage_timer: Timer = null
var _is_poisoned: bool = false

func set_package_reference(package: Package) -> void:
	_package = package
	print("[StatusEffectPackageCore] set_package_reference() called, package: ", package.config_get_name())
	print("[StatusEffectPackageCore] Subscribing to status effect requests...")
	_package.subscribe_to_event("status.request_freeze_self", Callable(self, "_on_request_freeze"))
	_package.subscribe_to_event("status.request_poison_self", Callable(self, "_on_request_poison"))
	print("[StatusEffectPackageCore] Subscriptions established")

func _on_request_freeze(_data: Variant = null) -> void:
	print("[StatusEffectPackageCore] Freeze request received")
	if not _is_frozen:
		apply_freeze()
	else:
		print("[StatusEffectPackageCore] Already frozen, ignoring")

func _on_request_poison(_data: Variant = null) -> void:
	print("[StatusEffectPackageCore] Poison request received")
	if not _is_poisoned:
		apply_poison()
	else:
		print("[StatusEffectPackageCore] Already poisoned, ignoring")

func apply_freeze() -> void:
	print("[StatusEffectPackageCore] apply_freeze() executing")
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
	print("[StatusEffectPackageCore] Freeze applied for %.1f sec" % FREEZE_DURATION)

func _on_freeze_ended() -> void:
	print("[StatusEffectPackageCore] Freeze ended")
	_is_frozen = false
	if _freeze_timer and _freeze_timer.timeout.is_connected(_on_freeze_ended):
		_freeze_timer.timeout.disconnect(_on_freeze_ended)
	_package.emit_event("status.freeze_removed", {})

func apply_poison() -> void:
	print("[StatusEffectPackageCore] apply_poison() executing")
	_is_poisoned = true
	_package.emit_event("status.poison_applied", {"duration": POISON_DURATION})
	
	if not _poison_timer:
		_poison_timer = Timer.new()
		add_child(_poison_timer)
	else:
		if _poison_timer.timeout.is_connected(Callable(self, "_on_poison_ended")):
			_poison_timer.timeout.disconnect(Callable(self, "_on_poison_ended"))
		_poison_timer.stop()
	
	_poison_timer.wait_time = POISON_DURATION
	_poison_timer.one_shot = true
	if not _poison_timer.timeout.is_connected(Callable(self, "_on_poison_ended")):
		_poison_timer.timeout.connect(Callable(self, "_on_poison_ended"))
	_poison_timer.start()
	
	if not _poison_damage_timer:
		_poison_damage_timer = Timer.new()
		add_child(_poison_damage_timer)
	
	_poison_damage_timer.wait_time = 1.0
	if not _poison_damage_timer.timeout.is_connected(Callable(self, "_on_poison_tick")):
		_poison_damage_timer.timeout.connect(Callable(self, "_on_poison_tick"))
	_poison_damage_timer.start()
	print("[StatusEffectPackageCore] Poison applied for %.1f sec" % POISON_DURATION)

func _on_poison_tick() -> void:
	print("[StatusEffectPackageCore] Periodic damage from poison")
	_package.emit_event("health.take_damage", {"amount": 1, "source": "poison"})

func _on_poison_ended() -> void:
	print("[StatusEffectPackageCore] Poison ended")
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