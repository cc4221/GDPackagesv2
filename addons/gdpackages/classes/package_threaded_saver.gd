## PackageThreadedSaver - Многопоточный сохранитель ресурсов (Godot 4.5)
## Основан на ThreadedResourceSaver от MeroVinggen
## Позволяет сохранять ресурсы асинхронно в фоновых потоках с батчингом и проверкой доступа

extends Node
class_name PackageThreadedSaver

# Сигналы сохранения
signal saveStarted(totalResources: int)
signal saveProgress(completedCount: int, totalResources: int)
signal saveFinished(savedPaths: Array[String])
signal saveError(path: String, errorCode: Error)
signal becameIdle()

# Глобальное подавление предупреждений
static var ignoreWarnings: bool = false

# Внутренние переменные для потокобезопасности
var _semaphore: Semaphore
var _mutex: Mutex
var _threads: Array[Thread] = []

# Очереди ресурсов для сохранения (батчинг - последний ресурс по пути переписывает предыдущие)
var _activeQueue: Dictionary = {}
var _activeQueueKeys: Array = []
var _idleQueue: Dictionary = {}

# Счетчики и статус
var _totalResourcesAmount: int = 0
var _completedResourcesAmount: int = 0
var _failedResourcesAmount: int = 0
var _currentThreadsAmount: int = 0

# Сохраненные пути
var _savedPaths: Array[String] = []

# Состояние сохранения
var _savingHasStarted: bool = false
var _isStopping: bool = false
var _awaiting_for_cleaning: bool = false
var _verifyFilesAccess: bool = false

# Автозапуск при завершении очистки
var _auto_start_on_ready: bool = false
var _auto_start_on_ready_thread_amount: int = 0


func _init() -> void:
	_semaphore = Semaphore.new()
	_mutex = Mutex.new()


## Проверить, находится ли сохранитель в состоянии ожидания
func is_idle() -> bool:
	_mutex.lock()
	var result = not _savingHasStarted
	_mutex.unlock()
	return result


## Получить текущее количество используемых потоков
func get_current_threads_amount() -> int:
	_mutex.lock()
	var result = _currentThreadsAmount
	_mutex.unlock()
	return result


## Добавить ресурсы в очередь сохранения (с батчингом - последний резурс переписывает предыдущий)
func add(resources: Array) -> PackageThreadedSaver:
	_mutex.lock()
	
	for params in resources:
		# Проверить корректность первого параметра (ресурс)
		if not (params[0] is Resource):
			push_error("PackageThreadedSaver: неверное значение параметра: \"%s\", должно быть Resource, будет проигнорирован" % params[0])
			continue
		
		# Проверить что массив не пуст
		if params.size() == 0:
			push_error("PackageThreadedSaver: пустой массив параметров будет проигнорирован")
			continue
		
		# Получить путь ресурса
		var resource: Resource = params[0]
		var resourcePathIsEmpty: bool = resource.resource_path.strip_edges() == ""
		var savePath: String = ""
		
		# Если задан только ресурс без пути сохранения
		if params.size() == 1:
			if resourcePathIsEmpty:
				push_error("PackageThreadedSaver: resource_path пуст и параметр пути сохранения не указан, ресурс будет проигнорирован")
				continue
			else:
				if not ignoreWarnings:
					push_warning("PackageThreadedSaver: параметр пути сохранения пуст, будет использован resource_path: \"%s\"" % resource.resource_path)
				savePath = resource.resource_path
		# Если задано более одного параметра
		else:
			# Проверить тип пути сохранения
			if typeof(params[1]) != TYPE_STRING and typeof(params[1]) != TYPE_STRING_NAME:
				push_error("PackageThreadedSaver: неверное значение параметра пути сохранения: \"%s\", должно быть String или StringName, ресурс будет проигнорирован" % params[1])
				continue
			
			var savePathParamIsEmpty: bool = params[1].strip_edges() == ""
			
			if savePathParamIsEmpty:
				if resourcePathIsEmpty:
					push_error("PackageThreadedSaver: resource_path и параметр пути сохранения оба пусты, ресурс будет проигнорирован")
					continue
				else:
					if not ignoreWarnings:
						push_warning("PackageThreadedSaver: параметр пути сохранения пуст, будет использован resource_path: \"%s\"" % resource.resource_path)
					savePath = resource.resource_path
			else:
				savePath = params[1]
		
		# Батчинг: последний ресурс для пути переписывает предыдущие
		# Храним [resource, savePath, flags?]
		var saveParams: Array = [resource, savePath]
		if params.size() > 2:
			saveParams.append(params[2])
		
		_idleQueue[savePath] = saveParams
	
	_mutex.unlock()
	return self


## Запустить сохранение всех ресурсов в очереди
func start(verifyFilesAccess: bool = false, threadsAmount: int = -1) -> PackageThreadedSaver:
	if threadsAmount == -1:
		threadsAmount = max(1, OS.get_processor_count() - 1)
	
	_mutex.lock()
	
	# Если уже в процессе остановки
	if _isStopping:
		if not ignoreWarnings:
			push_warning("PackageThreadedSaver: в настоящее время на этапе очистки, запуск будет отложен")
		_auto_start_on_ready = true
		_auto_start_on_ready_thread_amount = threadsAmount
		_mutex.unlock()
		return self
	
	# Если остановка запланирована - отменить
	if _awaiting_for_cleaning:
		_awaiting_for_cleaning = false
	
	# Слить idle очередь в active очередь (батчинг)
	_activeQueue.merge(_idleQueue, true)
	_totalResourcesAmount = _activeQueue.size()
	_activeQueueKeys = _activeQueue.keys()
	
	# Если очередь пуста
	if _totalResourcesAmount == 0:
		if not ignoreWarnings:
			push_warning("PackageThreadedSaver: очередь сохранения пуста, сразу испускаем сигнал завершения")
		
		if _savingHasStarted:
			if not _awaiting_for_cleaning:
				_awaiting_for_cleaning = true
				_on_save_finished.call_deferred()
		else:
			_clearDataAfterSave.call_deferred()
		
		call_deferred("emit_signal", "saveFinished", _savedPaths)
		_mutex.unlock()
		return self
	
	# Если сохранение еще не начиналось
	if not _savingHasStarted:
		_savingHasStarted = true
		_verifyFilesAccess = verifyFilesAccess
		_initThreadPool(threadsAmount)
	
	call_deferred("emit_signal", "saveStarted", _totalResourcesAmount)
	
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
		thread.start(_saveThreadWorker)
	_currentThreadsAmount = actualThreadsNeeded


## Работник потока для сохранения ресурсов
func _saveThreadWorker() -> void:
	while true:
		_semaphore.wait()
		_mutex.lock()
		
		if _isStopping:
			_mutex.unlock()
			break
		
		if _activeQueueKeys.is_empty():
			_mutex.unlock()
			continue
		
		var resource_path: String = _activeQueueKeys.pop_back()
		var saveParams: Array = _activeQueue[resource_path]
		_activeQueue.erase(resource_path)
		
		_mutex.unlock()
		
		# saveParams: [resource, save_path, flags?]
		# Нужно передать [save_path, resource, flags?] в ResourceSaver.save
		var resource: Resource = saveParams[0]
		var path: String = saveParams[1]
		var flags: int = saveParams[2] if saveParams.size() > 2 else 0
		
		# Сохранить ресурс
		var error: Error = ResourceSaver.save(resource, path, flags)
		
		_mutex.lock()
		
		if error == OK:
			_completedResourcesAmount += 1
			_savedPaths.append(resource_path)
			call_deferred(
				"emit_signal",
				"saveProgress",
				_completedResourcesAmount,
				_totalResourcesAmount
			)
		else:
			_failedResourcesAmount += 1
			call_deferred("emit_signal", "saveError", resource_path, error)
		
		var isSaveComplete: bool = _completedResourcesAmount + _failedResourcesAmount >= _totalResourcesAmount
		
		if isSaveComplete:
			if _verifyFilesAccess:
				_verifyFileReadinessAccess.call_deferred()
			else:
				call_deferred("emit_signal", "saveFinished", _savedPaths)
				_awaiting_for_cleaning = true
				_on_save_finished.call_deferred()
		else:
			if not _activeQueueKeys.is_empty():
				_semaphore.post()
		
		_mutex.unlock()


## Обработчик завершения сохранения
func _on_save_finished() -> void:
	if _awaiting_for_cleaning:
		_stopSaveThreads()


## Проверить доступность сохраненных файлов
func _verifyFileReadinessAccess() -> void:
	_mutex.lock()
	var savedPathsCopy: Array[String] = _savedPaths.duplicate()
	_mutex.unlock()
	
	if not _verifyFilesAccess:
		call_deferred("emit_signal", "saveFinished", savedPathsCopy)
		_stopSaveThreads.call_deferred()
		return
	
	var file: FileAccess
	for path in savedPathsCopy:
		file = FileAccess.open(path, FileAccess.READ)
		if file:
			file.close()
		else:
			call_deferred("emit_signal", "saveError", path, ERR_FILE_CANT_READ)
			_stopSaveThreads.call_deferred()
			return  # ОСТАНОВИТЬСЯ ПРИ ОШИБКЕ!
	
	call_deferred("emit_signal", "saveFinished", savedPathsCopy)
	_stopSaveThreads.call_deferred()


## Остановить потоки сохранения
func _stopSaveThreads() -> void:
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
	
	# Очистить данные после сохранения
	_clearDataAfterSave()


## Очистить данные после завершения сохранения
func _clearDataAfterSave() -> void:
	_mutex.lock()
	
	# Очистить все данные для следующего использования
	_activeQueue.clear()
	_activeQueueKeys.clear()
	_threads.clear()
	_savedPaths = []
	_totalResourcesAmount = 0
	_completedResourcesAmount = 0
	_failedResourcesAmount = 0
	_isStopping = false
	_savingHasStarted = false
	_currentThreadsAmount = 0
	_verifyFilesAccess = false
	_awaiting_for_cleaning = false
	
	if _idleQueue.is_empty():
		_auto_start_on_ready = false
		_auto_start_on_ready_thread_amount = 0
	elif _auto_start_on_ready:
		call_deferred("start", _auto_start_on_ready_thread_amount)
	
	_mutex.unlock()
	
	becameIdle.emit()


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
	if _savingHasStarted:
		_stopSaveThreads()
