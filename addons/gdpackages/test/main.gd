extends Node2D

func _ready() -> void:
	print("\n========== Initializing packages ==========\n")
	
	# 1. Загружаем пакеты
	PackageManager.load_packages_in_directory("res://addons/gdpackages/test/packages/")
	
	# Ждем кадр, чтобы PackageManager успел проинициализировать адаптеры
	await get_tree().process_frame
