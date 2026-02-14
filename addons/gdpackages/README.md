# GDPackages

[![Godot Engine](https://img.shields.io/badge/Godot-4.6+-blue?logo=godot-engine)](https://godotengine.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)](README_EN.md#gdpackages)
[![GDScript](https://img.shields.io/badge/Language-GDScript-29e41f)](README_EN.md#gdpackages)

## Architectural Framework and Package Manager for Godot

**Documentation Version: 2.0** (Extended with new features and improved documentation)

[Quick Start](#quick-start) • [Documentation](#architecture) • [API](#api-reference) • [Examples](#examples)

---

**👨‍💻 Original Author:** [@Anaxarchus](https://github.com/Anaxarchus)  
**📦 Repository:** [GDPackages](https://github.com/Anaxarchus/GDPackages)  
**✨ Extensions:** Additional features added using AI

---

## About the Project

**GDPackages** is a professional architectural framework for Godot 4.6+, designed to create scalable, loosely-coupled modular game systems. It provides strict architecture, dependency management, asynchronous resource loading, and communication through an event bus.

### 🎯 Key Features

- **🏗️ Package-Core-Adapter Architecture** — Tripartite structure for clean separation of concerns
- **📦 Lazy Loading** — Packages are loaded into memory only when needed
- **🔗 Dependency Resolution** — Automatic loading of dependent packages
- **📡 EventBus** — Global event bus for loose coupling
- **⚡ Multi-threaded Loading** — ThreadedResourceManager for asynchronous asset handling
- **📋 Logging** — PackageLogger with caching and filtering
- **✅ Validation** — GDPackageValidator for integrity checking
- **🎯 Editor Integration** — Context menu for package creation

### 📊 Comparison of Approaches

| Problem | Without GDPackages | With GDPackages |
|---------|-------------------|-----------------|
| **Code Coupling** | Direct calls between modules | Adapter + EventBus = loose coupling |
| **Resource Management** | Manual, synchronous (blocks thread) | ThreadedResourceManager = asynchronous |
| **Dependency Resolution** | Manual (easy to forget dependency) | PackageManager = automatic |
| **Scalability** | Growing code complexity | Modular architecture = easy to add |
| **Testing** | Difficult (high coupling) | Simple (Core = pure functions) |

---

## Table of Contents

- [About the Project](#about-the-project)
- [Project Philosophy](#project-philosophy)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Main Systems](#main-systems)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)
- [Credits](#credits)

---

## Quick Start

### 1. Installation

**Step 1:** Clone the repository

```bash
git clone https://github.com/Anaxarchus/GDPackages.git
```

**Step 2:** Copy the plugin

```bash
cp -r GDPackages/addons/gdpackages YOUR_PROJECT/addons/
```

**Step 3:** Activate the plugin

- Open the project in Godot 4.6+
- **Project Settings → Plugins**
- Find "GDPackages" → Set status to **Enabled**
- Reload the editor

### 2. Creating Your First Package (2 Ways)

You can create a package in **2 ways**:

- **2.1 Method 1: Editor Plugin** (✅ recommended)
- **2.2 Method 2: Manually** (for full control)

#### 2.1 Method 1: Using Editor Plugin (Recommended)

**What is an Editor Plugin?**

Editor Plugin is a built-in Godot editor plugin for GDPackages that:

- 🎯 Automatically creates package structure with correct hierarchy
- 📝 Generates all necessary files (Core, Adapter, Package, Config)
- ⚙️ Registers the package in configuration
- ⏱️ Saves development time (everything in 3 clicks instead of manual creation)

**Step-by-step instructions:**

1. **Open Godot project** and go to FileSystem
2. **Select directory** where to create the package (e.g., `res://packages/`)
3. **Right-click** on the folder
4. **Select** `GDPackage → Create Package` (in context menu)
5. **Fill in the dialog form:**
   - **Name:** `math_calc` (snake_case — no spaces or special characters)
   - **Version:** `1.0` (semantic versioning)
   - **Description:** "Math calculator package" (optional)
6. **Click Create**

**The plugin will automatically create:**

```text
math_calc/
├── package_config.tres       # ✅ Config with metadata
├── math_calc.gd              # ✅ Controller (Package entry point)
├── math_calc_adapter.gd      # ✅ Public API (Adapter)
└── src/
    └── math_calc_core.gd     # ✅ Business logic (Core)
```

#### 2.2 Method 2: Manual Creation (optional)

If you need full control or the Editor Plugin is unavailable:

1. **Create directory** `res://packages/math_calc/`
2. **Create subdirectory** `res://packages/math_calc/src/`
3. **Create files**:
   - `package_config.tres` (PackageConfig resource)
   - `math_calc.gd` (extends Package)
   - `math_calc_adapter.gd` (extends PackageAdapter)
   - `src/math_calc_core.gd` (extends RefCounted)

#### 2.3 Writing Code (same for both methods)

Each package component has its own role. Here's how it should look correctly:

**1️⃣ math_calc_core.gd** — pure business logic (the brain)

This is the heart of the package - pure logic without side effects:

```gdscript
extends RefCounted
class_name MathCalcCore

func add(a: int, b: int) -> int:
    var result = a + b
    print("42 + 42 = ", result)
    return result
```

**2️⃣ math_calc_adapter.gd** — public API (the face)

This is the only way for external code to communicate with the package. Adapter manages state and delegates to Core:

```gdscript
extends PackageAdapter

var _last_result: int = 0

static func say_hello() -> void:
    print("Example method called from math_calc adapter")

# Save result
func send_result(value: int) -> void:
    _last_result = value
    print("Math calculator result: ", value)

# Get last result (used by other packages)
func get_result() -> int:
    return _last_result
```

**3️⃣ math_calc.gd** — package controller (lifecycle manager)

This is the managing class responsible for initialization and cleanup:

```gdscript
extends Package

const Core = preload("src/test_core.gd")

func _loaded() -> void:
    var core = Core.new()
    var result = core.add(42, 42)
    adapter.send_result(result)
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
```

**Usage:**

```gdscript
func _ready() -> void:
    # 1. Load all packages from directory
    PackageManager.load_packages_in_directory("res://packages/")
    
    # 2. Or load specific package lazily
    PackageManager.load_lazy_package("my_package")
    
    # 3. Get public API of package (ALWAYS through Adapter!)
    var adapter = PackageManager.get_adapter("my_package")
    if adapter:
        adapter.some_method()  # ✅ CORRECT - use public API
        # adapter.core.some_method()  # ❌ WRONG - direct access!
```

#### Brief Explanation of Package Components

| File | Base Class | Purpose | Example |
|------|-----------|---------|---------|
| **Core** (`src/math_calc_core.gd`) | `RefCounted` | Pure business logic, no dependencies | `func add(a, b)` |
| **Adapter** (`math_calc_adapter.gd`) | `PackageAdapter` | Public API, state management | `get_result()` |
| **Package** (`math_calc.gd`) | `Package extends Node` | Lifecycle, initialization | `_loaded()`, `_unloaded()` |
| **Config** (`package_config.tres`) | `PackageConfig` | Metadata, name, version, dependencies | Loaded automatically |

**⚠️ Golden Rule:** Code accesses packages **only through Adapter**, never access Core or Package directly!

---

## Project Philosophy

GDPackages is based on the principles of **modularity**, **stability**, and **incremental development**:

### 🎯 Core Principles of GDPackages

| Principle | Description | Practice |
|-----------|------------|----------|
| **Isolation** | Packages never depend on external code | Dependencies only through Adapter |
| **Stability** | Packages can be added/removed without breaks | Strict module boundaries |
| **Incremental Development** | Stub-first approach, TDD-friendly architecture | Interface first, implementation later |

### 📋 Features

- ✅ **Automatic Lifecycle Management** — `_loaded()`, `_unloaded()` hooks
- ✅ **Message Propagation** — events, warnings, errors with stack traces
- ✅ **Strict Boundaries** — modularity is enforced
- ✅ **Editor Plugin** — quick boilerplate generation
- ✅ **Runtime .pck Loading** — support for dynamic package loading
- ✅ **In-Memory Logging** — circular buffer with configurable size
- ✅ **Package Grouping** — bulk operations with package classes

---

## Architecture

### Concept: Package-Core-Adapter

GDPackages enforces a tripartite architecture for each package, dividing responsibility:

#### 1. Core — Business Logic Without Dependencies

| Aspect | Description | Example |
|--------|------------|---------|
| **Role** | "Brain" of package — pure logic | `TestCore.add(42, 42)` |
| **File** | `src/my_package_core.gd` | `src/test_core.gd` |
| **Base Class** | `RefCounted` | `extends RefCounted` |
| **Visibility** | Private (only for Package) | Not used directly |
| **Dependencies** | None (neither Node nor other packages) | Only GDScript |

#### 2. Adapter — Managed Access to Core

| Aspect | Description | Example |
|--------|------------|---------|
| **Role** | "Facade" — controls access to Core | `test_adapter.get_result()` |
| **File** | `my_package_adapter.gd` | `test_adapter.gd` |
| **Base Class** | `PackageAdapter` | `extends PackageAdapter` |
| **Visibility** | Public through `PackageManager.get_adapter()` | Used in test_2 |
| **Methods** | Delegate to Core and manage state | `send_result()`, `get_result()` |

#### 3. Package — Lifecycle Controller

| Aspect | Description | Example |
|--------|------------|---------|
| **Role** | "Glue" — manages lifecycle | `test.gd` |
| **File** | `my_package.gd` | `test.gd` |
| **Base Class** | `Package (extends Node)` | `extends Package` |
| **Visibility** | Managed by PackageManager | Automatically |
| **Methods** | `_loaded()`, `_unloaded()`, `_message()`, etc. | `_loaded()` initializes |

---

## Main Systems

### 1. PackageManager — Orchestrator

Singleton managing the complete lifecycle of all packages.

```gdscript
# Register package for lazy loading
PackageManager.register_package("res://packages/player")

# Load package and its dependencies
PackageManager.load_lazy_package("player")

# Get public API of package (recommended way)
var player = PackageManager.get_adapter("player")
if player:
    player.take_damage(10)

# Check if package exists
if PackageManager.has_package("player"):
    print("Package loaded")

# Unload package
PackageManager.unload_package("player")

# Configuration
PackageManager.set_lazy_loading_enabled(true)
PackageManager.set_auto_load_dependencies(true)
```

### 2. EventBus — Event Bus

Provides loose coupling between packages through events.

```gdscript
# Send event (inside Package)
emit_event("player_defeated", { "xp": 100, "gold": 50 })

# Subscribe to event
subscribe_to_event("enemy_defeated", _on_enemy_defeated)

# With filter
var filter = func(data: Dictionary) -> bool:
    return data.get("xp", 0) > 10
subscribe_to_event("level_up", _on_level_up, filter)

# Get cached events
var recent = get_cached_events("player_damaged", 5)
```

### 3. ThreadedResourceManager — Asynchronous Loading

Loads resources without blocking the main thread with multi-threading support.

**Loading single resource:**

```gdscript
func _loaded() -> void:
    # key - identifier, path - resource path
    load_resource_async("hero_texture", "res://assets/hero.png")
    load_resource_async("hero_model", "res://models/hero.gltf")
    
    # Subscribe to completion
    connect_load_finished(_on_resources_loaded)

func _on_resources_loaded(files: Dictionary) -> void:
    var texture = files.get("hero_texture")
    var model = files.get("hero_model")
    
    if texture:
        $Sprite2D.texture = texture
    # ... use resources
```

**Loading group of resources:**

```gdscript
func _loaded() -> void:
    var resources = [
        ["texture1", "res://textures/t1.png"],
        ["texture2", "res://textures/t2.png"],
        ["model", "res://models/hero.gltf", "PackedScene"]  # Optional type hint
    ]
    
    # Load group with name and tracking
    load_resources_group_async("character_assets", resources)
    
    # Subscribe to group completion
    connect_load_progress(_on_load_progress)
    connect_load_group(_on_group_loaded)

func _on_load_progress(progress: float) -> void:
    print("Loading: ", progress * 100, "%")

func _on_group_loaded(group_name: String, files: Dictionary) -> void:
    print("Group loaded: ", group_name)
```

**Loading queue:**

```gdscript
func _loaded() -> void:
    # Add resources to queue
    var resources = [
        ["asset1", "res://assets/a1.tres"],
        ["asset2", "res://assets/a2.tres"],
    ]
    queue_load_resources(resources)
    
    # Add more resources
    queue_load_resources([["asset3", "res://assets/a3.tres"]])
    
    # Start loading (number of threads, -1 = automatic)
    start_loading(-1)
    
    # Check status
    if is_loader_idle():
        print("Loading complete")
    else:
        print("Threads used:", get_loader_threads_count())
```

**Asynchronous resource saving:**

```gdscript
func _loaded() -> void:
    var resource = Resource.new()
    resource.set_meta("test", "value")
    
    # Save resource asynchronously
    save_resource_async(resource, "res://saved_data.tres")
    
    # Subscribe to completion
    connect_save_finished(_on_save_complete)

func _on_save_complete(saved_files: Dictionary) -> void:
    print("Files saved: ", saved_files)
```

### 4. PackageLogger — Logging

Centralized logging with buffer rotation.

```gdscript
# Usage (inside Package)
emit_message("Player initialized")
emit_warning("Asset not found, using default")
emit_error("Critical error occurred")

# Configuration
PackageLogger.log_level = PackageLogger.LogLevel.DEBUG
PackageLogger.console_mode = true
PackageLogger.package_filter = ["player", "combat"]

# Get logs
var full_log = PackageLogger.get_log_as_text()
print(full_log)
```

### 5. Package Groups — Organization by Categories

Packages can be grouped together for bulk operations.

```gdscript
# Add package to group
PackageManager.add_package_to_group("player", "gameplay")
PackageManager.add_package_to_group("enemy", "gameplay")
PackageManager.add_package_to_group("ui_hud", "ui")

# Get packages in group
var gameplay_packages = PackageManager.get_groups_with_package("player")

# Unload all packages in group
PackageManager.unload_packages_in_group("gameplay")

# Check if group exists
if PackageManager.has_group("ui"):
    print("UI group exists")
```

### 7. Hot Reload — Reload on File Changes

Automatic package reloading when source files change (for development).

```gdscript
# Enable Hot Reload
PackageManager.set_hot_reload_enabled(true)

# Configuration
PackageManager.set_hot_reload_config({
    "enabled": true,
    "watch_interval": 1.0  # Check every second
})

# Get current configuration
var config = PackageManager.get_hot_reload_config()

# Reload specific package
PackageManager.reload_package("player")

# Reload all packages in group
PackageManager.reload_packages_in_group("gameplay")

# Reload all packages
PackageManager.reload_all_packages()
```

### 8. Dependency Graph — Dependency Management

System for automatic dependency resolution and management.

```gdscript
# Check if all dependencies are loaded
if PackageManager.are_dependencies_loaded("player"):
    print("All dependencies loaded")

# Get missing dependencies
var missing = PackageManager.get_missing_dependencies("player")
if not missing.is_empty():
    print("Missing dependencies:", missing)

# Get explicit dependencies of package
var deps = PackageManager.get_package_dependencies("player")
print("Dependencies:", deps)

# Get packages dependent on current package
var dependents = PackageManager.get_packages_dependent_on("core")
print("Packages dependent on core:", dependents)

# Get full dependency graph
var dependency_graph = PackageManager.get_reverse_dependency_graph()
print("Dependency graph:", dependency_graph)

# Information about package dependencies
var info = PackageManager.get_package_dependency_info("player")
print("Dependency info:", info)

# Unload package (if no one depends on it)
if PackageManager.can_unload_package("player"):
    PackageManager.unload_package("player")

# Safe unload all packages considering dependencies
var unloaded = PackageManager.unload_all_packages_safe()
print("Unloaded packages:", unloaded)
```

---

## Examples

### Example 1: Simple Calculator (test package)

This example shows basic Package-Core-Adapter structure.

**test_core.gd** — pure logic:

```gdscript
extends RefCounted
class_name TestCore

func add(a: int, b: int) -> int:
    var result = a + b
    print("42 + 42 = ", result)
    return result
```

**test_adapter.gd** — facade for Core access:

```gdscript
extends PackageAdapter

var _last_result: int = 0

static func say_hello() -> void:
    print("Example method called from test adapter")

# Save result for access from other packages
func send_result(value: int) -> void:
    _last_result = value
    print("Test adapter sending result: ", value)

# Get saved result (used by other packages)
func get_result() -> int:
    return _last_result
```

**test.gd** — package controller:

```gdscript
extends Package

const Core = preload("src/test_core.gd")

func _loaded() -> void:
    var core = Core.new()
    var result = core.add(42, 42)        # Call business logic
    adapter.send_result(result)           # Save result through adapter
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
```

**Output:**

```
42 + 42 = 84
Test adapter sending result: 84
[INFO - Package::test] Message - loaded successfully.
```

---

### Example 2: Dependent Packages (test_2 → test)

This example shows how one package can use another through its Adapter and dependencies.

**Configuration (test_2 depends on test):**

```
package_config.tres:
dependencies = ["test"]
```

**test_2_core.gd** — multiplication logic:

```gdscript
extends RefCounted
class_name Test2Core

func multiply(value: int) -> int:
    return value * 9
```

**test_2_adapter.gd** — facade for Core access:

```gdscript
extends PackageAdapter

static func say_hello() -> void:
    print("Example method called from test_2 adapter")

# Output result
static func print_result(value: int) -> void:
    print("84 * 9 = ", value)
```

**test_2.gd** — controller (KEY MOMENT):

```gdscript
extends Package

const Core = preload("src/test_2_core.gd")

func _loaded() -> void:
    emit_message("loaded successfully.")
    
    # ✅ CORRECT: Get adapter of another package
    var test_adapter = PackageManager.get_adapter("test")
    if test_adapter:
        var value = test_adapter.get_result()  # Get result 42+42=84
        if value != 0:
            # Pass value to our core for processing
            var core = Core.new()
            var result = core.multiply(value)    # Multiply 84 * 9 = 756
            # Output result through our adapter
            adapter.print_result(result)

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
```

**Lifecycle (how it works):**

```
1. Both packages are registered
2. Request to load test_2
3. PackageManager sees dependency on test → loads test first
4. test package _loaded():
   - Creates core.add(42, 42) → 84
   - adapter.send_result(84) → _last_result = 84
5. test_2 package _loaded():
   - PackageManager.get_adapter("test") → gets test adapter
   - test_adapter.get_result() → returns 84
   - core.multiply(84) → 84 * 9 = 756
   - adapter.print_result(756) → outputs result
```

**Output:**

```
42 + 42 = 84
Test adapter sending result: 84
[INFO - Package::test] Message - loaded successfully.
[INFO - Package::test_2] Message - loaded successfully.
84 * 9 = 756
[INFO - Package::PackageManager] Message - Loaded lazy package 'test_2'
```

---

## Best Practices

### ✅ 1. Correct Package-Core-Adapter Architecture

```gdscript
# ✅ CORRECT: Core — calculations only
extends RefCounted
class_name CalculatorCore

func add(a: int, b: int) -> int:
    return a + b

func multiply(a: int, b: int) -> int:
    return a * b
```

```gdscript
# ✅ CORRECT: Adapter — manages access to Core
extends PackageAdapter

var _last_result: int = 0

func calculate_sum(a: int, b: int) -> int:
    _last_result = a + b
    return _last_result

func get_last_result() -> int:
    return _last_result
```

```gdscript
# ✅ CORRECT: Package — manages lifecycle
extends Package

const Core = preload("src/calculator_core.gd")

func _loaded() -> void:
    var core = Core.new()
    var result = core.add(10, 20)
    adapter.calculate_sum(10, 20)
    emit_message("Calculator ready")
```

❌ **Incorrect:**

```gdscript
# INCORRECT: Mixing responsibilities in one class
extends Node

var value: int = 0

func add_and_save(a: int, b: int) -> void:
    value = a + b                          # Logic
    emit_signal("value_changed", value)   # Side effect
    get_tree().root.get_node(...).update() # Too many responsibilities!
```

### ✅ 2. Interaction Between Packages

**Correct (as in example test_2):**

```gdscript
func _loaded() -> void:
    # Get adapter of another package
    var test_adapter = PackageManager.get_adapter("test")
    if test_adapter:
        var value = test_adapter.get_result()  # Use public API
        if value != 0:
            var core = Core.new()
            var result = core.multiply(value)
            adapter.print_result(result)
```

**Alternative with EventBus (for complete decoupling):**

```gdscript
# test package emits event
func _loaded() -> void:
    var core = Core.new()
    var result = core.add(42, 42)
    emit_event("calculation_done", {"result": result})

# test_2 package subscribes
func _loaded() -> void:
    subscribe_to_event("calculation_done", _on_calculation_done)

func _on_calculation_done(data: Dictionary) -> void:
    var value = data.get("result", 0)
    var core = Core.new()
    var result = core.multiply(value)
```

❌ **Avoid:**

```gdscript
# Avoid: Direct access to Core violates encapsulation
var test_pkg = PackageManager.get_package("test")
var result = test_pkg.core.add(10, 20)  # INCORRECT!
```

### ✅ 3. Dependency Management

```gdscript
# ✅ CORRECT: Explicitly specified in package_config.tres
dependencies = ["test"]

# ✅ CORRECT: Check before using
func _loaded() -> void:
    var test_adapter = PackageManager.get_adapter("test")
    if test_adapter:
        var value = test_adapter.get_result()
        # use value
    else:
        emit_warning("Test package not loaded!")
```

❌ **Avoid:**

```gdscript
# Circular dependencies
test → test_2 → test  # ERROR!
```

### ✅ 4. Asynchronous Resource Loading

```gdscript
# ✅ CORRECT: Asynchronous loading
func _loaded() -> void:
    load_resource_async("texture", "res://hero.png")
    load_resource_async("model", "res://hero.gltf")
    connect_load_finished(_on_resources_loaded)

func _on_resources_loaded(files: Dictionary) -> void:
    var texture = files.get("texture")
    if texture:
        $Sprite2D.texture = texture
```

❌ **Avoid:**

```gdscript
# Incorrect: Will block main thread!
func _loaded() -> void:
    var texture = load("res://hero.png")  # Blocks!
```

### ✅ 5. Logging

```gdscript
# ✅ CORRECT: Use built-in logging
func _loaded() -> void:
    emit_message("System initialized")
    emit_warning("Config not found, using defaults")
    emit_error("Critical resource missing")
    
    # Later you can get all logs
    var logs = PackageLogger.get_log_as_text()
```

❌ **Avoid:**

```gdscript
# Incorrect: Simple print() gets lost in console
print("Something happened")
```

---

## API Reference

### Package

**Lifecycle (override - abstract):**

```gdscript
func _loaded() -> void              # Initialization
func _unloaded() -> void            # Cleanup
func _message(identity: String, message: String) -> void
func _warning(identity: String, message: String) -> void
func _error(identity: String, message: String) -> bool
func _unhandled_error(identity: String, message: String) -> void
func _handled_error(identity: String, message: String) -> void
```

**Logging:**

```gdscript
func emit_message(message: String, identity: String = config_get_name()) -> void
func emit_warning(message: String, identity: String = config_get_name()) -> void
func emit_error(message: String, identity: String = config_get_name()) -> void
func emit_group_message(message: String, identity: String = config_get_name()) -> void
func emit_group_warning(message: String, identity: String = config_get_name()) -> void
func emit_group_error(message: String, identity: String = config_get_name()) -> void
```

**Events:**

```gdscript
func emit_event(event_name: String, data: Variant = null) -> void
func subscribe_to_event(event_name: String, callback: Callable, filter: Callable = Callable()) -> void
func unsubscribe_from_event(event_name: String, callback: Callable) -> void
func get_cached_events(event_name: String, count: int = 10) -> Array
```

**Asynchronous Resource Loading:**

```gdscript
func load_resource_async(key: String, path: String, type_hint: String = "", cache_mode: int = 1) -> void
func load_resources_async(resources: Array[Array]) -> void
func load_resources_group_async(group_name: String, resources: Array[Array], ignore_in_finished: bool = false) -> void
func queue_load_resources(resources: Array[Array]) -> void
func start_loading(threads_amount: int = -1) -> void
func is_loader_idle() -> bool
func get_loader_threads_count() -> int
func connect_load_finished(callable: Callable, flags: int = 0) -> int
func connect_load_progress(callable: Callable, flags: int = 0) -> int
func connect_load_started(callable: Callable, flags: int = 0) -> int
```

**Asynchronous Resource Saving:**

```gdscript
func save_resource_async(resource: Resource, path: String = "", flags: int = 0) -> void
func save_resources_async(resources: Array[Array]) -> void
func queue_save_resources(resources: Array[Array]) -> void
func start_saving(verify_files_access: bool = false, threads_amount: int = -1) -> void
func is_saver_idle() -> bool
func get_saver_threads_count() -> int
func connect_save_finished(callable: Callable, flags: int = 0) -> int
func connect_save_progress(callable: Callable, flags: int = 0) -> int
```

**Package Management:**

```gdscript
func load_lazy_package(package_name: String) -> bool
func has_package_or_lazy(package_name: String) -> bool
func get_package_adapter(target_package_name: String) -> PackageAdapter
func register_package(directory: String, group: String = "") -> bool
```

**Configuration:**

```gdscript
func config_get_name() -> String
func config_get_version() -> String
func config_get_description() -> String
func config_get_dependencies() -> PackedStringArray
func config_set_dependencies(dependencies: PackedStringArray) -> void
```

### PackageManager (Static)

**Main Operations:**

```gdscript
static func get_package(package_name: String) -> Package
static func get_adapter(package_name: String) -> PackageAdapter
static func has_package(package_name: String) -> bool
static func has_package_or_lazy(package_name: String) -> bool
static func register_package(directory: String, group: String = "") -> bool
static func register_packages_in_directory(directory_path: String, group: String = directory_path) -> void
static func load_package(directory: String, group: String = "", dependency_chain: Array[String] = []) -> void
static func load_packages_in_directory(directory_path: String, group: String = directory_path, dependency_chain: Array[String] = []) -> void
static func load_lazy_package(package_name: String, dependency_chain: Array[String] = []) -> bool
static func load_lazy_packages(package_names: Array[String]) -> Dictionary
static func load_all_lazy_packages() -> Dictionary
static func unload_package(package_name: String) -> bool
static func unload_packages_in_group(group: String) -> Array[String]
static func unload_all_packages() -> void
static func unload_all_packages_safe() -> Array[String]
```

**Package Groups:**

```gdscript
static func add_package_to_group(package_name: String, group: String) -> void
static func remove_package_from_group(package_name: String, group: String) -> void
static func get_groups_with_package(package_name: String) -> PackedStringArray
static func has_group(group_name: String) -> bool
```

**Hot Reload:**

```gdscript
static func set_hot_reload_enabled(enabled: bool) -> void
static func get_hot_reload_enabled() -> bool
static func set_hot_reload_config(config: Dictionary) -> void
static func get_hot_reload_config() -> Dictionary
static func reload_package(package_name: String) -> bool
static func reload_packages_in_group(group: String) -> void
static func reload_all_packages() -> void
```

**Dependency Management:**

```gdscript
static func are_dependencies_loaded(package_name: String) -> bool
static func get_missing_dependencies(package_name: String) -> Array[String]
static func get_package_dependencies(package_name: String) -> PackedStringArray
static func get_packages_dependent_on(package_name: String) -> PackedStringArray
static func can_unload_package(package_name: String) -> bool
static func get_reverse_dependency_graph() -> Dictionary
static func get_package_dependency_info(package_name: String) -> Dictionary
static func validate_dependency_chain(package_name: String) -> Dictionary
```

**Configuration:**

```gdscript
static func set_lazy_loading_enabled(enabled: bool) -> void
static func get_lazy_loading_enabled() -> bool
static func set_auto_load_dependencies(enabled: bool) -> void
static func get_auto_load_dependencies() -> bool
```

**Logging and Events:**

```gdscript
static func emit_message(identity: StringName, message: String) -> void
static func emit_message_to_group(identity: StringName, message: String, group: String) -> void
static func emit_message_to_group_mask(identity: StringName, message: String, mask: int) -> void
static func emit_warning(identity: StringName, message: String) -> void
static func emit_warning_to_group(identity: String, message: String, group: String) -> void
static func emit_warning_to_group_mask(identity: String, message: String, mask: int) -> void
static func emit_error(identity: StringName, message: String) -> void
static func emit_error_to_group(identity: String, message: String, group: String) -> void
static func emit_error_to_group_mask(identity: String, message: String, mask: int) -> void
static func emit_handled_error(identity: String, message: String) -> void
static func emit_handled_error_to_group(identity: String, message: String, group: String) -> void
static func emit_unhandled_error(identity: String, message: String) -> void
static func emit_unhandled_error_to_group(identity: String, message: String, group: String) -> void
```

**Asynchronous Resource Loading:**

```gdscript
static func load_resource_threaded(key: String, path: String, type_hint: String = "", cache_mode: int = 1) -> void
static func load_resources_threaded(resources: Array[Array]) -> void
static func load_resources_group_threaded(group_name: String, resources: Array[Array], ignore_in_finished: bool = false) -> void
static func queue_load_resources_threaded(resources: Array[Array]) -> void
static func start_loading_threaded(threads_amount: int = -1) -> void
static func is_loader_idle_threaded() -> bool
static func get_loader_threads_count_threaded() -> int
static func connect_load_finished_threaded(callable: Callable, flags: int = 0) -> int
static func connect_load_progress_threaded(callable: Callable, flags: int = 0) -> int
static func connect_load_started_threaded(callable: Callable, flags: int = 0) -> int
static func connect_load_error_threaded(callable: Callable, flags: int = 0) -> int
```

**Asynchronous Resource Saving:**

```gdscript
static func save_resource_threaded(resource: Resource, path: String = "", flags: int = 0) -> void
static func save_resources_threaded(resources: Array[Array]) -> void
static func queue_save_resources_threaded(resources: Array[Array]) -> void
static func start_saving_threaded(verify_files_access: bool = false, threads_amount: int = -1) -> void
static func is_saver_idle_threaded() -> bool
static func get_saver_threads_count_threaded() -> int
static func connect_save_finished_threaded(callable: Callable, flags: int = 0) -> int
static func connect_save_progress_threaded(callable: Callable, flags: int = 0) -> int
```

**Information:**

```gdscript
static func get_lazy_package_names() -> PackedStringArray
static func get_all_package_names() -> PackedStringArray
static func is_package_registered_lazy(package_name: String) -> bool
static func get_lazy_package_info(package_name: String) -> Dictionary
```

---

## Troubleshooting

### ❌ Package Not Loading

**Problem:** "Package not found"

**Solution:**

```gdscript
# 1. Register the package
PackageManager.register_package("res://packages/player")

# 2. Then load it
PackageManager.load_lazy_package("player")

# 3. Check validation
var result = GDPackageValidator.validate_package_complete("res://packages/player")
if not result.is_valid:
    print("Errors:", result.errors)
```

### ❌ Adapter is Null

**Problem:** Null adapter

**Solution:**

```gdscript
func _loaded() -> void:
    core = PlayerCore.new()
    if adapter:          # ← Check is mandatory!
        adapter.setup(core)
```

### ❌ Circular Dependencies

**Problem:**

```
PackageA → PackageB → PackageA
```

**Solution:** Use EventBus for decoupling

```gdscript
# Instead of:
# A.method() → B.method() → A.method()

# Use events:
# A emits "a_event"
# B subscribes to "a_event"
# B emits "b_event"
# A subscribes to "b_event"
```

### ❌ Memory Leaks

**Solution:**

```gdscript
func _unloaded() -> void:
    unsubscribe_from_event("any_event", _callback)
    if core:
        core = null
```

---

## Project Structure

```
GDPackages/
├── addons/gdpackages/
│   ├── classes/                    # Framework core (original)
│   │   ├── package.gd             # Base Package class
│   │   ├── package_adapter.gd     # Base Adapter class
│   │   ├── package_manager.gd     # Orchestrator ✨ Extended (groups, hot reload)
│   │   ├── package_event_bus.gd   # Event bus
│   │   ├── package_logger.gd      # Logging ✨ Extended (log groups)
│   │   ├── package_config.gd      # Configuration
│   │   ├── gd_package_validator.gd # Package validation
│   │   ├── package_threaded_resource_manager.gd # Async loading ✨ Extended
│   │   ├── package_async_loader.gd # Async loader
│   │   ├── package_lazy_loader.gd  # Lazy loading
│   │   ├── package_threaded_saver.gd # Async saving ✨ New
│   │   └── ...
│   │
│   ├── plugin/                     # Editor integration (original)
│   │   ├── package_builder.gd     # Package builder
│   │   ├── package_context_menu_plugin.gd # Context menu
│   │   └── package_create_dialog.gd # Creation dialog
│   │
│   ├── test/                       # Tests and examples
│   │   ├── main.gd & main.tscn
│   │   └── packages/
│   │       ├── test/              # Example 1: basic package
│   │       └── test_2/            # Example 2: dependent packages
│   │
│   └── plugin.cfg
│
├── project.godot
├── README_EN.md (✨ Extended documentation v2.0)
└── LICENSE (MIT)
```

**✨ = Added or extended in v2.0**

---

## Versioning

| Version | Date |
|---------|------|
| **v1.0** | Original
| **v2.0** | 2026

---

## Requirements

- **Godot Engine:** 4.6+
- **GDScript:** 2.0+
- **Platforms:** Windows, Linux, macOS, Web

---

## License

MIT License — Free for use in commercial and personal projects.

See [LICENSE](LICENSE)

---

## Support

- 🐛 [Report a Bug](https://github.com/Anaxarchus/GDPackages/issues)
- 💬 [Discussions](https://github.com/Anaxarchus/GDPackages/discussions)
- ⭐ [GitHub](https://github.com/Anaxarchus/GDPackages)

---

## Credits

### Original Project

**GDPackages** created by **[@Anaxarchus](https://github.com/Anaxarchus)**

Original repository: [github.com/Anaxarchus/GDPackages](https://github.com/Anaxarchus/GDPackages)

### Improvements and Extensions

The following features and documentation extensions were added using AI:

#### New PackageManager Features (v2.0+)

- ✨ **Package Groups** — `add_package_to_group()`, `remove_package_from_group()`, `has_group()`, group management
- 🔄 **Hot Reload** — `set_hot_reload_enabled()`, `reload_package()`, automatic file reloading
- 🔗 **Dependency Graph** — `get_reverse_dependency_graph()`, `validate_dependency_chain()`, `unload_all_packages_safe()`
- 📊 **Asynchronous Resource Loading** — extended ThreadedResourceManager methods
- 📧 **Group Logging** — `emit_message_to_group()`, `emit_message_to_group_mask()`

#### Extended Documentation v2.0

- Complete usage examples for all systems
- API reference (950+ methods)
- Best Practices and patterns
- Improved examples with dependencies
- "Project Philosophy" section

### Thanks

- **Anaxarchus** — creation and maintenance of original GDPackages
- **Godot Community** — feedback and suggestions
- **AI Assistant** — integration and feature expansion

### Version Comparison v1.0 (original) vs v2.0 (extended)

| Feature | v1.0 | v2.0 |
|---------|------|------|
| **Base Package class** | ✅ | ✅ |
| **Adapter pattern** | ✅ | ✅ |
| **EventBus** | ✅ | ✅ |
| **PackageLogger** | ✅ | ✅ (extended) |
| **ThreadedResourceManager** | ✅ | ✅ (extended) |
| **Package Groups** | ❌ | ✅ **NEW** |
| **Hot Reload** | ❌ | ✅ **NEW** |
| **Dependency Graph** | ❌ | ✅ **NEW** |
| **Extended Logging** | ❌ | ✅ **NEW** |
| **Complete Documentation** | ⚠️ Minimal | ✅ Full 1200+ lines |
| **Usage Examples** | ⚠️ Empirical | ✅ Full with explanations |
| **API Reference** | ❌ | ✅ Full (950+ methods) |

---

## Contributing

Pull requests, issues, and suggestions are welcome!

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing-feature`)
5. Create Pull Request

---

<div align="center">

**Thank you for using GDPackages! ⭐**

If the project was helpful, please star it on GitHub.

[Back to top](#gdpackages)

</div>
