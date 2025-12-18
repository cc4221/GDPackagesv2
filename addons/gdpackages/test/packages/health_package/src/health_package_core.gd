extends Node
## HealthPackageCore - Ядро системы здоровья
## Хранит HP и обрабатывает урон/лечение
## Никакой логики FSM или эффектов

class_name HealthPackageCore

const MAX_HP = 100
const MIN_HP = 1  # Яд не может убить

var _package: Package = null
var _current_hp: int = MAX_HP
var _weapon_adapter: PackageAdapter = null  # Ссылка на адаптер оружия

func set_package_reference(package: Package) -> void:
	_package = package
	print("[HealthPackageCore] set_package_reference() вызвана, пакет: ", package.config_get_name())
	# Подписываемся на события от PlayerPackage и статус-эффектов
	print("[HealthPackageCore] Подписываемся на player.request_attack и player.request_heal...")
	_package.subscribe_to_event("player.request_attack", Callable(self, "_on_player_request_attack"))
	_package.subscribe_to_event("player.request_heal", Callable(self, "_on_player_request_heal"))
	_package.subscribe_to_event("health.take_damage", Callable(self, "_on_health_take_damage"))
	print("[HealthPackageCore] Подписки установлены")

func set_weapon_adapter(adapter) -> void:
	_weapon_adapter = adapter
	print("[HealthPackageCore] set_weapon_adapter() вызвана")

func _on_player_request_attack(_data: Variant = null) -> void:
	print("[HealthPackageCore] player.request_attack получено")
	## Игрок атакует сам себя
	var damage = 10
	if _weapon_adapter and _weapon_adapter.is_ready():
		damage = int(damage * _weapon_adapter.get_damage_multiplier())
		print("[HealthPackageCore] Множитель урона из weapon_adapter: ", _weapon_adapter.get_damage_multiplier())
	else:
		print("[HealthPackageCore] WeaponAdapter не готов или null, используем базовое значение")
	
	print("[HealthPackageCore] Наносим урон: ", damage)
	take_damage(damage)

func _on_player_request_heal(_data: Variant = null) -> void:
	print("[HealthPackageCore] player.request_heal получено")
	## Игрок лечит сам себя
	var heal_amount = 15
	if _weapon_adapter and _weapon_adapter.is_ready():
		heal_amount = int(heal_amount * _weapon_adapter.get_heal_multiplier())
		print("[HealthPackageCore] Множитель лечения из weapon_adapter: ", _weapon_adapter.get_heal_multiplier())
	else:
		print("[HealthPackageCore] WeaponAdapter не готов или null, используем базовое значение")
	
	print("[HealthPackageCore] Лечимся на: ", heal_amount)
	heal(heal_amount)

# Новый метод для обработки события загрузки оружия
func on_weapon_loaded(_data: Variant = null) -> void:
	print("[HealthPackageCore] Событие weapon.loaded получено")
	# Получаем адаптер оружия через PackageManager
	_weapon_adapter = _package.get_package_adapter("weapon_package")
	if _weapon_adapter:
		print("[HealthPackageCore] Адаптер оружия получен")
	else:
		print("[HealthPackageCore] Не удалось получить адаптер оружия")

func take_damage(amount: int) -> void:
	_current_hp = max(MIN_HP, _current_hp - amount)
	print("[HealthPackageCore] take_damage(): HP = ", _current_hp, "/", MAX_HP)
	var data = {"current_hp": _current_hp, "damage": amount, "max_hp": MAX_HP}
	_package.emit_event("health.changed", data)
	
	if _current_hp <= MIN_HP:
		print("[HealthPackageCore] Игрок мертв!")
		_package.emit_event("player.died", {"final_hp": _current_hp})

func heal(amount: int) -> void:
	_current_hp = min(MAX_HP, _current_hp + amount)
	print("[HealthPackageCore] heal(): HP = ", _current_hp, "/", MAX_HP)
	var data = {"current_hp": _current_hp, "healed": amount, "max_hp": MAX_HP}
	_package.emit_event("health.changed", data)

func get_current_hp() -> int:
	return _current_hp

func get_max_hp() -> int:
	return MAX_HP

func _on_health_take_damage(data: Variant) -> void:
	## Обработка урона от статус-эффектов (например, яд)
	var amount = 1
	var source = "unknown"
	
	if data is Dictionary:
		amount = data.get("amount", 1)
		source = data.get("source", "unknown")
		print("[HealthPackageCore] Получен урон от %s: %d" % [source, amount])
		
		# Яд не может убить, оставляет минимум 1 HP
		if source == "poison":
			if _current_hp - amount < MIN_HP:
				amount = max(0, _current_hp - MIN_HP)
		
		if amount > 0:
			_current_hp = max(MIN_HP, _current_hp - amount)
			var event_data = {"current_hp": _current_hp, "damage": amount, "from_poison": source == "poison", "max_hp": MAX_HP}
			_package.emit_event("health.changed", event_data)

func example_method() -> void:
	print("[HealthPackageCore] Example method called")