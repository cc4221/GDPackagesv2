extends Node
## LoggerPackageCore - Ядро системы логирования
## Слушает и логирует все ключевые события

class_name LoggerPackageCore

var _package: Package = null

func set_package_reference(package: Package) -> void:
	_package = package
	print("[LoggerPackageCore] set_package_reference() вызвана, пакет: ", package.config_get_name())
	# Подписываемся на все ключевые события
	_subscribe_to_events()
	print("[LoggerPackageCore] Подписки установлены")

func _subscribe_to_events() -> void:
	# События ввода
	_package.subscribe_to_event("input.attack", Callable(self, "_log_input_event").bind("ATTACK"))
	_package.subscribe_to_event("input.heal", Callable(self, "_log_input_event").bind("HEAL"))
	_package.subscribe_to_event("input.freeze", Callable(self, "_log_input_event").bind("FREEZE"))
	_package.subscribe_to_event("input.poison", Callable(self, "_log_input_event").bind("POISON"))
	
	# События игрока
	_package.subscribe_to_event("player.request_attack", Callable(self, "_log_player_action").bind("REQUEST_ATTACK"))
	_package.subscribe_to_event("player.request_heal", Callable(self, "_log_player_action").bind("REQUEST_HEAL"))
	_package.subscribe_to_event("player.state_changed", Callable(self, "_log_state_changed"))
	
	# События здоровья
	_package.subscribe_to_event("health.changed", Callable(self, "_log_health_changed"))
	_package.subscribe_to_event("health.take_damage", Callable(self, "_log_health_take_damage"))
	_package.subscribe_to_event("player.died", Callable(self, "_log_player_died"))
	
	# События статус-эффектов
	_package.subscribe_to_event("status.freeze_applied", Callable(self, "_log_effect_applied").bind("FREEZE"))
	_package.subscribe_to_event("status.freeze_removed", Callable(self, "_log_effect_removed").bind("FREEZE"))
	_package.subscribe_to_event("status.poison_applied", Callable(self, "_log_effect_applied").bind("POISON"))
	_package.subscribe_to_event("status.poison_removed", Callable(self, "_log_effect_removed").bind("POISON"))
	
	# События оружия
	_package.subscribe_to_event("weapon.loaded", Callable(self, "_log_weapon_loaded"))

func _log_input_event(data: Variant, action: String) -> void:
	print("[INPUT] Кнопка нажата: ", action)

func _log_player_action(data: Variant, action: String) -> void:
	print("[PLAYER] Действие: ", action)

func _log_state_changed(data: Variant) -> void:
	if data is Dictionary:
		print("[PLAYER] Смена состояния: %s → %s" % [data.get("from", "?"), data.get("to", "?")])

func _log_health_changed(data: Variant) -> void:
	if data is Dictionary:
		var hp = data.get("current_hp", 0)
		var max_hp = data.get("max_hp", 100)
		var is_poison = data.get("from_poison", false)
		
		if is_poison:
			print("[HEALTH] Урон от яда: HP = %d/%d" % [hp, max_hp])
		elif data.has("damage"):
			print("[HEALTH] Получен урон (%d): HP = %d/%d" % [data.get("damage"), hp, max_hp])
		elif data.has("healed"):
			print("[HEALTH] Исцелено (%d): HP = %d/%d" % [data.get("healed"), hp, max_hp])
		else:
			print("[HEALTH] HP изменился: %d/%d" % [hp, max_hp])

func _log_health_take_damage(data: Variant) -> void:
	if data is Dictionary:
		var amount = data.get("amount", 1)
		var source = data.get("source", "unknown")
		print("[HEALTH] Урон от %s: %d HP" % [source, amount])
	else:
		print("[HEALTH] Урон от неизвестного источника: %d HP" % data)

func _log_player_died(data: Variant) -> void:
	print("[GAME] ИГРОК МЕРТВ!")

func _log_effect_applied(data: Variant, effect_name: String) -> void:
	var duration = data.get("duration", 0) if data is Dictionary else 0
	print("[STATUS] Эффект применен: %s (длительность: %.1f сек)" % [effect_name, duration])

func _log_effect_removed(data: Variant, effect_name: String) -> void:
	print("[STATUS] Эффект завершен: %s" % effect_name)

func _log_weapon_loaded(data: Variant) -> void:
	if data is Dictionary:
		var dmg = data.get("damage_multiplier", 1.0)
		var heal = data.get("heal_multiplier", 1.0)
		print("[WEAPON] Оружие загружено - Урон: %.1fx, Лечение: %.1fx" % [dmg, heal])

func example_method() -> void:
	print("[LoggerPackageCore] Example method called")