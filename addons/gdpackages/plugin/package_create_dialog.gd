# PackageCreateDialog is a UI dialog that allows users to create new packages
# It collects information like package name, version, description, and dependencies
@tool
extends ConfirmationDialog

# Import required UI control types
# (Godot automatically recognizes these types, no explicit import needed)

# Signal emitted when the create button is pressed with package information
signal create(pkg_path: String, pkg_name: String, pkg_version: String, pkg_desc: String, pkg_deps: Array)

# Clear all input fields and hide error messages
func clear() -> void:
	var package_path_edit = get_node("VBoxContainer/HBoxContainer5/PackagePathEdit") as LineEdit
	if package_path_edit:
		package_path_edit.text = ""
	
	var package_name_edit = get_node("VBoxContainer/HBoxContainer/PackageNameEdit") as LineEdit
	if package_name_edit:
		package_name_edit.text = ""
	
	var package_version = get_node("VBoxContainer/HBoxContainer3/PackageVersion") as LineEdit
	if package_version:
		package_version.text = "v1.0"
	
	var package_description = get_node("VBoxContainer/PackageDescription") as TextEdit
	if package_description:
		package_description.text = ""
	
	var package_dependencies = get_node("VBoxContainer/HBoxContainerDependencies/PackageDependenciesEdit") as LineEdit
	if package_dependencies:
		package_dependencies.text = ""
	
	var error_message = get_node("VBoxContainer/ErrorMessage") as RichTextLabel
	if error_message:
		error_message.text = ""
		error_message.hide()

# Set the package path in the dialog
func set_package_path(path: String) -> void:
	var package_path_edit = get_node("VBoxContainer/HBoxContainer5/PackagePathEdit") as LineEdit
	if package_path_edit:
		package_path_edit.text = path

# Display an error message in the dialog
func set_error_message(message: String) -> void:
	var error_message = get_node("VBoxContainer/ErrorMessage") as RichTextLabel
	if error_message:
		error_message.text = "[color=red]" + message + "[/color]"
		error_message.show()

# Initialize the dialog by connecting signals
func _ready() -> void:
	# Debug: print the node structure to understand the hierarchy
	print("Dialog name: ", name)
	print("Dialog children count: ", get_child_count())
	
	for i in range(get_child_count()):
		var child = get_child(i)
		print("Child ", i, ": ", child.name, " (type: ", child.get_class(), ")")
		
		if child is Container:
			print(" ", child.name, " has ", child.get_child_count(), " children:")
			for j in range(child.get_child_count()):
				var subchild = child.get_child(j)
				print("    Subchild ", j, ": ", subchild.name, " (type: ", subchild.get_class(), ")")
				
				if subchild is Container:
					print("      ", subchild.name, " has ", subchild.get_child_count(), " children:")
					for k in range(subchild.get_child_count()):
						var subsubchild = subchild.get_child(k)
						print("        Subsubchild ", k, ": ", subsubchild.name, " (type: ", subsubchild.get_class(), ")")
	
	confirmed.connect(_on_create_button_pressed)
	canceled.connect(_on_cancel_button_pressed)


# Handle the cancel button press
func _on_cancel_button_pressed() -> void:
	clear()
	self.hide()

# Handle the create button press, validate inputs, and emit the create signal
func _on_create_button_pressed() -> void:
	# Use direct get_node approach with absolute paths
	var package_name_edit = get_node("VBoxContainer/HBoxContainer/PackageNameEdit") as LineEdit
	var package_path_edit = get_node("VBoxContainer/HBoxContainer5/PackagePathEdit") as LineEdit
	var package_version = get_node("VBoxContainer/HBoxContainer3/PackageVersion") as LineEdit
	var package_description = get_node("VBoxContainer/PackageDescription") as TextEdit
	var package_dependencies = get_node("VBoxContainer/HBoxContainerDependencies/PackageDependenciesEdit") as LineEdit
	var error_message = get_node("VBoxContainer/ErrorMessage") as RichTextLabel
	
	if not package_name_edit:
		push_error("Could not find PackageNameEdit control")
		return
	var pkg_name: String = package_name_edit.text.strip_edges().to_snake_case()

	if pkg_name.is_empty():
		if error_message:
			error_message.text = "[color=red]Invalid package name.[/color]"
			error_message.show()
		return

	if not package_path_edit:
		push_error("Could not find PackagePathEdit control")
		return
	var pkg_path: String = package_path_edit.text.strip_edges()

	var exists: bool = DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(pkg_path.path_join(pkg_name)))
	if exists:
		if error_message:
			error_message.text = "[color=red]Package cannot overwrite existing directory.[/color]"
			error_message.show()
		return

	if not package_version:
		push_error("Could not find PackageVersion control")
		return
	var vers: String = package_version.text.strip_edges()
	
	if not package_description:
		push_error("Could not find PackageDescription control")
		return
	var desc: String = package_description.text.strip_edges()
	
	if not package_dependencies:
		push_error("Could not find PackageDependencies control")
		return
	var deps_text: String = package_dependencies.text.strip_edges()
	print("Dependencies text from UI: ", deps_text)
	
	var deps_array: Array = []
	if not deps_text.is_empty():
		deps_array = deps_text.split(",", false)
		for i in range(deps_array.size()):
			deps_array[i] = deps_array[i].strip_edges()

	print("Dependencies array to emit: ", deps_array)
	create.emit(pkg_path, pkg_name, vers, desc, deps_array)
	clear()
	self.hide()
