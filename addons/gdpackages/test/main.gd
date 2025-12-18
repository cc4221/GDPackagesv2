extends Node2D
## Точка входа для демонстрационной RPG-системы на основе GDPackages

func _ready() -> void:
	print("\n========== GDPackages RPG System Demo ==========\n")
	print("Инициализация пакетов...")
	
	# Загружаем все пакеты из директории
	PackageManager.load_packages_in_directory("res://addons/gdpackages/test/packages/")
	
	print("\n========== Система инициализирована ==========")
	print("\nУправление:")
	print("  [1] - Атаковать себя")
	print("  [2] - Лечить себя")
	print("  [3] - Применить заморозку")
	print("  [4] - Применить яд")
	print("\n=========================================\n")
	
	# Даем небольшую задержку перед инициализацией переключателя пакетов
	await get_tree().process_frame
	_initialize_package_connections()
	_add_packages_to_scene()

func _add_packages_to_scene() -> void:
	## Добавляем пакеты в дерево сцены чтобы они получали input события
	print("[DEBUG] Начало добавления пакетов в сцену")
	print("[DEBUG] Всего пакетов: ", PackageManager.packages.keys().size())
	for package_name in PackageManager.packages.keys():
		var package = PackageManager.get_package(package_name)
		print("[DEBUG] Проверяю пакет: %s (null=%s, has_parent=%s)" % [package_name, package == null, package and package.get_parent() != null])
		if package and not package.get_parent():
			add_child(package)
			print("[SCENE] Пакет %s добавлен в сцену" % package_name)

func _initialize_package_connections() -> void:
	## Настраиваем связь между пакетами после загрузки
	print("[DEBUG] Начало инициализации связей между пакетами")
	
	var health_pkg = PackageManager.get_package("health_package")
	var weapon_pkg = PackageManager.get_package("weapon_package")
	var status_pkg = PackageManager.get_package("status_effect_package")
	var player_pkg = PackageManager.get_package("player_package")
	
	print("[DEBUG] health_pkg = %s" % ("null" if health_pkg == null else "ok"))
	print("[DEBUG] weapon_pkg = %s" % ("null" if weapon_pkg == null else "ok"))
	print("[DEBUG] status_pkg = %s" % ("null" if status_pkg == null else "ok"))
	print("[DEBUG] player_pkg = %s" % ("null" if player_pkg == null else "ok"))
	
	if not health_pkg or not weapon_pkg or not status_pkg or not player_pkg:
		print("Ошибка: не все пакеты загружены!")
		return
	
	# Все связи теперь устанавливаются через события, нет необходимости в прямых вызовах
	print("[INIT] Связи между пакетами установлены через события")

func _get_package_core(package: Package):
	## Вспомогательная функция для получения ядра пакета
	for child in package.get_children():
		if child.get_script():
			# Проверяем, является ли это ядром пакета
			if "set_package_reference" in child:
				return child
	return null
