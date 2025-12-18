extends Node2D

func _ready() -> void:
	# Загружаем все пакеты в директории
	PackageManager.load_packages_in_directory("res://addons/gdpackages/test/packages/")
