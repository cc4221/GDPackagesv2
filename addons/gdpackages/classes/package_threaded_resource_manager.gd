## PackageThreadedResourceManager - Singleton менеджер для многопоточной загрузки/сохранения
## Предоставляет удобный интерфейс для пакетов для использования PackageThreadedLoader и PackageThreadedSaver
## Автоматически создаёт и управляет инстансами этих классов

extends Node
class_name PackageThreadedResourceManager

# Singleton instance
static var _instance: PackageThreadedResourceManager = null

# Threaded loader singleton
var loader: PackageThreadedLoader = null

# Threaded saver singleton
var saver: PackageThreadedSaver = null

# Пул потоков для управления многопоточными операциями
var _thread_pool: Array[Thread] = []
var _thread_pool_size: int = 0
var _max_thread_pool_size: int = 8  # Максимальное количество потоков в пуле
var _active_tasks: int = 0 # Количество активных задач
var _task_queue: Array[Dictionary] = []  # Очередь задач для пула потоков
var _thread_pool_enabled: bool = true  # Флаг включения пула потоков

# Конфигурация производительности для асинхронных операций
@export var performance_config: Dictionary = {
	"max_concurrent_loads": 4,           # Максимальное количество одновременных загрузок
	"max_concurrent_saves": 2,           # Максимальное количество одновременных сохранений
	"batch_size": 10,                    # Размер пакета для обработки
	"timeout_ms": 30000,                 # Таймаут операции в миллисекундах
	"memory_limit_mb": 512,              # Ограничение памяти в мегабайтах
	"progress_update_interval": 0.1,     # Интервал обновления прогресса в секундах
	"use_compression": false,            # Использовать сжатие при сохранении
	"verify_after_save": false,          # Проверять целостность после сохранения
	"cache_resources": true,             # Кэшировать загруженные ресурсы
	"thread_priority": 1,                # Приоритет потоков (0-низкий, 1-нормальный, 2-высокий)
	"cache_size_limit": 100              # Ограничение размера кэша (в количестве ресурсов)
}

# Кэш для ресурсов с ограничением по размеру
var _resource_cache: Dictionary = {}
var _cache_access_order: Array[String] = []  # Для отслеживания порядка доступа к ресурсам
var _cache_size_limit: int = 100  # Максимальное количество ресурсов в кэше

# Управление кэшем ресурсов
func _cache_resource(key: String, resource: Resource) -> void:
	if not performance_config.get("cache_resources", true):
		return
	
	# Если ключ уже в кэше, удаляем его из списка доступа для обновления позиции
	if _resource_cache.has(key):
		_cache_access_order.erase(key)
	
	# Добавляем ресурс в кэш
	_resource_cache[key] = resource
	_cache_access_order.append(key)
	
	# Если кэш превышает лимит, удаляем наименее используемый ресурс
	if _cache_access_order.size() > performance_config.get("cache_size_limit", 100):
		var oldest_key = _cache_access_order[0]
		_resource_cache.erase(oldest_key)
		_cache_access_order.remove_at(0)

func _get_cached_resource(key: String) -> Resource:
	if _resource_cache.has(key):
		# Обновляем порядок доступа
		_cache_access_order.erase(key)
		_cache_access_order.append(key)
		return _resource_cache[key]
	return null

func _clear_resource_cache() -> void:
	_resource_cache.clear()
	_cache_access_order.clear()

func _get_cache_stats() -> Dictionary:
	return {
		"size": _resource_cache.size(),
		"limit": performance_config.get("cache_size_limit", 100),
		"keys": _resource_cache.keys()
	}

func _init() -> void:
	if _instance != null:
		push_error("PackageThreadedResourceManager: экземпляр уже существует!")
		queue_free()
		return
	
	_instance = self
	name = "PackageThreadedResourceManager"
	
	# Создаём инстансы loader и saver
	loader = PackageThreadedLoader.new()
	loader.name = "PackageThreadedLoader"
	add_child(loader)
	
	saver = PackageThreadedSaver.new()
	saver.name = "PackageThreadedSaver"
	add_child(saver)
	
	# Инициализация пула потоков
	_initialize_thread_pool()


## Получить singleton инстанс
static func get_instance() -> PackageThreadedResourceManager:
	if _instance == null:
		var manager = PackageThreadedResourceManager.new()
		var root = Engine.get_main_loop().get_root()
		if root:
			# Используем call_deferred для избежания ошибки "Parent node is busy setting up children"
			root.call_deferred("add_child", manager)

	return _instance

# Кэшированный инстанс для улучшения производительности
# Использование кэшированного инстанса позволяет избежать повторных вызовов get_instance()
# и ускоряет работу методов, особенно при частом использовании
static var _cached_instance: PackageThreadedResourceManager = null

## Получить кэшированный singleton инстанс (оптимизированная версия)
static func _get_cached_instance() -> PackageThreadedResourceManager:
	if _cached_instance == null:
		_cached_instance = get_instance()
	return _cached_instance


## Установить режим игнорирования предупреждений
static func set_ignore_warnings(value: bool) -> void:
	PackageThreadedLoader.ignoreWarnings = value
	PackageThreadedSaver.ignoreWarnings = value


# ================================================================================
# LOADER INTERFACE - Асинхронная загрузка ресурсов
# ================================================================================

## Загрузить один ресурс асинхронно
## Пример: load_resource("texture", "res://assets/texture.png")
static func load_resource(key: String, path: String, type_hint: String = "", cache_mode: int = 1) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	
	# Проверяем кэш
	var cached_resource = manager._get_cached_resource(key)
	if cached_resource != null:
		# Если ресурс в кэше, возвращаем его сразу
		manager.loader._loadedFiles[key] = cached_resource
		return manager
	
	manager.loader.add([[key, path, type_hint, cache_mode]]).start()
	return manager


## Загрузить один ресурс с автоматическим ключом (используется путь)
static func load_resource_simple(path: String, type_hint: String = "", cache_mode: int = 1) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	var key = path.get_file()
	
	# Проверяем кэш
	var cached_resource = manager._get_cached_resource(key)
	if cached_resource != null:
		# Если ресурс в кэше, возвращаем его сразу
		manager.loader._loadedFiles[key] = cached_resource
		return manager
	
	manager.loader.add([["", path, type_hint, cache_mode]]).start()
	return manager


## Загрузить несколько ресурсов асинхронно
## Пример: load_resources([["tex1", "res://1.png"], ["tex2", "res://2.png"]])
static func load_resources(resources: Array) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	
	# Проверяем кэш для каждого ресурса и добавляем только отсутствующие в кэше
	var resources_to_load = []
	for resource_data in resources:
		var key = resource_data[0] if resource_data[0] != "" else resource_data[1].get_file()
		var cached_resource = manager._get_cached_resource(key)
		if cached_resource != null:
			# Если ресурс в кэше, добавляем его напрямую
			manager.loader._loadedFiles[key] = cached_resource
		else:
			# Иначе добавляем в очередь загрузки
			resources_to_load.append(resource_data)
	
	if resources_to_load.size() > 0:
		manager.loader.add(resources_to_load).start()
	
	return manager


## Загрузить группу ресурсов с фильтрацией в loadFinished
## Пример: load_resources_group("ui_textures", [["btn", "res://btn.png"], ...], true)
static func load_resources_group(group_name: String, resources: Array, ignore_in_finished: bool = false) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.loader.add_group(group_name, resources, ignore_in_finished).start()
	return manager


## Добавить ресурсы в очередь загрузки без запуска
static func queue_load_resources(resources: Array) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.loader.add(resources)
	return manager


## Добавить группу ресурсов в очередь без запуска
static func queue_load_group(group_name: String, resources: Array, ignore_in_finished: bool = false) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.loader.add_group(group_name, resources, ignore_in_finished)
	return manager


## Запустить загрузку всех ресурсов в очереди
static func start_loading(threads_amount: int = -1) -> PackageThreadedResourceManager:
	if threads_amount == -1:
		threads_amount = max(1, OS.get_processor_count() - 1)
	var manager = _get_cached_instance()
	manager.loader.start(threads_amount)
	return manager


## Проверить, завершена ли загрузка
static func is_loader_idle() -> bool:
	return _get_cached_instance().loader.is_idle()


## Получить текущее количество потоков загрузки
static func get_loader_threads_count() -> int:
	return _get_cached_instance().loader.get_current_threads_amount()


## Подключить сигнал завершения загрузки
static func connect_load_finished(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadFinished.connect(callable, flags)


## Подключить сигнал прогресса загрузки
static func connect_load_progress(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadProgress.connect(callable, flags)


## Подключить сигнал завершения группы загрузки
static func connect_load_group(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadGroup.connect(callable, flags)


## Подключить сигнал ошибки загрузки
static func connect_load_error(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadError.connect(callable, flags)


## Подключить сигнал начала загрузки
static func connect_load_started(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.loadStarted.connect(callable, flags)


## Подключить сигнал простоя загрузчика
static func connect_loader_idle(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().loader.becameIdle.connect(callable, flags)


# ================================================================================
# SAVER INTERFACE - Асинхронное сохранение ресурсов
# ================================================================================

## Сохранить один ресурс асинхронно
## Пример: save_resource(my_resource, "res://saved/resource.tres")
static func save_resource(resource: Resource, path: String = "", flags: int = 0) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	if path.is_empty():
		path = resource.resource_path
	manager.saver.add([[resource, path, flags]]).start()
	return manager


## Сохранить один ресурс с автоматическим путем (используется resource_path)
static func save_resource_simple(resource: Resource, flags: int = 0) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	if resource.resource_path.is_empty():
		push_error("PackageThreadedResourceManager: resource_path пуст, используйте save_resource() с явным путем")
		return manager
	manager.saver.add([[resource, "", flags]]).start()
	return manager


## Сохранить несколько ресурсов асинхронно
## Пример: save_resources([[res1, "path1"], [res2, "path2"]]) или [[res1, "path1", flags], ...]
static func save_resources(resources: Array) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.saver.add(resources).start()
	return manager


## Добавить ресурсы в очередь сохранения без запуска
static func queue_save_resources(resources: Array) -> PackageThreadedResourceManager:
	var manager = _get_cached_instance()
	manager.saver.add(resources)
	return manager


## Запустить сохранение всех ресурсов в очереди
static func start_saving(verify_files_access: bool = false, threads_amount: int = -1) -> PackageThreadedResourceManager:
	if threads_amount == -1:
		threads_amount = max(1, OS.get_processor_count() - 1)
	var manager = _get_cached_instance()
	manager.saver.start(verify_files_access, threads_amount)
	return manager


## Проверить, завершено ли сохранение
static func is_saver_idle() -> bool:
	return _get_cached_instance().saver.is_idle()


## Получить текущее количество потоков сохранения
static func get_saver_threads_count() -> int:
	return _get_cached_instance().saver.get_current_threads_amount()


## Подключить сигнал завершения сохранения
static func connect_save_finished(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.saveFinished.connect(callable, flags)


## Подключить сигнал прогресса сохранения
static func connect_save_progress(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.saveProgress.connect(callable, flags)


## Подключить сигнал ошибки сохранения
static func connect_save_error(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.saveError.connect(callable, flags)


## Подключить сигнал начала сохранения
static func connect_save_started(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.saveStarted.connect(callable, flags)


## Подключить сигнал простоя сохранителя
static func connect_saver_idle(callable: Callable, flags: int = 0) -> int:
	return _get_cached_instance().saver.becameIdle.connect(callable, flags)


# ================================================================================
# UTILITY METHODS - Вспомогательные методы
# ================================================================================

## Подключить сигналы обоих (loader и saver) к одному обработчику
static func connect_all_finished(callable: Callable, flags: int = 0) -> Array[int]:
	var manager = _get_cached_instance()
	var ids: Array[int] = []
	ids.append(manager.loader.loadFinished.connect(callable, flags))
	ids.append(manager.saver.saveFinished.connect(callable, flags))
	return ids


## Отключить сигналы
static func disconnect_signal(signal_obj: Signal, callable: Callable) -> void:
	if signal_obj.is_connected(callable):
		signal_obj.disconnect(callable)


## Ожидать завершения загрузки (используя await)
static func await_load_finished() -> Signal:
	return _get_cached_instance().loader.loadFinished


## Ожидать завершения сохранения (используя await)
static func await_save_finished() -> Signal:
	return _get_cached_instance().saver.saveFinished


# ================================================================================
# RESULTS RETRIEVAL - Получение результатов загрузки/сохранения
# ================================================================================

## Получить загруженный ресурс по ключу
static func get_loaded_resource(key: String) -> Resource:
	var manager = _get_cached_instance()
	if manager.loader._loadedFiles.has(key):
		return manager.loader._loadedFiles[key]
	
	# Если ресурс не найден в загруженных, проверяем кэш
	return manager._get_cached_resource(key)


## Получить все загруженные ресурсы
static func get_all_loaded_resources() -> Dictionary:
	var all_resources = _get_cached_instance().loader._loadedFiles.duplicate()
	
	# Добавляем ресурсы из кэша, если они не были загружены
	var cache_resources = _get_cached_instance()._resource_cache
	for key in cache_resources:
		if not all_resources.has(key):
			all_resources[key] = cache_resources[key]
	
	return all_resources


## Получить список сохраненных путей
static func get_saved_paths() -> Array[String]:
	return _get_cached_instance().saver._savedPaths.duplicate()

# Инициализация пула потоков
func _initialize_thread_pool() -> void:
	_thread_pool_size = min(_max_thread_pool_size, OS.get_processor_count())
	_thread_pool.resize(_thread_pool_size)
	
	# Создаем потоки пула
	for i in range(_thread_pool_size):
		_thread_pool[i] = Thread.new()

# Управление пулом потоков - запуск задачи в пуле
func execute_task_in_pool(task_func: Callable, task_data: Dictionary = {}) -> void:
	if not _thread_pool_enabled:
		# Если пул потоков отключен, выполняем синхронно
		task_func.call(task_data)
		return
	
	# Добавляем задачу в очередь
	var task = {
		"function": task_func,
		"data": task_data,
		"thread_index": -1
	}
	_task_queue.append(task)
	
	# Пытаемся выполнить задачу
	_process_task_queue()

# Обработка очереди задач
func _process_task_queue() -> void:
	if _task_queue.is_empty() or _active_tasks >= _thread_pool_size:
		return
	
	# Получаем задачу из очереди
	var task = _task_queue.pop_front()
	
	# Находим свободный поток
	var available_thread_index = -1
	for i in range(_thread_pool_size):
		if _thread_pool[i] and _thread_pool[i].is_active() == false:
			available_thread_index = i
			break
	
	# Если нет свободных потоков, возвращаем задачу в очередь
	if available_thread_index == -1:
		_task_queue.push_front(task)
		return
	
	# Выполняем задачу в потоке
	task.thread_index = available_thread_index
	_active_tasks += 1
	
	# Запускаем выполнение задачи в потоке
	# Создаем временную функцию для выполнения задачи
	var thread_func = func(data):
		var task_data = data["task"]
		task_data["function"].call(task_data["data"])
		_active_tasks -= 1
		_process_task_queue()  # Проверяем очередь снова после завершения задачи
	
	var task_data = {"task": task}
	_thread_pool[available_thread_index].start(thread_func, task_data)

# Получить статистику пула потоков
func get_thread_pool_stats() -> Dictionary:
	return {
		"pool_size": _thread_pool_size,
		"active_tasks": _active_tasks,
		"queued_tasks": _task_queue.size(),
		"pool_enabled": _thread_pool_enabled
	}

# Управление размером пула потоков
func set_thread_pool_size(size: int) -> void:
	if size <= 0:
		push_warning("Thread pool size must be greater than 0")
		return
	
	_max_thread_pool_size = size
	_thread_pool_enabled = true
	_initialize_thread_pool()

# Остановка пула потоков
func stop_thread_pool() -> void:
	_thread_pool_enabled = false
	_task_queue.clear()
	
	# Ожидаем завершения всех активных задач
	while _active_tasks > 0:
		OS.delay_msec(10)  # Небольшая задержка для предотвращения перегрузки процессора

# Управление конфигурацией производительности
func set_performance_config(config: Dictionary) -> void:
	for key in config:
		if performance_config.has(key):
			performance_config[key] = config[key]

func get_performance_config() -> Dictionary:
	return performance_config.duplicate()

func update_performance_setting(key: String, value) -> void:
	if performance_config.has(key):
		performance_config[key] = value
	else:
		push_warning("Unknown performance setting: " + key)

# Получить значение конкретной настройки производительности
func get_performance_setting(key: String):
	return performance_config.get(key, null)
