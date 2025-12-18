# Package System Examples

This directory contains example packages that demonstrate the usage of the package system.

## Available Packages

- `health_package` - Manages player health, damage and healing
- `input_package` - Handles input events and converts them to game actions
- `player_package` - Manages player state and FSM
- `status_effect_package` - Applies status effects like freeze and poison
- `weapon_package` - Manages weapon data and multipliers
- `logger_package` - Logs all events in the system

## Package Structure

Each package follows the same basic structure:

```
package_name/
├── package.gd          # Main package script
├── package_config.tres # Package configuration
├── src/                # Source code directory
│   └── package_core.gd # Core functionality
└── resources/          # Package resources
```

## Package Communication

Packages interact with each other through the event system. Each package can subscribe to events from other packages and send its own events.

Event examples:
- `input.attack` - Attack button press event
- `player.request_heal` - Player heal request
- `health.take_damage` - Damage receiving event
- `status.freeze_applied` - Freeze effect application

## Package Lifecycle

Each package goes through the following lifecycle stages:

1. **Creation** - Package instance creation
2. **Loading** - Loading the package and its dependencies
3. **Initialization** - Subscribing to events and setting up connections
4. **Operation** - Processing events and executing main logic
5. **Unloading** - Resource cleanup and package unloading