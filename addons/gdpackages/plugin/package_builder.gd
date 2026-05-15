@tool
extends EditorPlugin

const PackageConfigClass = preload("res://addons/gdpackages/classes/package_config.gd")
const GDPackageValidatorClass = preload("res://addons/gdpackages/classes/gd_package_validator.gd")

const PackageCreateDialog = preload("package_create_dialog.tscn")
const PackageContextMenuPlugin = preload("package_context_menu_plugin.gd")

var dialog: ConfirmationDialog
var ctx: EditorContextMenuPlugin

func _enter_tree() -> void:
	ctx = PackageContextMenuPlugin.new()
	ctx.pressed.connect(_on_create_package_pressed)
	ctx.create_src_script.connect(_on_create_src_script_pressed)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE, ctx)

func _exit_tree() -> void:
	if dialog:
		if dialog.get_parent():
			dialog.get_parent().remove_child(dialog)
		dialog.queue_free()
	dialog = null
	if ctx:
		remove_context_menu_plugin(ctx)
	ctx = null

func _new_package_config(pkg_name: String, pkg_vers: String, pkg_desc: String, pkg_deps: Array = []) -> PackageConfig:
	var config := PackageConfig.new()
	
	config.name = pkg_name
	config.version = pkg_vers
	config.description = pkg_desc
	
	# Пути к основным файлам
	config.script_path = pkg_name + ".gd"
	config.adapter_path = pkg_name + "_adapter.gd"
	config.core_path = "src/" + pkg_name + "_core.gd"
	
	# ИЗМЕНЕНИЕ: Сразу добавляем путь к саб-адаптеру в массив
	# Так как мы используем Array[String], это сохранится корректно без хаков
	config.sub_adapters.append("src/adapters/" + pkg_name + "_sub_adapter.gd")
	
	# Зависимости
	config.dependencies = []
	for dep: String in pkg_deps:
		config.dependencies.append(str(dep))
	
	return config


const PACKAGE_TEMPLATE = """extends Package # {name}

const Core = preload("src/{name}_core.gd")
const Adapter = preload("{name}_adapter.gd")

func _loaded() -> void:
	var core: Variant = Core.new()
	var adapter_instance: PackageAdapter = Adapter.new()
	
	core.example_method()
	Adapter.say_hello()
	
	# Пример вызова саб-адаптера по ключу (имя файла без расширения)
	if sub_adapters.has("{name}_sub_adapter"):
		var sub_adapter: Variant = sub_adapters["{name}_sub_adapter"]
		sub_adapter.example_method()
	
	emit_message("loaded successfully.")

func _unloaded() -> void:
	emit_message("unloaded successfully.")

func _message(_identity: String, _msg: String) -> void:
	pass

func _warning(_identity: String, _msg: String) -> void:
	pass

func _error(_identity: String, _msg: String) -> bool:
	return false

func _unhandled_error(_identity: String, _msg: String) -> void:
	pass

func _handled_error(_identity: String, _msg: String) -> void:
	pass
"""

# --------------------------------------------------------------

func _new_package_script(pkg_name: String, _pkg_desc: String) -> String:
	return PACKAGE_TEMPLATE.format({"name": pkg_name})

func _new_package_adapter_script(pkg_name: String) -> String:
	var result: String = "extends PackageAdapter"
	result += "\n\nstatic func say_hello() -> void:"
	result += "\n\tprint(\"Example method called from " + pkg_name + " adapter\")"
	return result

func _new_package_src_script(pkg_name: String) -> String:
	var result: String = "extends RefCounted"
	result += "\n\nclass_name " + pkg_name.capitalize().replace(" ", "") + "Core"
	result += "\n\nfunc example_method() -> void:"
	result += "\n\tprint(\"Example method called from " + pkg_name + " core\")"
	return result

func _new_package_sub_adapter_script(pkg_name: String) -> String:
	var result: String = "extends PackageAdapter"
	result += "\n\nfunc example_method() -> void:"
	result += "\n\tprint(\"Example method called from " + pkg_name + " sub adapter\")"
	return result

func _on_create_package_pressed(option: Array) -> void:
	if option.is_empty():
		return
	
	if not dialog:
		dialog = PackageCreateDialog.instantiate()
		dialog.create.connect(_on_package_created)
		var base_control: Control = EditorInterface.get_base_control()
		base_control.add_child(dialog)
	
	dialog.set_package_path(option[0])
	dialog.popup_centered(Vector2i(500, 300))

func _on_create_src_script_pressed(option: Array) -> void:
	if option.is_empty():
		return
	var parent_dir: String = option[0]
	if parent_dir.get_file() == "src":
		var package_dir: String = parent_dir.get_base_dir()
		var package_name: String = package_dir.get_file()
		
		var file: FileAccess = FileAccess.open(parent_dir.path_join(package_name + "_core.gd"), FileAccess.WRITE)
		if FileAccess.get_open_error() == OK:
			file.store_string(_new_package_src_script(package_name))
			file.close()
			EditorInterface.get_resource_filesystem().scan()
		else:
			push_error("[PackageBuilder] failed to create core script")

func _on_package_created(package_path: String, package_name: String, package_version: String, package_desc: String, package_deps: Array) -> void:
	var dir := DirAccess.open(package_path)
	if DirAccess.get_open_error() == OK:
		dir.make_dir(package_name)

	var path: String = package_path.path_join(package_name)
	
	# 1. Создаем конфиг
	var config: PackageConfig = _new_package_config(package_name, package_version, package_desc, package_deps)
	
	# 2. Сохраняем конфиг стандартным способом (без хаков!)
	var save_path: String = path.path_join("package_config.tres")
	var save_error: Error = ResourceSaver.save(config, save_path)
	if save_error != OK:
		push_error("[PackageBuilder] Failed to save config: " + str(save_error))
	else:
		print("[PackageBuilder] Created config: ", save_path)
	
	# 3. Создаем остальные файлы
	var file := FileAccess.open(path.path_join(package_name + ".gd"), FileAccess.WRITE)
	if file:
		file.store_string(_new_package_script(package_name, package_desc))
		file.close()

	file = FileAccess.open(path.path_join(package_name + "_adapter.gd"), FileAccess.WRITE)
	if file:
		file.store_string(_new_package_adapter_script(package_name))
		file.close()

	dir.make_dir(path.path_join("src"))
	
	file = FileAccess.open(path.path_join("src").path_join(package_name + "_core.gd"), FileAccess.WRITE)
	if file:
		file.store_string(_new_package_src_script(package_name))
		file.close()

	# Создание sub_adapters
	var adapters_dir: DirAccess = DirAccess.open(path.path_join("src"))
	if adapters_dir:
		adapters_dir.make_dir("adapters")
	
	var sub_adapter_path: String = path.path_join("src/adapters").path_join(package_name + "_sub_adapter.gd")
	file = FileAccess.open(sub_adapter_path, FileAccess.WRITE)
	if file:
		file.store_string(_new_package_sub_adapter_script(package_name))
		file.close()

	EditorInterface.get_resource_filesystem().scan()
	
	# Валидация
	var validation_result: GDPackageValidator.ValidationResult = GDPackageValidator.validate_package_complete(path)
	if validation_result.is_valid:
		print("[PackageBuilder] Package created successfully: " + package_name)
	else:
		push_warning("[PackageBuilder] Package created with warnings")
	



	
