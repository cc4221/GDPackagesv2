# PackageContextMenuPlugin adds context menu items to the Godot editor's filesystem dock
# It allows users to create new packages or package source scripts directly from the editor
@tool
extends EditorContextMenuPlugin

# Signal emitted when the "Package" context menu item is selected
signal pressed
# Signal emitted when the "GD Script (Package Src)" context menu item is selected
signal create_src_script

# Override the _popup_menu method to add custom context menu items
func _popup_menu(paths: PackedStringArray) -> void:
	var is_src_folder = false
	if paths.size() > 0:
		var path = paths[0]
		# Check if the selected path is a 'src' directory within a package
		if path.get_file() == "src":
			var package_dir = path.get_base_dir()
			# Verify that this src directory is part of an actual package by checking for package config files
			if FileAccess.file_exists(package_dir.path_join("package.json")) or FileAccess.file_exists(package_dir.path_join("package_config.tres")):
				is_src_folder = true
	
	# Add different menu items depending on the context
	if is_src_folder:
		add_context_menu_item("GD Script (Package Src)", create_src_script.emit)
	else:
		add_context_menu_item("Package", pressed.emit)