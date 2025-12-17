extends Node2D

func _ready() -> void:
	print("Starting GDPackages test...")
	
	# Регистрируем пакеты
	PackageManager.register_package("res://addons/gdpackages/test/packages/hello")
	PackageManager.register_package("res://addons/gdpackages/test/packages/world")
	
	# Загружаем пакеты
	PackageManager.load_lazy_package("hello")
	PackageManager.load_lazy_package("world")
	
	pass  # Загрузка зависимостей происходит автоматически благодаря конфигурации пакетов
	
	# Демонстрируем взаимодействие между пакетами
	demonstrate_package_interaction()
	
	# Демонстрируем использование адаптеров
	demonstrate_adapters()
	
	# Демонстрируем асинхронную загрузку ресурсов
	demonstrate_async_loading()

func demonstrate_package_interaction() -> void:
	print("\n--- Demonstrating Package Interaction ---")
	
	# Получаем пакеты
	var hello_package = PackageManager.get_package("hello")
	var world_package = PackageManager.get_package("world")
	
	if hello_package and world_package:
		# Отправляем приветствие от world к hello через событие
		PackageEventBus.emit("world_greeting", {"to": "HelloPackage"})
			
		# Запрашиваем счетчик hello
		PackageEventBus.emit("request_hello_counter", {"requester": "world"})
			
		# Инкрементим счетчики
		if hello_package.has_method("_increment_counter"):
			hello_package._increment_counter()
			
		if world_package.has_method("_increment_counter"):
			world_package._increment_counter()
		else:
			print("One or both packages not found")

func demonstrate_adapters() -> void:
	print("\n--- Demonstrating Adapters ---")
	
	# Используем адаптеры для взаимодействия
	var hello_adapter = PackageManager.get_adapter("hello")
	var world_adapter = PackageManager.get_adapter("world")
	
	if hello_adapter:
		print("Hello adapter counter: ", hello_adapter.get_counter())
		hello_adapter.increment_counter()
		hello_adapter.send_greeting("AdapterUser")
	
	if world_adapter:
		print("World adapter counter: ", world_adapter.get_counter())
		world_adapter.increment_counter()
		world_adapter.interact_with_hello()
	
	# Взаимодействие между адаптерами
	if world_adapter:
		world_adapter.request_hello_counter()

func demonstrate_async_loading() -> void:
	print("\n--- Demonstrating Async Resource Loading ---")
	
	# Загружаем существующие ресурсы асинхронно
	PackageThreadedResourceManager.load_resource("test_icon", "res://icon.svg")
	
	# Подключаемся к сигналу завершения загрузки
	PackageThreadedResourceManager.connect_load_finished(_on_resources_loaded)
	
	# Также можно использовать асинхронную загрузку через пакет
	var hello_package = PackageManager.get_package("hello")
	if hello_package:
		hello_package.load_resource_async("hello_script", "res://addons/gdpackages/test/packages/hello/hello.gd")

func _on_resources_loaded(loaded_files: Dictionary) -> void:
	print("Async resources loaded: ", loaded_files.keys())
	
	# Дополнительная демонстрация событийной шины
	var hello_package = PackageManager.get_package("hello")
	var world_package = PackageManager.get_package("world")
	
	if hello_package and world_package:
			# Отправляем событие, на которое должны отреагировать оба пакета
		PackageEventBus.emit("demo_event", {"message": "This is a demo event for both packages"})
	
	print("\n--- Demo completed ---")
	
	# Правильный порядок выгрузки: сначала зависимые пакеты
	PackageManager.unload_package("world")
	PackageManager.unload_package("hello")
