extends Package # world

const Adapter = preload("world_adapter.gd")
const Core = preload("src/world_core.gd")

var core_instance: WorldCore

func _loaded() -> void:
	emit_message("World package loaded successfully.")
	core_instance = Core.new()
	core_instance.example_method()
	
	# Подписываемся на события от других пакетов
	subscribe_to_event("hello_greeting", self._on_hello_greeting)
	subscribe_to_event("hello_counter_changed", self._on_hello_counter_changed)
	subscribe_to_event("hello_counter_response", self._on_hello_counter_response)
	
	# Отправляем событие о загрузке
	emit_event("world_loaded", {"package": config_get_name()})
	
	# Взаимодействуем с пакетом hello через адаптер
	# Вместо ожидания через get_tree(), просто вызываем метод позже
	call_deferred("_interact_with_hello")

func _unloaded() -> void:
	emit_message("World package unloaded successfully.")
	
	# Отправляем событие о выгрузке
	emit_event("world_unloaded", {"package": config_get_name()})

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
		emit_event("world_counter_changed", {"value": new_counter})
		return new_counter
	return -1

func _send_greeting(name: String) -> void:
	var greeting = core_instance.generate_greeting(name)
	emit_message(greeting)
	emit_event("world_greeting", {"greeting": greeting, "to": name})

func _request_hello_counter() -> void:
	emit_event("request_hello_counter", {"requester": config_get_name()})

func _interact_with_hello() -> void:
	# Взаимодействие с пакетом hello через его адаптер
	var hello_adapter = get_package_adapter("hello")
	if hello_adapter:
		hello_adapter.send_greeting("World")
		emit_message("Sent greeting to hello package via adapter")
		
		# Также можно вызвать напрямую методы пакета
		var hello_package = PackageManager.get_package("hello")
		if hello_package and hello_package.has_method("_increment_counter"):
			hello_package._increment_counter()
	else:
		emit_message("Could not get hello adapter, sending event instead")
		emit_event("world_greeting", {"to": "hello"})

# Обработчики событий
func _on_hello_greeting(data: Dictionary) -> void:
	var greeting = data.get("greeting", "")
	var to = data.get("to", "unknown")
	emit_message("Received greeting from hello: " + greeting + " (to: " + to + ")")
	
	# Инкрементим свой счетчик в ответ
	if core_instance:
		core_instance.increment_counter()
	
	# Отправляем ответное событие
	emit_event("world_acknowledge_hello", {"greeting": greeting, "response_to": to})

func _on_hello_counter_changed(data: Dictionary) -> void:
	var value = data.get("value", 0)
	emit_message("Hello counter changed to: " + str(value))
	
	# В ответ увеличиваем свой счетчик
	if core_instance:
		core_instance.increment_counter()
	
	emit_event("world_counter_synced", {"hello_value": value, "world_value": core_instance.get_counter()})

func _on_hello_counter_response(data: Dictionary) -> void:
	var requester = data.get("requester", "unknown")
	var value = data.get("value", 0)
	emit_message("Hello counter response received by " + requester + ": " + str(value))
