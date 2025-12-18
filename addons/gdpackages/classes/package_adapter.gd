class_name PackageAdapter extends RefCounted

var _owner_package_name: String = ""

func _init(owner_name: String = "") -> void:
	_owner_package_name = owner_name

func get_owner_package_name() -> String:
	return _owner_package_name