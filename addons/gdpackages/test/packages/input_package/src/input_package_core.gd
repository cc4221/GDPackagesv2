extends Node

class_name InputPackageCore

var _package: Package = null

func set_package_reference(package: Package) -> void:
	_package = package
	print("[InputPackageCore] set_package_reference() called, package: ", package.config_get_name())

func _input(event: InputEvent) -> void:
	if not _package:
		print("[InputPackageCore] ERROR: _package = null")
		return
	
	if event is InputEventKey and event.pressed:
		print("[InputPackageCore] Key pressed: ", event.keycode)
		match event.keycode:
			KEY_1:
				print("[InputPackageCore] Emitting input.attack")
				_package.emit_event("input.attack", {"action": "attack"})
				get_tree().root.set_input_as_handled()
			KEY_2:
				print("[InputPackageCore] Emitting input.heal")
				_package.emit_event("input.heal", {"action": "heal"})
				get_tree().root.set_input_as_handled()
			KEY_3:
				print("[InputPackageCore] Emitting input.freeze")
				_package.emit_event("input.freeze", {"action": "freeze"})
				get_tree().root.set_input_as_handled()
			KEY_4:
				print("[InputPackageCore] Emitting input.poison")
				_package.emit_event("input.poison", {"action": "poison"})
				get_tree().root.set_input_as_handled()

func example_method() -> void:
	print("[InputPackageCore] Example method called")