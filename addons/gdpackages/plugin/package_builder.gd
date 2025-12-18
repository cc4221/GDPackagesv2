@tool
extends EditorPlugin

const PackageConfig = preload("res://addons/gdpackages/classes/package_config.gd")
const GDPackageValidator = preload("res://addons/gdpackages/classes/gd_package_validator.gd")

const PackageCreateDialog = preload("package_create_dialog.tscn")
const PackageContextMenuPlugin = preload("package_context_menu_plugin.gd")

var dialog: ConfirmationDialog
var ctx: EditorContextMenuPlugin
var last_file_path: String

func _enter_tree():
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
	print("Creating new PackageConfig resource...")
	var config := PackageConfig.new()
	print("PackageConfig instance created: ", config)
	config.name = pkg_name
	print("Set name: ", pkg_name)
	config.version = pkg_vers
	print("Set version: ", pkg_vers)
	config.description = pkg_desc
	print("Set description: ", pkg_desc)
	config.script_path = pkg_name + ".gd"
	print("Set script_path: ", pkg_name + ".gd")
	config.adapter_path = pkg_name + "_adapter.gd"
	print("Set adapter_path: ", pkg_name + "_adapter.gd")
	config.dependencies = PackedStringArray(pkg_deps)
	print("Set dependencies: ", PackedStringArray(pkg_deps))
	
	print("PackageConfig resource ready: ", config)
	return config

func _get_type_index(value) -> int:
	if value is int:
		return 1
	elif value is String:
		return 2
	elif value is bool:
		return 3
	else:
		return 0

const PACKAGE_TEMPLATE = """extends Package # {name}

const Adapter = preload("{name}_adapter.gd")

const Core = preload("src/{name}_core.gd")

func _loaded() -> void:
	emit_message("loaded successfully.")
	var core_instance = Core.new()
	core_instance.example_method()

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

func _new_package_script(pkg_name: String, pkg_desc: String) -> String:
	return PACKAGE_TEMPLATE.format({"name": pkg_name})

func _new_package_adapter_script(pkg_name: String) -> String:
	var result: String = "extends PackageAdapter"
	result += "\n\nfunc _init(owner_name: String = \"\") -> void:"
	result += "\n\t_owner_package_name = owner_name"
	return result

func _new_package_src_script(pkg_name: String) -> String:
	var result: String = "extends RefCounted"
	result += "\n\nclass_name " + pkg_name.capitalize().replace(" ", "") + "Core"
	result += "\n\nfunc example_method() -> void:"
	result += "\n\tprint(\"Example method called from " + pkg_name + " core\")"
	return result

func _on_create_package_pressed(option: Array):
	if option.is_empty():
		return
	
	if not dialog:
		dialog = PackageCreateDialog.instantiate()
		dialog.create.connect(_on_package_created)
		var base_control = get_editor_interface().get_base_control()
		base_control.add_child(dialog)
	
	dialog.set_package_path(option[0])
	dialog.popup_centered(Vector2i(500, 300))

func _on_create_src_script_pressed(option: Array):
	if option.is_empty():
		return
	var parent_dir = option[0]
	if parent_dir.get_file() == "src":
		var package_dir = parent_dir.get_base_dir()
		var package_name = package_dir.get_file()
		
		var dir = DirAccess.open(parent_dir)
		if dir.get_open_error() != OK:
			var parent_path = parent_dir
			dir = DirAccess.open(parent_path.get_base_dir())
			if dir.get_open_error() == OK:
				dir.make_dir(parent_path.get_file())
				dir = DirAccess.open(parent_dir)
		
		var file = FileAccess.open(parent_dir.path_join(package_name + "_core.gd"), FileAccess.WRITE)
		if FileAccess.get_open_error() == OK:
			file.store_string(_new_package_src_script(package_name))
			file.close()
			print("Created src script: ", parent_dir.path_join(package_name + "_core.gd"))
		else:
			push_error("[PackageBuilderPlugin] failed to create package core script in src, open error: ", FileAccess.get_open_error())
		
		get_editor_interface().get_resource_filesystem().scan()
	else:
		push_error("[PackageBuilderPlugin] Not a src directory: ", parent_dir)

func _on_package_created(package_path: String, package_name: String, package_version: String, package_desc: String, package_deps: Array) -> void:
	print("creating package: ", package_name)
	print("at path: ", package_path)

	var dir := DirAccess.open(package_path)
	if dir.get_open_error() == OK:
		dir.make_dir(package_name)

	var path: String = package_path.path_join(package_name)
	print("Received package_deps in _on_package_created: ", package_deps)
	var config: PackageConfig = _new_package_config(package_name, package_version, package_desc, package_deps)
	print("Config after _new_package_config call: ", config.to_dict())
	
	print("Config type: ", config.get_class())
	print("Config name: ", config.name)
	print("Config version: ", config.version)
	print("Config description: ", config.description)
	print("Config script_path: ", config.script_path)
	print("Config adapter_path: ", config.adapter_path)
	print("Config dependencies: ", config.dependencies)

	print("Attempting to save Resource to: ", path.path_join("package_config.tres"))
	var save_error = ResourceSaver.save(config, path.path_join("package_config.tres"))
	print("Save result: ", save_error)
	if save_error != OK:
		push_error("[PackageBuilderPlugin] failed to create package config resource file, error code: " + str(save_error))
	else:
		print("Created package config: ", path.path_join("package_config.tres"))

	var file := FileAccess.open(path.path_join(package_name + ".gd"), FileAccess.WRITE)
	if FileAccess.get_open_error() == OK:
		file.store_string(_new_package_script(package_name, package_desc))
		file.close()
	else:
		push_error("[PackageBuilderPlugin] failed to create package main script, open error: ", FileAccess.get_open_error())

	file = FileAccess.open(path.path_join(package_name + "_adapter.gd"), FileAccess.WRITE)
	if FileAccess.get_open_error() == OK:
		file.store_string(_new_package_adapter_script(package_name))
		file.close()
	else:
		push_error("[PackageBuilderPlugin] failed to create package adapter script, open error: ", FileAccess.get_open_error())

	dir.make_dir(path.path_join("src"))
	
	var src_dir_new = DirAccess.open(path.path_join("src"))
	if src_dir_new.get_open_error() != OK:
		push_error("[PackageBuilderPlugin] failed to open src directory: ", path.path_join("src"))
		return
	
	file = FileAccess.open(path.path_join("src").path_join(package_name + "_core.gd"), FileAccess.WRITE)
	if FileAccess.get_open_error() == OK:
		file.store_string(_new_package_src_script(package_name))
		file.close()
	else:
		push_error("[PackageBuilderPlugin] failed to create package core script in src, open error: ", FileAccess.get_open_error())

	get_editor_interface().get_resource_filesystem().scan()
	
	var validation_result = GDPackageValidator.validate_package_complete(path)
	if not validation_result.is_valid:
		push_warning("Package validation failed for '" + package_name + "':")
		for error in validation_result.errors:
			push_error(error)
	for warning in validation_result.warnings:
		push_warning(warning)
	if validation_result.is_valid:
		print("Package validation passed for '" + package_name + "'")