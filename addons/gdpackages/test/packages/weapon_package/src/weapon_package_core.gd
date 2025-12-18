extends Node
## WeaponPackageCore - Core weapon system
## Asynchronously loads .tres resource
## Provides damage and healing multipliers

class_name WeaponPackageCore

var _package: Package = null
var _damage_multiplier: float = 1.0
var _heal_multiplier: float = 1.0
var _is_ready: bool = false
var _resource_loader = null

func set_package_reference(package: Package) -> void:
	_package = package
	print("[WeaponPackageCore] set_package_reference() called")

func load_weapon_async(resource_path: String) -> void:
	## Loading weapon asynchronously through ResourceLoader
	print("[WeaponPackageCore] load_weapon_async() starting load: ", resource_path)
	_resource_loader = ResourceLoader.load_threaded_request(resource_path)
	if _resource_loader == OK:
		print("[WeaponPackageCore] Async resource load request sent")
		# Connecting to the update process to check readiness
		set_process(true)
	else:
		print("[WeaponPackageCore] ERROR during async load request: ", _resource_loader)

func _process(_delta: float) -> void:
	if _resource_loader and not _is_ready:
		var status = ResourceLoader.load_threaded_get_status(_resource_loader)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			print("[WeaponPackageCore] Resource loaded successfully")
			var weapon_resource = ResourceLoader.load_threaded_get(_resource_loader)
			_apply_weapon_data(weapon_resource)
			_resource_loader = null
			set_process(false)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			print("[WeaponPackageCore] ERROR loading resource")
			_package.emit_event("weapon.load_failed", {"path": _resource_loader})
			_resource_loader = null
			set_process(false)

func _apply_weapon_data(weapon: Resource) -> void:
	print("[WeaponPackageCore] _apply_weapon_data() called")
	if weapon and weapon.has_meta("damage_multiplier"):
		_damage_multiplier = weapon.get_meta("damage_multiplier")
		print("[WeaponPackageCore] damage_multiplier = ", _damage_multiplier)
	if weapon and weapon.has_meta("heal_multiplier"):
		_heal_multiplier = weapon.get_meta("heal_multiplier")
		print("[WeaponPackageCore] heal_multiplier = ", _heal_multiplier)
	
	_is_ready = true
	print("[WeaponPackageCore] Weapon ready for use")
	_package.emit_event("weapon.loaded", {
		"damage_multiplier": _damage_multiplier,
		"heal_multiplier": _heal_multiplier
	})

func is_ready() -> bool:
	return _is_ready

func get_damage_multiplier() -> float:
	return _damage_multiplier if _is_ready else 1.0

func get_heal_multiplier() -> float:
	return _heal_multiplier if _is_ready else 1.0

func example_method() -> void:
	print("[WeaponPackageCore] Example method called")