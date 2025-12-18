@tool
extends EditorContextMenuPlugin

signal pressed
signal create_src_script

func _popup_menu(paths: PackedStringArray) -> void:
	var is_src_folder = false
	if paths.size() > 0:
		var path = paths[0]
		if path.get_file() == "src":
			var package_dir = path.get_base_dir()
			if FileAccess.file_exists(package_dir.path_join("package.json")) or FileAccess.file_exists(package_dir.path_join("package_config.tres")):
				is_src_folder = true
	
	if is_src_folder:
		add_context_menu_item("GD Script (Package Src)", create_src_script.emit)
	else:
		add_context_menu_item("Package", pressed.emit)