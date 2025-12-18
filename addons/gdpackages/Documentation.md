# GDPackages Documentation

## Package Development Guide

### Creating a New Package

1. **Use the Editor Context Menu**:
   - Right-click in the FileSystem dock
   - Select "Package" from the context menu
   - Fill in the package information in the dialog

2. **Package Structure**:
   - `package.gd` - Main package script
   - `src/` - Source code directory
   - `resources/` - Package resources
   - `package_config.tres` - Package configuration

3. **Package Configuration**:
   - Name: Unique package identifier
   - Version: Package version
   - Dependencies: List of required packages

### Package Lifecycle

1. **Registration**: Package is registered in the system
2. **Loading**: Package is loaded and initialized
3. **Operation**: Package handles events and messages
4. **Unloading**: Package is unloaded from memory

### Package Communication

- **Events**: Use `emit_event()` to send events between packages
- **Messages**: Use `emit_message()` to send messages
- **Adapters**: Use adapters for direct package-to-package communication

### Best Practices

1. **Minimal Dependencies**: Keep package dependencies to a minimum
2. **Clear Interfaces**: Define clear interfaces for package interaction
3. **Error Handling**: Implement proper error handling
4. **Logging**: Use the package logger for debugging

## API Reference

### Package Methods

- `config_get_name()` - Returns the package name
- `emit_event(event_name, data, source)` - Emits an event
- `emit_message(message, data)` - Emits a message
- `subscribe_to_event(event_name, callback)` - Subscribes to an event
- `get_package_instance(name)` - Gets a package instance
- `get_package_adapter(name)` - Gets a package adapter

### PackageEventBus Methods

- `emit_event(event_name, data, source)` - Emits an event to all subscribers
- `subscribe_to_event(event_name, callback, package_name)` - Subscribes to an event
- `get_cached_events(event_name, count)` - Gets cached events

### PackageLogger Methods

- `log_info(identity, message)` - Logs an info message
- `log_warning(identity, message)` - Logs a warning message
- `log_error(identity, message)` - Logs an error message
- `set_log_level(level)` - Sets the logging level

### PackageConfig Methods

- `to_dict()` - Converts the configuration to a dictionary
- `from_dict(dict)` - Initializes the configuration from a dictionary

## Dependency Management

Packages can declare dependencies in their configuration. The system will ensure that dependencies are loaded before the package is initialized.

### Dependency Loading

1. **Automatic Loading**: Dependencies are loaded automatically
2. **Dependency Checking**: Check for dependencies before using them
3. **Optional Dependencies**: Handle optional dependencies gracefully

## Usage Examples

### Basic Package

```gdscript
tool
extends Package

func _on_load() -> bool:
    print("Package loaded")
    return true

func _on_unload() -> bool:
    print("Package unloaded")
    return true

func _on_message(identity: String, message: String, data: Variant) -> void:
    print("Received message: ", message)
```


### Event Communication

```gdscript
# Sending an event
emit_event("player.died", {"player_id": 1}, config_get_name())

# Receiving an event
func _on_player_died(identity: String, data: Dictionary) -> void:
    print("Player ", data.get("player_id"), " died")
```


### Package with Adapter

```gdscript
# Main package
tool
extends Package

var adapter: MyPackageAdapter

func _on_load() -> bool:
    adapter = MyPackageAdapter.new(self)
    return true

func get_adapter() -> Resource:
    return adapter
```
