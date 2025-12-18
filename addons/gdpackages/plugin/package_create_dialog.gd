## PackageCreateDialog - Dialog for creating a package
## Allows the user to enter a name and directory for a new package
@tool
extends ConfirmationDialog

@onready var package_path_edit: LineEdit = $VBoxContainer/HBoxContainer5/PackagePathEdit
@onready var package_name_edit: LineEdit = $VBoxContainer/HBoxContainer/PackageNameEdit
@onready var package_version_edit: LineEdit = $VBoxContainer/HBoxContainer3/PackageVersion
@onready var package_description_edit: TextEdit = $VBoxContainer/PackageDescription
@onready var package_dependencies_edit: LineEdit = $VBoxContainer/HBoxContainerDependencies/PackageDependenciesEdit
@onready var error_message_label: RichTextLabel = $VBoxContainer/ErrorMessage

signal create(path: String, name: String, version: String, description: String, dependencies: Array)

# Store initial values to restore if dialog is closed without creating a package
var _initial_package_path: String = ""
var _initial_package_name: String = ""
var _initial_package_version: String = "v1.0"
var _initial_package_description: String = ""
var _initial_package_dependencies: String = ""

func _enter_tree() -> void:
    # Set dialog title
    title = "Create New Package"

    # Store initial values when dialog is shown
    _store_initial_values()

func _store_initial_values() -> void:
    # Store current values as initial values
    _initial_package_path = package_path_edit.text
    _initial_package_name = package_name_edit.text
    _initial_package_version = package_version_edit.text
    _initial_package_description = package_description_edit.text
    _initial_package_dependencies = package_dependencies_edit.text

func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED:
        if not visible:
            # Dialog is being hidden - restore initial values if not created successfully
            # This will restore values when dialog is closed without clicking "Create"
            # For now, we'll just store the initial values when dialog is shown
            pass
    # Set dialog title
    title = "Create New Package"

func _ready() -> void:
    # Connect the confirmed signal to the create handler
    confirmed.connect(_on_confirmed)

# Set the package path in the dialog
func set_package_path(path: String) -> void:
    _initial_package_path = path
    package_path_edit.text = path
    # Also store initial values for other fields if they're empty
    if package_name_edit.text.is_empty():
        _initial_package_name = ""
    if package_version_edit.text.is_empty():
        _initial_package_version = "v1.0"
    if package_description_edit.text.is_empty():
        _initial_package_description = ""
    if package_dependencies_edit.text.is_empty():
        _initial_package_dependencies = ""

# Get the package path from the dialog
func get_package_path() -> String:
    return package_path_edit.text

# Get the package name from the dialog
func get_package_name() -> String:
    return package_name_edit.text

# Get the package version from the dialog
func get_package_version() -> String:
    return package_version_edit.text

# Get the package description from the dialog
func get_package_description() -> String:
    return package_description_edit.text

# Get the package dependencies from the dialog
func get_package_dependencies() -> Array:
    var deps_text = package_dependencies_edit.text
    if deps_text.is_empty():
        return []
    var deps_array = deps_text.split(",", false)
    # Trim whitespace from each dependency
    for i in range(deps_array.size()):
        deps_array[i] = deps_array[i].strip_edges()
    return deps_array

# Handle the confirmed signal (when OK button is pressed)
func _on_confirmed() -> void:
    var name = get_package_name()
    var path = get_package_path()
    
    # Validate inputs
    if name.is_empty():
        show_error("Package name cannot be empty")
        return
    
    if path.is_empty():
        show_error("Package path cannot be empty")
        return
    
    # Validate package name (should be a valid filename)
    if name.contains("/") or name.contains("\\") or name.contains(":") or name.contains("*") or name.contains("?") or name.contains("\"") or name.contains("<") or name.contains(">") or name.contains("|"):
        show_error("Package name contains invalid characters")
        return
    
    # Hide error message if validation passes
    hide_error()
    
    # Emit the create signal with all the necessary data
    var version = get_package_version() if not get_package_version().is_empty() else "v1.0"
    var description = get_package_description()
    var dependencies = get_package_dependencies()
    
    create.emit(path, name, version, description, dependencies)
    # Close the dialog after emitting the signal
    hide()
    # Clear all input fields after successful package creation
    package_name_edit.text = ""
    package_version_edit.text = "v1.0"
    package_description_edit.text = ""
    package_dependencies_edit.text = ""

# Show an error message
func show_error(message: String) -> void:
    error_message_label.text = "[color=red]%s[/color]" % message
    error_message_label.visible = true

# Hide the error message
func hide_error() -> void:
    error_message_label.visible = false
