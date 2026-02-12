class_name PackageLogger extends RefCounted


enum LogLevel {FATAL, ERROR, WARN, INFO, DEBUG}
enum EntryType {None, UnhandledError, HandledError, Warning, Message}

const LOG_SIZE: int = 200
const STACK_TRACE_DEPTH: int = 5

static var log_level: LogLevel = LogLevel.INFO
static var console_mode: bool = true
static var package_filter: PackedStringArray = []

static var log: Array[Dictionary] = []
static var log_position: int = 0
static var log_count: int = 0

static var _entry_type_keys = EntryType.keys()
static var _log_level_keys = LogLevel.keys()

static func _initialize_log() -> void:
	if log.size() == 0:
		for i in range(LOG_SIZE):
			log.append({"time":"","type":EntryType.None,"level":LogLevel.INFO,"identity":"","message":"","stack":[]})

static func clear_log() -> void:
	for i in range(log.size()):
		var entry = log[i]
		entry["time"] = ""
		entry["type"] = EntryType.None
		entry["level"] = LogLevel.INFO
		entry["identity"] = ""
		entry["message"] = ""
		entry["stack"] = []
		log[i] = entry
	log_position = 0
	log_count = 0

static func get_timestamp() -> String:
	return Time.get_time_string_from_system()

static func get_stack_item_as_text(stack_item: Dictionary) -> String:
	return "\n\t" + stack_item.source + ":" + str(stack_item.line) + "::" + stack_item.function + "."

static func get_log_entry_as_text(entry: Dictionary) -> String:
	var result: String = entry.time + " [" + _log_level_keys[entry.level] + " - Package::" + entry.identity + "] " + _entry_type_keys[entry.type] + " - " + entry.message
	for stack_item in entry.stack:
		result += "\n" + get_stack_item_as_text(stack_item)
	return result

static func get_log_as_text() -> String:
	var result: String = ""
	var total = min(log.size(), log_count)
	for i in range(total):
		var entry = log[i]
		result += "\n" + get_log_entry_as_text(entry)
	return result

static func print_entry(entry: Dictionary) -> void:
	match entry.level:
		LogLevel.WARN:
			push_warning(entry.time + " [Package::" + entry.identity + "] " + entry.message)
		LogLevel.ERROR, LogLevel.FATAL:
			push_error(entry.time + " [Package::" + entry.identity + "] " + entry.message)
		_:
			print(get_log_entry_as_text(entry))

static func print_log() -> void:
	for entry in log:
		print_entry(entry)

static func _should_log_package(identity: String) -> bool:
	if package_filter.is_empty():
		return true
	return package_filter.has(identity)

static func log_entry(type: EntryType, level: LogLevel, identity: String, message: String, stack: Array[Dictionary] = []) -> void:
	if level > log_level or not _should_log_package(identity):
		return
	
	_initialize_log()
	
	var entry = log[log_position]
	entry["time"] = get_timestamp()
	entry["type"] = type
	entry["level"] = level
	entry["identity"] = identity
	entry["message"] = message
	entry["stack"] = stack
	log[log_position] = entry
	if console_mode:
		print_entry(log[log_position])
	log_position = (log_position + 1) % LOG_SIZE
	log_count += 1

static func log_async(type: EntryType, level: LogLevel, identity: String, message: String, stack: Array[Dictionary] = []) -> void:
	Engine.get_main_loop().call_deferred("_async_log_entry", type, level, identity, message, stack)

static func _async_log_entry(type: EntryType, level: LogLevel, identity: String, message: String, stack: Array[Dictionary] = []) -> void:
	log_entry(type, level, identity, message, stack)

static func log_error(identity: String, message: String) -> void:
	var stack := get_stack()
	if STACK_TRACE_DEPTH > -1:
		stack.resize(mini(stack.size(), STACK_TRACE_DEPTH))
	log_entry(EntryType.UnhandledError, LogLevel.ERROR, identity, message, stack)

static func log_handled_error(identity: String, message: String) -> void:
	log_entry(EntryType.HandledError, LogLevel.ERROR, identity, message)

static func log_warning(identity: String, message: String) -> void:
	log_entry(EntryType.Warning, LogLevel.WARN, identity, message)

static func log_info(identity: String, message: String) -> void:
	log_entry(EntryType.Message, LogLevel.INFO, identity, message)

static func log_debug(identity: String, message: String) -> void:
	log_entry(EntryType.Message, LogLevel.DEBUG, identity, message)

static func log_fatal(identity: String, message: String) -> void:
	var stack := get_stack()
	if STACK_TRACE_DEPTH > -1:
		stack.resize(mini(stack.size(), STACK_TRACE_DEPTH))
	log_entry(EntryType.UnhandledError, LogLevel.FATAL, identity, message, stack)

static func set_log_level(level: LogLevel) -> void:
	log_level = level

static func set_package_filter(filter: PackedStringArray) -> void:
	package_filter = filter

static func save_log(file_path: String) -> Error:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if FileAccess.get_open_error() == OK:
		file.store_string(get_log_as_text())
		file.close()
	return FileAccess.get_open_error()

static func _static_init() -> void:
	log.clear()
	for i in range(LOG_SIZE):
		log.append({"time":"","type":EntryType.None,"level":LogLevel.INFO,"identity":"","message":"","stack":[]})
