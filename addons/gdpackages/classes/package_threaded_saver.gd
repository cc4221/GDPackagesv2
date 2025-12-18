extends Node
class_name PackageThreadedSaver

signal saveStarted(totalResources: int)
signal saveProgress(completedCount: int, totalResources: int)
signal saveFinished(savedPaths: Array[String])
signal saveError(path: String, errorCode: Error)
signal becameIdle()

static var ignoreWarnings: bool = false

var _semaphore: Semaphore
var _mutex: Mutex
var _threads: Array[Thread] = []

var _activeQueue: Dictionary = {}
var _activeQueueKeys: Array = []
var _idleQueue: Dictionary = {}

var _totalResourcesAmount: int = 0
var _completedResourcesAmount: int = 0
var _failedResourcesAmount: int = 0
var _currentThreadsAmount: int = 0

var _savedPaths: Array[String] = []

var _savingHasStarted: bool = false
var _isStopping: bool = false
var _awaiting_for_cleaning: bool = false
var _verifyFilesAccess: bool = false

var _auto_start_on_ready: bool = false
var _auto_start_on_ready_thread_amount: int = 0




func is_idle() -> bool:
	_mutex.lock()
	var result = not _savingHasStarted
	_mutex.unlock()
	return result


func get_current_threads_amount() -> int:
	_mutex.lock()
	var result = _currentThreadsAmount
	_mutex.unlock()
	return result


func add(resources: Array) -> PackageThreadedSaver:
	_mutex.lock()
	
	for params in resources:
		if not (params[0] is Resource):
			push_error("PackageThreadedSaver: invalid parameter value: \"%s\", should be Resource, will be ignored" % params[0])
			continue
		
		if params.size() == 0:
			push_error("PackageThreadedSaver: empty parameter array will be ignored")
			continue
		
		var resource: Resource = params[0]
		var resourcePathIsEmpty: bool = resource.resource_path.strip_edges() == ""
		var savePath: String = ""
		
		if params.size() == 1:
			if resourcePathIsEmpty:
				push_error("PackageThreadedSaver: resource_path is empty and save path parameter is not specified, resource will be ignored")
				continue
			else:
				if not ignoreWarnings:
					push_warning("PackageThreadedSaver: save path parameter is empty, will use resource_path: \"%s\"" % resource.resource_path)
				savePath = resource.resource_path
		else:
			if typeof(params[1]) != TYPE_STRING and typeof(params[1]) != TYPE_STRING_NAME:
				push_error("PackageThreadedSaver: invalid save path parameter value: \"%s\", should be String or StringName, resource will be ignored" % params[1])
				continue
			
			var savePathParamIsEmpty: bool = params[1].strip_edges() == ""
			
			if savePathParamIsEmpty:
				if resourcePathIsEmpty:
					push_error("PackageThreadedSaver: resource_path and save path parameter are both empty, resource will be ignored")
					continue
				else:
					if not ignoreWarnings:
						push_warning("PackageThreadedSaver: save path parameter is empty, will use resource_path: \"%s\"" % resource.resource_path)
					savePath = resource.resource_path
			else:
				savePath = params[1]
		
		var saveParams: Array = [resource, savePath]
		if params.size() > 2:
			saveParams.append(params[2])
		
		_idleQueue[savePath] = saveParams
	
	_mutex.unlock()
	return self


func start(verifyFilesAccess: bool = false, threadsAmount: int = -1) -> PackageThreadedSaver:
	if threadsAmount == -1:
		threadsAmount = max(1, OS.get_processor_count() - 1)
	
	_mutex.lock()
	
	if _isStopping:
		if not ignoreWarnings:
			push_warning("PackageThreadedSaver: currently in cleanup phase, start will be deferred")
		_auto_start_on_ready = true
		_auto_start_on_ready_thread_amount = threadsAmount
		_mutex.unlock()
		return self
	
	if _awaiting_for_cleaning:
		_awaiting_for_cleaning = false
	
	_activeQueue.merge(_idleQueue, true)
	_totalResourcesAmount = _activeQueue.size()
	_activeQueueKeys = _activeQueue.keys()
	
	if _totalResourcesAmount == 0:
		if not ignoreWarnings:
			push_warning("PackageThreadedSaver: save queue is empty, immediately emitting finish signal")

		if _savingHasStarted:
			if not _awaiting_for_cleaning:
				_awaiting_for_cleaning = true
				_on_save_finished.call_deferred()
		else:
			_clearDataAfterSave.call_deferred()
		
		call_deferred("emit_signal", "saveFinished", _savedPaths)
		_mutex.unlock()
		return self
	
	if not _savingHasStarted:
		_savingHasStarted = true
		_verifyFilesAccess = verifyFilesAccess
		_initThreadPool(threadsAmount)
	
	call_deferred("emit_signal", "saveStarted", _totalResourcesAmount)
	
	for _i in range(_currentThreadsAmount):
		_semaphore.post.call_deferred()
	
	_idleQueue.clear()
	_mutex.unlock()
	
	return self


func _initThreadPool(threadsAmount: int) -> void:
	var actualThreadsNeeded = min(threadsAmount, _totalResourcesAmount)
	for i in range(actualThreadsNeeded):
		var thread = Thread.new()
		_threads.append(thread)
		thread.start(_saveThreadWorker)
	_currentThreadsAmount = actualThreadsNeeded


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
		
		var resource: Resource = saveParams[0]
		var path: String = saveParams[1]
		var flags: int = saveParams[2] if saveParams.size() > 2 else 0
		
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


func _on_save_finished() -> void:
	if _awaiting_for_cleaning:
		_stopSaveThreads()


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
			return
	
	call_deferred("emit_signal", "saveFinished", savedPathsCopy)
	_stopSaveThreads.call_deferred()


func _stopSaveThreads() -> void:
	_mutex.lock()
	if _isStopping:
		_mutex.unlock()
		return
	
	_isStopping = true
	_mutex.unlock()
	
	for _i in range(_currentThreadsAmount):
		_semaphore.post()
	
	for thread in _threads:
		if thread.is_started():
			thread.wait_to_finish()
	
	_clearDataAfterSave()


func _clearDataAfterSave() -> void:
	_mutex.lock()
	
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_mutex.lock()
		_isStopping = true
		
		for _i in range(_currentThreadsAmount):
			_semaphore.post()
		
		_mutex.unlock()
		
		for thread in _threads:
			if thread.is_started():
				thread.wait_to_finish()


func _exit_tree():
	if _savingHasStarted:
		_stopSaveThreads()