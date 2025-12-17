## PackageThreadedLoader - Многопоточный загрузчик ресурсов (Godot 4.5)
## Основан на ThreadedResourceLoader от MeroVinggen
## Позволяет загружать ресурсы асинхронно в фоновых потоках без замораживания основного потока

extends Node
class_name PackageThreadedLoader

# Сигналы загрузки
signal loadStarted(totalResources: int)
signal loadProgress(completedCount: int, totalResources: int)
signal loadGroup(groupName: String, loaded: Dictionary, failed: Dictionary)
signal loadFinished(loadedFiles: Dictionary)
signal loadError(path: String)
signal becameIdle()

# Глобальное подавление предупреждений
static var ignoreWarnings: bool = false

# Внутренние переменные для потокобезопасности
var _semaphore: Semaphore
var _mutex: Mutex
var _threads: Array[Thread] = []

# Очереди ресурсов для загрузки
var _activeQueue: Array[Array] = []
var _idleQueue: Array[Array] = []

# Счетчики и статус
var _totalResourcesAmount: int = 0
var _completedResourcesAmount: int = 0
var _failedResourcesAmount: int = 0
var _currentThreadsAmount: int = 0

# Загруженные ресурсы
var _loadedFiles: Dictionary = {}

# Состояние загрузки
var _loadingHasStarted: bool = false
var _isStopping: bool = false
var _awaiting_for_cleaning: bool = false

# Отображение пути ресурса на ключ
var _resourcePathToKeyMap: Dictionary = {}
var _resourcePathToGroupMap: Dictionary = {}

# Группы ресурсов
var _groups: Dictionary = {}

# Автозапуск при завершении очистки
var _auto_start_on_ready: bool = false
var _auto_start_on_ready_thread_amount: int = 0


func _init() -> void:
	_semaphore = Semaphore.new()
	_mutex = Mutex.new()


## Проверить, находится ли загрузчик в состоянии ожидания
func is_idle() -> bool:
	_mutex.lock()
	var result = not _loadingHasStarted
	_mutex.unlock()
	return result


## Получить текущее количество используемых потоков
func get_current_threads_amount() -> int:
	_mutex.lock()
	var result = _currentThreadsAmount
	_mutex.unlock()
	return result


## Добавить группу ресурсов в очередь загрузки
func add_group(group_name: String, resources: Array, ignore_in_finished: bool = false) -> PackageThreadedLoader:
	_mutex.lock()
	
	for params in resources:
		if _areParamsValid(params):
			_idleQueue.append(params)
			
			if not _groups.has(group_name):
				_groups[group_name] = {
					"loaded": {},
					"failed": {},
					"finished": 0,
					"total": 0,
					"ignore_in_finished": ignore_in_finished
				}
			
			_groups[group_name].total += 1
			var resource_path: String = params[1]
			var resource_key: String = _getResourceKey(params)
			_resourcePathToKeyMap[resource_path] = resource_key
			_resourcePathToGroupMap[resource_path] = group_name
	
	_mutex.unlock()
	return self


## Добавить ресурсы в очередь загрузки
func add(resources: Array) -> PackageThreadedLoader:
	_mutex.lock()
	
	for params in resources:
		if _areParamsValid(params):
			_idleQueue.append(params)
			var resource_path: String = params[1]
			var resource_key: String = _getResourceKey(params)
			_resourcePathToKeyMap[resource_path] = resource_key
	
	_mutex.unlock()
	return self


## Запустить загрузку всех ресурсов в очереди
func start(threadsAmount: int = -1) -> PackageThreadedLoader:
	if threadsAmount == -1:
		threadsAmount = max(1, OS.get_processor_count() - 1)
	
	_mutex.lock()
	
	# Если уже в процессе остановки
	if _isStopping:
		if not ignoreWarnings:
			push_warning("PackageThreadedLoader: в настоящее время на этапе очистки, запуск будет отложен")
		_auto_start_on_ready = true
		_auto_start_on_ready_thread_amount = threadsAmount
		_mutex.unlock()
		return self
	
	# Если остановка запланирована - отменить
	if _awaiting_for_cleaning:
		_awaiting_for_cleaning = false
	
	# Переместить все из idle в active очередь
	var idle_size = _idleQueue.size()
	_activeQueue.append_array(_idleQueue)
	_totalResourcesAmount += idle_size
	_idleQueue.clear()
	if _totalResourcesAmount == 0:
		if not ignoreWarnings:
			push_warning("PackageThreadedLoader: очередь загрузки пуста, сразу испускаем сигнал завершения")
		
		if _loadingHasStarted:
			if not _awaiting_for_cleaning:
				_awaiting_for_cleaning = true
				_on_load_finished.call_deferred()
		else:
			_clearDataAfterLoad.call_deferred()
		
		call_deferred("emit_signal", "loadFinished", _loadedFiles)
		_mutex.unlock()
		return self
	
	# Если загрузка еще не начиналась
	if not _loadingHasStarted:
		_loadingHasStarted = true
		_initThreadPool(threadsAmount)
	
	call_deferred("emit_signal", "loadStarted", _totalResourcesAmount)
	
	# Пробудить все потоки
	for _i in range(_currentThreadsAmount):
		_semaphore.post.call_deferred()
	
	_idleQueue.clear()
	_mutex.unlock()
	
	return self


## Инициализировать пул потоков
func _initThreadPool(threadsAmount: int) -> void:
	var actualThreadsNeeded = min(threadsAmount, _totalResourcesAmount)
	for i in range(actualThreadsNeeded):
		var thread = Thread.new()
		_threads.append(thread)
		thread.start(_loadThreadWorker)
	_currentThreadsAmount = actualThreadsNeeded


## Работник потока для загрузки ресурсов
func _loadThreadWorker() -> void:
	while true:
		_semaphore.wait()
		_mutex.lock()
		
		if _isStopping:
			_mutex.unlock()
			break
		
		if _activeQueue.is_empty():
			_mutex.unlock()
			continue
		
		var loadItem: Array = _activeQueue.pop_back()
		
		_mutex.unlock()
		
		# Параметры: [key, path, type_hint?, cache_mode?]
		var resource_key: String = loadItem[0]
		var resource_path: String = loadItem[1]
		var loadParams: Array = loadItem.slice(1)  # [path, type_hint?, cache_mode?]
		
		# Загрузить ресурс
		var resource: Resource = ResourceLoader.load.callv(loadParams)
		
		_mutex.lock()
		
		if resource:
			_completedResourcesAmount += 1
			
			# Обработка групп
			if _resourcePathToGroupMap.has(resource_path):
				var group_key = _resourcePathToGroupMap[resource_path]
				if _groups.has(group_key):
					var group: Dictionary = _groups[group_key]
					group.loaded[_resourcePathToKeyMap[resource_path]] = resource
					group.finished += 1
					
					if not group.ignore_in_finished:
						_loadedFiles[_resourcePathToKeyMap[resource_path]] = resource
					
					if group.finished == group.total:
						call_deferred(
							"emit_signal",
							"loadGroup",
							group_key,
							group.loaded,
							group.failed
						)
						_groups.erase(group_key)
			else:
				_loadedFiles[_resourcePathToKeyMap[resource_path]] = resource
			
			call_deferred(
				"emit_signal",
				"loadProgress",
				_completedResourcesAmount,
				_totalResourcesAmount
			)
		else:
			# Ошибка загрузки
			if _resourcePathToGroupMap.has(resource_path):
				var group_key = _resourcePathToGroupMap[resource_path]
				if _groups.has(group_key):
					var group: Dictionary = _groups[group_key]
					group.failed[_resourcePathToKeyMap[resource_path]] = resource_path
					group.finished += 1
			
			_failedResourcesAmount += 1
			call_deferred("emit_signal", "loadError", resource_path)
		
		var isLoadComplete: bool = _completedResourcesAmount + _failedResourcesAmount >= _totalResourcesAmount
		
		if isLoadComplete:
			call_deferred("emit_signal", "loadFinished", _loadedFiles)
			_awaiting_for_cleaning = true
			_on_load_finished.call_deferred()
		else:
			if not _activeQueue.is_empty():
				_semaphore.post()
		
		_mutex.unlock()


## Обработчик завершения загрузки
func _on_load_finished() -> void:
	if _awaiting_for_cleaning:
		_stopLoadThreads()


## Остановить потоки загрузки
func _stopLoadThreads() -> void:
	_mutex.lock()
	if _isStopping:
		_mutex.unlock()
		return
	
	_isStopping = true
	_mutex.unlock()
	
	# Пробудить все потоки для завершения
	for _i in range(_currentThreadsAmount):
		_semaphore.post()
	
	# Дождаться завершения всех потоков
	for thread in _threads:
		if thread.is_started():
			thread.wait_to_finish()
	
	# Очистить данные после загрузки
	_clearDataAfterLoad()


## Очистить данные после завершения загрузки
func _clearDataAfterLoad() -> void:
	_mutex.lock()
	
	# Очистить все данные для следующего использования
	_activeQueue.clear()
	_threads.clear()
	_totalResourcesAmount = 0
	_completedResourcesAmount = 0
	_failedResourcesAmount = 0
	_isStopping = false
	_loadingHasStarted = false
	_currentThreadsAmount = 0
	_resourcePathToKeyMap.clear()
	_resourcePathToGroupMap.clear()
	_groups.clear()
	_awaiting_for_cleaning = false
	
	if _idleQueue.is_empty():
		_auto_start_on_ready = false
		_auto_start_on_ready_thread_amount = 0
	elif _auto_start_on_ready:
		call_deferred("start", _auto_start_on_ready_thread_amount)
	
	_mutex.unlock()
	
	becameIdle.emit()


## Проверить корректность параметров
func _areParamsValid(params: Array) -> bool:
	# Недостаточно параметров
	if params.size() < 2:
		push_error("PackageThreadedLoader: слишком мало аргументов в массиве параметров, будут проигнорированы")
		return false
	
	# Неправильный тип ключа
	elif typeof(params[0]) != TYPE_STRING and typeof(params[0]) != TYPE_STRING_NAME:
		push_error("PackageThreadedLoader: неверное значение параметра ключа ресурса: \"%s\", должно быть String или StringName" % params[0])
		return false
	
	# Неправильный тип пути или пустой путь
	elif (typeof(params[1]) != TYPE_STRING and typeof(params[1]) != TYPE_STRING_NAME) or params[1].strip_edges() == "":
		push_error("PackageThreadedLoader: неверное значение параметра пути: \"%s\", должно быть непустым String или StringName" % params[1])
		return false
	
	# Пропустить если ключ уже существует
	elif params[0].strip_edges() != "" and _keyExist(params[0]):
		if not ignoreWarnings:
			push_warning("PackageThreadedLoader: ключ \"%s\" уже существует, ресурс будет проигнорирован" % params[0])
		return false
	
	return true


## Проверить существование ключа
func _keyExist(key: String) -> bool:
	if key.strip_edges() == "":
		return false
	
	# Проверить в маппировании - проверяем значения (ключи ресурсов)
	for path in _resourcePathToKeyMap:
		if _resourcePathToKeyMap[path] == key:
			return true
	
	# Проверить в очереди idle
	return _idleQueue.any(func(params: Array) -> bool: return params[0] == key)


## Получить ключ ресурса
func _getResourceKey(params: Array) -> String:
	var resource_key = params[0]
	# Если ключ пуст - использовать путь ресурса
	if resource_key.strip_edges() == "":
		resource_key = params[1]
	
	return resource_key


## Очистить при удалении
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_mutex.lock()
		_isStopping = true
		
		# Пробудить все потоки для завершения
		for _i in range(_currentThreadsAmount):
			_semaphore.post()
		
		_mutex.unlock()
		
		# Дождаться завершения всех потоков
		for thread in _threads:
			if thread.is_started():
				thread.wait_to_finish()


## Очистить при выходе из дерева
func _exit_tree():
	if _loadingHasStarted:
		_stopLoadThreads()
