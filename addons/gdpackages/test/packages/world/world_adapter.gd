extends PackageAdapter

var _world_package = null

func _init(owner_name: String = "") -> void:
	super._init(owner_name)
	_world_package = PackageManager.get_package(owner_name)

func get_counter() -> int:
	if _world_package and _world_package.has_method("_get_counter"):
		return _world_package._get_counter()
	return -1

func increment_counter() -> int:
	if _world_package and _world_package.has_method("_increment_counter"):
		return _world_package._increment_counter()
	return -1

func send_greeting(name: String) -> void:
	if _world_package and _world_package.has_method("_send_greeting"):
		_world_package._send_greeting(name)

func request_hello_counter() -> void:
	if _world_package and _world_package.has_method("_request_hello_counter"):
		_world_package._request_hello_counter()

func interact_with_hello() -> void:
	if _world_package and _world_package.has_method("_interact_with_hello"):
		_world_package._interact_with_hello()