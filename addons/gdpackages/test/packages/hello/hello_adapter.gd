extends PackageAdapter

var _hello_package = null

func _init(owner_name: String = "") -> void:
	super._init(owner_name)
	_hello_package = PackageManager.get_package(owner_name)

func get_counter() -> int:
	if _hello_package and _hello_package.has_method("_get_counter"):
		return _hello_package._get_counter()
	return -1

func increment_counter() -> int:
	if _hello_package and _hello_package.has_method("_increment_counter"):
		return _hello_package._increment_counter()
	return -1

func send_greeting(name: String) -> void:
	if _hello_package and _hello_package.has_method("_send_greeting"):
		_hello_package._send_greeting(name)

func get_greeting_history() -> Array:
	if _hello_package and _hello_package.has_method("_get_greeting_history"):
		return _hello_package._get_greeting_history()
	return []