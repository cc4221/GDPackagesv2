extends PackageAdapter

var _weapon_core = null

func _init(owner_name: String = "") -> void:
	_owner_package_name = owner_name

func set_weapon_core(weapon_core) -> void:
	_weapon_core = weapon_core

func is_ready() -> bool:
	if _weapon_core:
		return _weapon_core.is_ready()
	return false

func get_damage_multiplier() -> float:
	if _weapon_core and _weapon_core.is_ready():
		return _weapon_core.get_damage_multiplier()
	return 1.0

func get_heal_multiplier() -> float:
	if _weapon_core and _weapon_core.is_ready():
		return _weapon_core.get_heal_multiplier()
	return 1.0