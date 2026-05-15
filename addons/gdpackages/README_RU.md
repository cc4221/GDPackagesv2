📦 GDPackages v2.0

GDPackages — это мощный архитектурный фреймворк для Godot 4.6+, реализующий паттерн Package-Core-Adapter (PCA). Он разработан для создания по-настоящему модульных, слабосвязанных и легко тестируемых игровых систем.

![alt text](https://img.shields.io/badge/Godot-4.6+-blue?logo=godot-engine)


![alt text](https://img.shields.io/badge/License-MIT-green)


![alt text](https://img.shields.io/badge/Status-Active-brightgreen)


![alt text](https://img.shields.io/badge/Language-GDScript-29e41f)

👨‍💻 Оригинальный автор: @Anaxarchus
📦 Репозиторий: GDPackages
✨ Расширения: Дополнительные функции добавлены с помощью ИИ.
🚀 Основные возможности

	🏗️ Архитектура PCA: Строгое разделение бизнес-логики (Core), публичного API (Adapter) и жизненного цикла (Package).

	🧩 Саб-адаптеры: Возможность разделять интерфейс пакета на несколько специализированных модулей.

	⚡ Многопоточная загрузка: Встроенный ThreadedResourceManager для асинхронной работы с ресурсами без фризов основного потока.

	🔗 Умные зависимости: Автоматическое разрешение цепочек зависимостей и поддержка ленивой загрузки (Lazy Loading).

	📡 EventBus: Глобальная шина событий с фильтрацией данных и кэшированием.

	🛠️ Инструменты редактора: Встроенный плагин для создания структуры пакета в один клик через контекстное меню.

	✅ Валидация: Автоматизированная система проверки целостности структуры и конфигурации пакетов.

📐 Архитектурный паттерн PCA

Фреймворк принудительно разделяет каждый модуль на три слоя:

	Core (Мозг): Скрипт класса RefCounted. Содержит чистую логику, расчеты и данные. Он полностью не осведомлен об узлах Godot или существовании других пакетов.

	Adapter (Лицо): Публичный интерфейс. Это единственная точка входа для общения между пакетами.

	Package (Оболочка): Узел (Node), управляющий жизненным циклом (_loaded, _unloaded). Он связывает Core и Adapter воедино.

🛠️ Быстрый старт
1. Создание пакета (Рекомендуемый способ)

	Включите плагин в Настройках проекта (Project Settings).

	Нажмите правой кнопкой мыши на любую папку в окне FileSystem -> Package.

	Введите имя (например, quest_system).

	Плагин автоматически создаст следующую структуру:

code Text

quest_system/
├── package_config.tres       # Метаданные и зависимости
├── quest_system.gd           # Главный контроллер (Package)
├── quest_system_adapter.gd   # Публичный API (Adapter)
└── src/
	└── quest_system_core.gd  # Бизнес-логика (Core)
	└── adapters/             # Директория для саб-адаптеров

2. Использование саб-адаптеров

Если ваш пакет становится слишком большим, вы можете создать саб-адаптеры (например, интерфейс инвентаря внутри пакета игрока):

	Создайте скрипт в src/adapters/inventory_sub_adapter.gd, наследующий PackageAdapter.

	Добавьте путь к нему в массив sub_adapters в файле package_config.tres.

	Внутренний доступ:
	code Gdscript

	sub_adapters["inventory_sub_adapter"].add_item(item_id)

💻 Примеры кода
Организация Core (Бизнес-логика)
code Gdscript

# res://packages/math/src/math_core.gd
extends RefCounted
class_name MathCore

func calculate_power(base: int, exp: int) -> int:
	return int(pow(base, exp))

Использование Адаптера (Публичный API)
code Gdscript

# res://packages/math/math_adapter.gd
extends PackageAdapter

func get_power(b: int, e: int) -> int:
	# Адаптеры могут хранить состояние или просто делегировать вызовы в Core
	var core = MathCore.new()
	return core.calculate_power(b, e)

Взаимодействие между пакетами
code Gdscript

# res://packages/unit/unit.gd
extends Package

func _loaded():
	# Получаем адаптер другого пакета
	var math = PackageManager.get_adapter("math")
	if math:
		var strength = math.get_power(2, 5)
		emit_message("Сила юнита рассчитана: " + str(strength))

⚠️ Правила (Dos and Don'ts)
✅ Нужно делать:

    Использовать Адаптеры: Всегда общайтесь с другими пакетами через PackageManager.get_adapter("name").

    Асинхронность: Загружайте тяжелые ресурсы через load_resource_async().

    Слабая связь: Используйте PackageEventBus для передачи событий вместо прямых жестких ссылок там, где это возможно.

    Валидация: Запускайте GDPackageValidator.validate_package_complete(path) перед релизом.

❌ Нельзя делать:

    Прямой доступ к Core: Никогда не обращайтесь к package.core или файлам внутри папки src извне пакета. Это нарушает инкапсуляцию.

    Циклические зависимости: Пакет А не должен зависеть от Б, если Б уже зависит от А. Используйте события для разрыва цикла.

    Тяжелый код в _loaded: Метод _loaded блокирует основной поток. Используйте его только для инициализации связей и ссылок.

📡 Система EventBus

Система поддерживает типизированные события с мощной фильтрацией:
code Gdscript

# Подписка с фильтром (сработает только если level > 10)
subscribe_to_event("on_player_leveled_up", _on_level_up, 
	func(data): return data.level > 10)

# Отправка события
emit_event("on_player_leveled_up", {"level": 11, "name": "Hero"})

🚀 Асинхронная загрузка ресурсов

Пакеты могут загружать свои ассеты в фоновом режиме, не вызывая фризов игры:
code Gdscript

func _loaded():
	# Постановка в очередь загрузки
	load_resource_async("main_skin", "res://assets/skin.tres")
	connect_load_finished(_on_assets_ready)

func _on_assets_ready(loaded_files: Dictionary):
	var skin = loaded_files["main_skin"]
	# Ресурс готов к использованию

🛠 Настройки PackageManager

Глобальный менеджер позволяет тонко настраивать поведение системы:

    set_lazy_loading_enabled(bool): Глобальное переключение ленивой загрузки.

    set_hot_reload_enabled(bool): Включить автоматическую перезагрузку пакетов при изменении файлов (только для режима разработки).

    unload_all_packages_safe(): Выгружает все пакеты, соблюдая граф зависимостей (сначала выгружаются зависимые пакеты).

📝 Лицензия

Распространяется под лицензией MIT. Не стесняйтесь использовать фреймворк как в коммерческих, так и в личных проектах.
