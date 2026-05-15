📦 GDPackages v2.0

GDPackages is a powerful architectural framework for Godot 4.6+, implementing the Package-Core-Adapter (PCA) pattern. It is designed to create truly modular, loosely coupled, and easily testable game systems.

![alt text](https://img.shields.io/badge/Godot-4.6+-blue?logo=godot-engine)


![alt text](https://img.shields.io/badge/License-MIT-green)


![alt text](https://img.shields.io/badge/Status-Active-brightgreen)


![alt text](https://img.shields.io/badge/Language-GDScript-29e41f)

👨‍💻 Original Author: @Anaxarchus
📦 Repository: GDPackages
✨ Extensions: Additional features added using AI
🚀 Key Features

	🏗️ PCA Architecture: Strict separation of business logic (Core), public API (Adapter), and lifecycle (Package).

	🧩 Sub-Adapters: Ability to split a package's interface into multiple specialized modules.

    ⚡ Multi-threaded Loading: Built-in ThreadedResourceManager for asynchronous asset handling without main-thread stutters.

    🔗 Smart Dependencies: Automatic dependency chain resolution and Lazy Loading support.

    📡 EventBus: Global event system with data filtering and caching.

    🛠️ Editor Tools: Built-in plugin to create package structures with one click via the context menu.

    ✅ Validation: Automated system to verify package structure and configuration integrity.

📐 The PCA Architectural Pattern

The framework enforces a three-layer separation for every module:

    Core (The Brain): A RefCounted script. It contains pure logic, calculations, and data. It is completely unaware of Godot nodes or the existence of other packages.

    Adapter (The Face): The public interface. This is the single entry point for communication between packages.

    Package (The Wrapper): A Node that manages the lifecycle (_loaded, _unloaded). It glues the Core and Adapter together.

🛠️ Quick Start
1. Creating a Package (Recommended Way)

    Enable the plugin in your Project Settings.

    Right-click any folder in the FileSystem dock -> Package.

    Enter a name (e.g., quest_system).

    The plugin will automatically generate the following structure:

code Text

quest_system/
├── package_config.tres       # Metadata and dependencies
├── quest_system.gd           # Main controller (Package)
├── quest_system_adapter.gd   # Public API (Adapter)
└── src/
    └── quest_system_core.gd  # Business logic (Core)
    └── adapters/             # Directory for sub-adapters

2. Using Sub-Adapters

If your package becomes too large, you can create sub-adapters (e.g., an inventory interface inside a player package):

    Create a script in src/adapters/inventory_sub_adapter.gd inheriting from PackageAdapter.

    Add its path to the sub_adapters array in package_config.tres.

    Internal Access:
    code Gdscript

    sub_adapters["inventory_sub_adapter"].add_item(item_id)

💻 Code Examples
Organizing the Core (Business Logic)
code Gdscript

# res://packages/math/src/math_core.gd
extends RefCounted
class_name MathCore

func calculate_power(base: int, exp: int) -> int:
	return int(pow(base, exp))

Using the Adapter (Public API)
code Gdscript

# res://packages/math/math_adapter.gd
extends PackageAdapter

func get_power(b: int, e: int) -> int:
	# Adapters can maintain state or simply delegate calls to the Core
	var core = MathCore.new()
	return core.calculate_power(b, e)

Inter-Package Communication
code Gdscript

# res://packages/unit/unit.gd
extends Package

func _loaded():
	# Retrieve the adapter of another package
	var math = PackageManager.get_adapter("math")
	if math:
		var strength = math.get_power(2, 5)
		emit_message("Unit strength calculated: " + str(strength))

⚠️ Dos and Don'ts
✅ Do:

	Use Adapters: Always communicate with other packages via PackageManager.get_adapter("name").

	Stay Async: Load heavy assets using load_resource_async().

	Loose Coupling: Use the PackageEventBus to propagate events instead of direct hard-references where possible.

	Validate: Run GDPackageValidator.validate_package_complete(path) before shipping.

❌ Don't:

    Direct Core Access: Never access package.core or files inside the src folder from outside the package. This violates encapsulation.

    Circular Dependencies: Package A should not depend on B if B already depends on A. Use events to break the cycle.

    Heavy Code in _loaded: The _loaded method blocks the main thread. Use it only to initialize connections and references.

📡 EventBus System

The system supports typed events with powerful filtering:
code Gdscript

# Subscribe with a filter (only triggers if level > 10)
subscribe_to_event("on_player_leveled_up", _on_level_up, 
	func(data): return data.level > 10)

# Emitting an event
emit_event("on_player_leveled_up", {"level": 11, "name": "Hero"})

🚀 Asynchronous Resource Loading

Packages can load their assets in the background without freezing the game:
code Gdscript

func _loaded():
	# Queue loading
	load_resource_async("main_skin", "res://assets/skin.tres")
	connect_load_finished(_on_assets_ready)

func _on_assets_ready(loaded_files: Dictionary):
	var skin = loaded_files["main_skin"]
	# Resource is now ready for use

🛠 PackageManager Settings

The global manager allows fine-tuning of the system behavior:

    set_lazy_loading_enabled(bool): Toggle lazy loading globally.

    set_hot_reload_enabled(bool): Enable automatic package reloading when files are modified (Developer mode only).

    unload_all_packages_safe(): Unloads all packages while respecting the dependency graph (dependents are unloaded first).

📝 License

Distributed under the MIT License. Feel free to use it in both commercial and personal projects.
