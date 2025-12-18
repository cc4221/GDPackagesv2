extends Node
## InputPackageCore - Ядро пакета ввода
## Обрабатывает нажатия физических клавиш 1,2,3,4
## Эмитит события через главный пакет

class_name InputPackageCore

var _package: Package = null

func set_package_reference(package: Package) -> void:
	_package = package
	print("[InputPackageCore] set_package_reference() вызвана, пакет: ", package.config_get_name())

func _input(event: InputEvent) -> void:
	if not _package:
		print("[InputPackageCore] ОШИБКА: _package = null")
		return
	
	# Обработка нажатий числовых клавиш
	if event is InputEventKey and event.pressed:
		print("[InputPackageCore] Нажата клавиша: ", event.keycode)
		match event.keycode:
			KEY_1:
				print("[InputPackageCore] Эмитим input.attack")
				_package.emit_event("input.attack", {"action": "attack"})
				get_tree().root.set_input_as_handled()
			KEY_2:
				print("[InputPackageCore] Эмитим input.heal")
				_package.emit_event("input.heal", {"action": "heal"})
				get_tree().root.set_input_as_handled()
			KEY_3:
				print("[InputPackageCore] Эмитим input.freeze")
				_package.emit_event("input.freeze", {"action": "freeze"})
				get_tree().root.set_input_as_handled()
			KEY_4:
				print("[InputPackageCore] Эмитим input.poison")
				_package.emit_event("input.poison", {"action": "poison"})
				get_tree().root.set_input_as_handled()

func example_method() -> void:
	print("[InputPackageCore] Example method called")