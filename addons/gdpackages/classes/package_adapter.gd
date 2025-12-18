# PackageAdapter - a simple reference-counted class holding package information
# Used to provide additional functionality or access to the package without exposing the entire package
class_name PackageAdapter extends RefCounted

# Name of the package this adapter belongs to
var _owner_package_name: String = ""

# Constructor that sets the package owner name
func _init(owner_name: String = "") -> void:
	_owner_package_name = owner_name

# Get the name of the package this adapter belongs to
func get_owner_package_name() -> String:
	return _owner_package_name
