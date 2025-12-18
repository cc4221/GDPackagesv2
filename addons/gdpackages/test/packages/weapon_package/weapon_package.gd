extends Package # weapon_package
## WeaponPackage - Weapon Management
## Asynchronously loads .tres weapon resource
## Provides damage and healing multipliers

const Adapter = preload("weapon_package_adapter.gd")
const Core = preload("src/weapon_package_core.gd")

var _core = null

func _loaded() -> void:
	emit_message("WeaponPackage loaded successfully.")
	_core = Core.new()
	add_child(_core)
	_core.set_package_reference(self)
	_core.name = "WeaponPackageCore"
	
	# Establish connection with adapter
	var adapter_instance = Adapter.new()
	adapter_instance.set_weapon_core(_core)
	adapter = adapter_instance
	
	_core.load_weapon_async("res://addons/gdpackages/test/packages/weapon_package/resources/example_weapon.tres")


func _unloaded() -> void:
	emit_message("WeaponPackage unloaded successfully.")
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
