extends Package # hello

const Adapter = preload("hello_adapter.gd")
const Core = preload("src/hello_core.gd")

var core_instance: HelloCore
var greeting_history: Array = []

func _loaded() -> void:
	emit_message("Hello package loaded successfully.")
	core_instance = Core.new()
	core_instance.example_method()
	
	# Подписываемся на события от других пакетов
	subscribe_to_event("world_greeting", self._on_world_greeting)
	subscribe_to_event("request_hello_counter", self._on_request_hello_counter)
	
	# Отправляем событие о загрузке
	emit_event("hello_loaded", {"package": config_get_name()})

func _unloaded() -> void:
	emit_message("Hello package unloaded successfully.")
	
	# Отправляем событие о выгрузке
	emit_event("hello_unloaded", {"package": config_get_name()})

func _message(_identity: String, _msg: String) -> void:
	pass

func _warning(_identity: String, _msg: String) -> void:
	emit_message("Warning from " + _identity + ": " + _msg)

func _error(_identity: String, _msg: String) -> bool:
	emit_message("Error from " + _identity + ": " + _msg)
	return true

func _unhandled_error(_identity: String, _msg: String) -> void:
	pass

func _handled_error(_identity: String, _msg: String) -> void:
	pass

# Публичные методы для вызова из других пакетов
func _get_counter() -> int:
	if core_instance:
		return core_instance.get_counter()
	return -1

func _increment_counter() -> int:
	if core_instance:
		var new_counter = core_instance.increment_counter()
		# Отправляем событие об изменении счетчика
		emit_event("hello_counter_changed", {"value": new_counter})
		return new_counter
	return -1

func _send_greeting(name: String) -> void:
	var greeting = "Hello, " + name + "!"
	greeting_history.append(greeting)
	emit_message(greeting)
	emit_event("hello_greeting", {"greeting": greeting, "to": name})

func _get_greeting_history() -> Array:
	return greeting_history

# Обработчики событий
func _on_world_greeting(data: Dictionary) -> void:
	var name = data.get("to", "unknown")
	emit_message("Received greeting from world: Hello to " + name)
	emit_event("hello_responded_to_world", {"to": name})

func _on_request_hello_counter(data: Dictionary) -> void:
	var requester = data.get("requester", "unknown")
	var counter_value = _get_counter()
	emit_event("hello_counter_response", {"requester": requester, "value": counter_value})
