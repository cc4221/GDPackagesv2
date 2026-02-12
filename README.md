# GDPackages

[![Godot Engine](https://img.shields.io/badge/Godot-4.6+-blue?logo=godot-engine)](https://godotengine.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active-brightgreen)](README.md#gdpackages)
[![GDScript](https://img.shields.io/badge/Language-GDScript-29e41f)](README.md#gdpackages)

## Архитектурный фреймворк и менеджер пакетов для Godot

**Версия документации: 2.0** (Расширенная с новыми функциями и улучшенной документацией)

[Быстрый старт](#быстрый-старт) • [Документация](#архитектура) • [API](#api-справочник) • [Examples](#примеры)

---

**👨‍💻 Оригинальный автор:** [@Anaxarchus](https://github.com/Anaxarchus)  
**📦 Репозиторий:** [GDPackages](https://github.com/Anaxarchus/GDPackages)  
**✨ Расширения:** Дополнительные функции добавлены с использованием AI

---

## О Проекте

**GDPackages** — это профессиональный архитектурный фреймворк для Godot 4.6+, предназначенный для создания масштабируемых, слабосвязанных (loosely-coupled) модульных игровых систем. Он обеспечивает строгую архитектуру, управление зависимостями, асинхронную загрузку ресурсов и коммуникацию через событийную шину.

### 🎯 Основные возможности

- **🏗️ Архитектурная модель Package-Core-Adapter** — Триединая структура для чистого разделения ответственности
- **📦 Ленивая загрузка** — Пакеты загружаются в памясть только при необходимости
- **🔗 Разрешение зависимостей** — Автоматическая загрузка зависимых пакетов
- **📡 EventBus** — Глобальная шина событий для слабой связности
- **⚡ Многопоточная загрузка** — ThreadedResourceManager для асинхронной работы с ассетами
- **📋 Логирование** — PackageLogger с кэшированием и фильтрацией
- **✅ Валидация** — GDPackageValidator для проверки целостности
- **🎯 Интеграция с редактором** — Контекстное меню для создания пакетов

### 📊 Сравнение подходов

| Проблема | Без GDPackages | С GDPackages |
|----------|----------------|--------------|
| **Связность кода** | Прямые вызовы между модулями | Adapter + EventBus = слабая связность |
| **Управление ресурсами** | Ручное, синхронное (блокирует поток) | ThreadedResourceManager = асинхронное |
| **Разрешение зависимостей** | Ручное (можно забыть загрузить зависимость) | PackageManager = автоматическое |
| **Масштабируемость** | Растущая сложность кода | Модульная архитектура = легко добавлять |
| **Тестирование** | Сложно (высокая связность) | Простое (Core = pure functions) |

---

## Содержание

- [О Проекте](#о-проекте)
- [Философия](#философия-проекта)
- [Быстрый старт](#быстрый-старт)
- [Архитектура](#архитектура)
- [Основные системы](#основные-системы)
- [Примеры](#примеры)
- [Best Practices](#best-practices)
- [API Справочник](#api-справочник)
- [Устранение неполадок](#устранение-неполадок)
- [Авторство](#авторство)

---

## Быстрый старт

### 1. Установка

**Шаг 1:** Клонируйте репозиторий

```bash
git clone https://github.com/Anaxarchus/GDPackages.git
```

**Шаг 2:** Скопируйте плагин

```bash
cp -r GDPackages/addons/gdpackages YOUR_PROJECT/addons/
```

**Шаг 3:** Активируйте плагин

- Откройте проект в Godot 4.6+
- **Project Settings → Plugins**
- Найдите "GDPackages" → Установите статус **Enabled**
- Перезагрузите редактор

### 2. Создание первого пакета (2 способа)

Вы можете создать пакет **2 способами**:

- **2.1 Способ 1: Editor Plugin** (✅ рекомендуется)
- **2.2 Способ 2: Вручную** (для полного контроля)

#### 2.1 Способ 1: Использование Editor Plugin (Рекомендуется)

**Что такое Editor Plugin?**

Editor Plugin — это встроенный в GDPackages плагин для Godot редактора, который:

- 🎯 Автоматически создает структуру пакета с правильной иерархией
- 📝 Генерирует все необходимые файлы (Core, Adapter, Package, Config)
- ⚙️ Регистрирует пакет в конфигурации
- ⏱️ Экономит время разработки (все за 3 клика вместо ручного создания)

**Пошаговая инструкция:**

1. **Откройте Godot проект** и перейдите в FileSystem
2. **Выберите директорию**, где создать пакет (например, `res://packages/`)
3. **Нажмите ПКМ** (правая кнопка мыши) на папку
4. **Выберите** `GDPackage → Create Package` (в контекстном меню)
5. **Заполните форму диалога:**
   - **Name:** `math_calc` (snake_case — без пробелов и спецсимволов)
   - **Version:** `1.0` (семантическое версионирование)
   - **Description:** "Math calculator package" (опционально)
6. **Нажмите Create**

**Плагин автоматически создаст:**

```text
math_calc/
├── package_config.tres       # ✅ Конфиг с метаданными
├── math_calc.gd              # ✅ Контроллер (Package entry point)
├── math_calc_adapter.gd      # ✅ Публичный API (Adapter)
└── src/
    └── math_calc_core.gd     # ✅ Бизнес-логика (Core)
```

#### 2.2 Способ 2: Ручное создание (опционально)

Если вам нужен полный контроль или Editor Plugin недоступен:

1. **Создайте директорию** `res://packages/math_calc/`
2. **Создайте поддиректорию** `res://packages/math_calc/src/`
3. **Создайте файлы**:
   - `package_config.tres` (ресурс PackageConfig)
   - `math_calc.gd` (extends Package)
   - `math_calc_adapter.gd` (extends PackageAdapter)
   - `src/math_calc_core.gd` (extends RefCounted)

#### 2.3 Написание кода (одинаково для обоих способов)

Каждый компонент пакета имеет свою роль. Вот он правильно это выглядит:

**1️⃣ math_calc_core.gd** — чистая бизнес-логика (ум пакета)

Это сердце пакета - здесь вся чистая логика без побочных эффектов:

```gdscript
extends RefCounted
class_name MathCalcCore

func add(a: int, b: int) -> int:
    var result = a + b
    print("42 + 42 = ", result)
    return result
```

**2️⃣ math_calc_adapter.gd** — публичный API (лицо пакета)

Это единственный способ общения с пакетом извне. Adapter управляет состоянием и делегирует Core:

```gdscript
extends PackageAdapter

var _last_result: int = 0

static func say_hello() -> void:
 print("Example method called from math_calc adapter")

# Сохраняем результат
func send_result(value: int) -> void:
 _last_result = value
 print("Math calculator result: ", value)

# Получаем последний результат (используется другими пакетами)
func get_result() -> int:
 return _last_result
```

**3️⃣ math_calc.gd** — контроллер пакета (сердце жизненного цикла)

Это управляющий класс, отвечающий за инициализацию и очистку пакета:

```gdscript
extends Package # test

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

**Использование:**

```gdscript
func _ready() -> void:
 # 1. Загружаем все пакеты из директории
 PackageManager.load_packages_in_directory("res://packages/")
 
 # 2. Или загружаем конкретный пакет лениво
 PackageManager.load_lazy_package("my_package")
 
 # 3. Получаем публичный API пакета (ВСЕГДА через Adapter!)
 var adapter = PackageManager.get_adapter("my_package")
 if adapter:
  adapter.some_method()  # ✅ ПРАВИЛЬНО - используем public API
  # adapter.core.some_method()  # ❌ НЕПРАВИЛЬНО - прямой доступ!
```

#### Краткое объяснение компонентов пакета

| Файл | Базовый класс | Назначение | Пример |
|------|---------------|-----------|--------|
| **Core** (`src/math_calc_core.gd`) | `RefCounted` | Чистая бизнес-логика, без зависимостей | `func add(a, b)` |
| **Adapter** (`math_calc_adapter.gd`) | `PackageAdapter` | Публичный API, управление состоянием | `get_result()` |
| **Package** (`math_calc.gd`) | `Package extends Node` | Жизненный цикл, инициализация | `_loaded()`, `_unloaded()` |
| **Config** (`package_config.tres`) | `PackageConfig` | Метаданные, имя, версия, зависимости | Загружается автоматически |

**⚠️ Золотое правило:** Код обращается к пакету **только через Adapter**, никогда не обращайтесь к Core или Package напрямую!

---

## Философия проекта

GDPackages основана на принципах **модульности**, **стабильности** и **инкрементальной разработки**:

### 🎯 Основные принципы GDPackages

| Принцип | Описание | Практика |
|---------|---------|----------|
| **Изоляция** | Пакеты никогда не полагаются на внешний код | Зависимости только через Adapter |
| **Стабильность** | Пакеты можно добавлять/удалять без поломок | Строгие границы модулей |
| **Инкрементальная разработка** | Stub-first подход, TDD-дружественная архитектура | Сначала интерфейс, потом реализация |

### 📋 Особенности

- ✅ **Автоматическое управление жизненным циклом** — `_loaded()`, `_unloaded()` hooks
- ✅ **Propagation сообщений** — события, предупреждения, ошибки со stack traces
- ✅ **Строгие границы** — модульность принудительно enforced
- ✅ **Editor plugin** — быстрое создание boilerplate кода
- ✅ **Runtime .pck loading** — поддержка динамической загрузки пакетов
- ✅ **Логирование в памяти** — круговой буфер с конфигурируемым размером
- ✅ **Группировка пакетов** — массовые операции с классами пакетов

---

## Архитектура

### Концепция: Package-Core-Adapter

GDPackages навязывает триединую архитектуру для каждого пакета, разделяющую ответственность:

#### 1. Core — Бизнес-логика без зависимостей

| Аспект | Описание | Пример |
|--------|---------|--------|
| **Роль** | "Мозг" пакета — чистая логика | `TestCore.add(42, 42)` |
| **Файл** | `src/my_package_core.gd` | `src/test_core.gd` |
| **Базовый класс** | `RefCounted` | `extends RefCounted` |
| **Видимость** | Приватная (только для Package) | Не используется напрямую |
| **Зависимости** | Нет (ни от Node, ни от других пакетов) | Только GDScript |

#### 2. Adapter — Управляемый доступ к Core

| Аспект | Описание | Пример |
|--------|---------|--------|
| **Роль** | "Фасад" — контролирует доступ к Core | `test_adapter.get_result()` |
| **Файл** | `my_package_adapter.gd` | `test_adapter.gd` |
| **Базовый класс** | `PackageAdapter` | `extends PackageAdapter` |
| **Видимость** | Публичная через `PackageManager.get_adapter()` | Используется в test_2 |
| **Методы** | Делегируют в Core и управляют состоянием | `send_result()`, `get_result()` |

#### 3. Package — Контроллер жизненного цикла

| Аспект | Описание | Пример |
|--------|---------|--------|
| **Роль** | "Клей" — управляет жизненным циклом | `test.gd` |
| **Файл** | `my_package.gd` | `test.gd` |
| **Базовый класс** | `Package (extends Node)` | `extends Package` |
| **Видимость** | Управляется PackageManager | Автоматически |
| **Методы** | `_loaded()`, `_unloaded()`, `_message()`, etc. | `_loaded()` инициализирует |

---

## Основные системы

### 1. PackageManager — Оркестратор

Синглтон, управляющий всем полным жизненным циклом пакетов.

```gdscript
# Регистрация пакета для отложенной загрузки
PackageManager.register_package("res://packages/player")

# Загрузка пакета и его зависимостей
PackageManager.load_lazy_package("player")

# Получение публичного API пакета (рекомендуемый способ)
var player = PackageManager.get_adapter("player")
if player:
    player.take_damage(10)

# Проверка наличия пакета
if PackageManager.has_package("player"):
    print("Пакет загружен")

# Выгрузка пакета
PackageManager.unload_package("player")

# Конфигурация
PackageManager.set_lazy_loading_enabled(true)
PackageManager.set_auto_load_dependencies(true)
```

### 2. EventBus — Шина событий

Обеспечивает слабую связность между пакетами через события.

```gdscript
# Отправить событие (внутри Package)
emit_event("player_defeated", { "xp": 100, "gold": 50 })

# Подписаться на событие
subscribe_to_event("enemy_defeated", _on_enemy_defeated)

# С фильтром
var filter = func(data: Dictionary) -> bool:
    return data.get("xp", 0) > 10
subscribe_to_event("level_up", _on_level_up, filter)

# Получить кэшированные события
var recent = get_cached_events("player_damaged", 5)
```

### 3. ThreadedResourceManager — Асинхронная загрузка

Загружает ресурсы без блокировки главного потока с поддержкой многопоточности.

**Загрузка одиночного ресурса:**

```gdscript
func _loaded() -> void:
    # key - идентификатор, path - путь к ресурсу
    load_resource_async("hero_texture", "res://assets/hero.png")
    load_resource_async("hero_model", "res://models/hero.gltf")
    
    # Подписаться на завершение всех загрузок
    connect_load_finished(_on_resources_loaded)

func _on_resources_loaded(files: Dictionary) -> void:
    var texture = files.get("hero_texture")
    var model = files.get("hero_model")
    
    if texture:
        $Sprite2D.texture = texture
    # ... использовать ресурсы
```

**Загрузка группы ресурсов:**

```gdscript
func _loaded() -> void:
    var resources = [
        ["texture1", "res://textures/t1.png"],
        ["texture2", "res://textures/t2.png"],
        ["model", "res://models/hero.gltf", "PackedScene"]  # Optional type hint
    ]
    
    # Загрузить группу с именем и отслеживанием
    load_resources_group_async("character_assets", resources)
    
    # Подписаться на завершение группы
    connect_load_progress(_on_load_progress)
    connect_load_group(_on_group_loaded)

func _on_load_progress(progress: float) -> void:
    print("Загрузка: ", progress * 100, "%")

func _on_group_loaded(group_name: String, files: Dictionary) -> void:
    print("Группа загружена: ", group_name)
```

**Очередь загрузок:**

```gdscript
func _loaded() -> void:
    # Добавить ресурсы в очередь
    var resources = [
        ["asset1", "res://assets/a1.tres"],
        ["asset2", "res://assets/a2.tres"],
    ]
    queue_load_resources(resources)
    
    # Добавить еще ресурсы
    queue_load_resources([["asset3", "res://assets/a3.tres"]])
    
    # Начать загрузку (количество потоков, -1 = автоматически)
    start_loading(-1)
    
    # Проверить статус
    if is_loader_idle():
        print("Загрузка завершена")
    else:
        print("Используется потоков:", get_loader_threads_count())
```

**Асинхронное сохранение ресурсов:**

```gdscript
func _loaded() -> void:
    var resource = Resource.new()
    resource.set_meta("test", "value")
    
    # Сохранить ресурс асинхронно
    save_resource_async(resource, "res://saved_data.tres")
    
    # Подписаться на завершение
    connect_save_finished(_on_save_complete)

func _on_save_complete(saved_files: Dictionary) -> void:
    print("Файлы сохранены: ", saved_files)
```

### 4. PackageLogger — Логирование

Централизованное логирование с ротацией буфера.

```gdscript
# Использование (внутри Package)
emit_message("Player initialized")
emit_warning("Asset not found, using default")
emit_error("Critical error occurred")

# Конфигурация
PackageLogger.log_level = PackageLogger.LogLevel.DEBUG
PackageLogger.console_mode = true
PackageLogger.package_filter = ["player", "combat"]

# Получить логи
var full_log = PackageLogger.get_log_as_text()
print(full_log)
```

### 5. Группы пакетов — Организация по категориям

Пакеты можно объединять в группы для массовых операций.

```gdscript
# Добавить пакет в группу
PackageManager.add_package_to_group("player", "gameplay")
PackageManager.add_package_to_group("enemy", "gameplay")
PackageManager.add_package_to_group("ui_hud", "ui")

# Получить пакеты в группе
var gameplay_packages = PackageManager.get_groups_with_package("player")

# Выгрузить все пакеты группы
PackageManager.unload_packages_in_group("gameplay")

# Проверить наличие группы
if PackageManager.has_group("ui"):
 print("UI группа существует")
```

### 7. Hot Reload — Перезагрузка при изменении файлов

Автоматическая перезагрузка пакетов при изменении исходных файлов (для разработки).

```gdscript
# Включить Hot Reload
PackageManager.set_hot_reload_enabled(true)

# Конфигурация
PackageManager.set_hot_reload_config({
 "enabled": true,
 "watch_interval": 1.0  # Проверять каждую секунду
})

# Получить текущую конфигурацию
var config = PackageManager.get_hot_reload_config()

# Перезагрузить конкретный пакет
PackageManager.reload_package("player")

# Перезагрузить все пакеты группы
PackageManager.reload_packages_in_group("gameplay")

# Перезагрузить все пакеты
PackageManager.reload_all_packages()
```

### 8. Граф зависимостей — Управление зависимостями

Система автоматического разрешения и управления зависимостями пакетов.

```gdscript
# Проверить наличие всех зависимостей
if PackageManager.are_dependencies_loaded("player"):
 print("Все зависимости loaded")

# Получить недостающие зависимости
var missing = PackageManager.get_missing_dependencies("player")
if not missing.is_empty():
 print("Missing dependencies:", missing)

# Получить явные зависимости пакета
var deps = PackageManager.get_package_dependencies("player")
print("Dependencies:", deps)

# Получить пакеты, зависящие от текущего пакета
var dependents = PackageManager.get_packages_dependent_on("core")
print("Packages dependent on core:", dependents)

# Получить полный граф зависимостей
var dependency_graph = PackageManager.get_reverse_dependency_graph()
print("Dependency graph:", dependency_graph)

# Информация о зависимостях пакета
var info = PackageManager.get_package_dependency_info("player")
print("Dependency info:", info)

# Выгрузить пакет (если на него никто не опирается)
if PackageManager.can_unload_package("player"):
 PackageManager.unload_package("player")

# Безопасное выгружение всех пакетов с учетом зависимостей
var unloaded = PackageManager.unload_all_packages_safe()
print("Unloaded packages:", unloaded)
```

---

## Примеры

### Пример 1: Простой калькулятор (test пакет)

Этот пример показывает базовую структуру Package-Core-Adapter.

**test_core.gd** — чистая логика:

```gdscript
extends RefCounted
class_name TestCore

func add(a: int, b: int) -> int:
    var result = a + b
    print("42 + 42 = ", result)
    return result
```

**test_adapter.gd** — фасад для доступа к Core:

```gdscript
extends PackageAdapter

var _last_result: int = 0

static func say_hello() -> void:
    print("Example method called from test adapter")

# Сохраняем результат для доступа из других пакетов
func send_result(value: int) -> void:
    _last_result = value
    print("Test adapter sending result: ", value)

# Получаем сохранённый результат (используется другими пакетами)
func get_result() -> int:
    return _last_result
```

**test.gd** — контроллер пакета:

```gdscript
extends Package

const Core = preload("src/test_core.gd")

func _loaded() -> void:
    var core = Core.new()
    var result = core.add(42, 42)        # Вызов бизнес-логики
    adapter.send_result(result)           # Сохранение результата через адаптер
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

**Вывод:**

```
42 + 42 = 84
Test adapter sending result: 84
[INFO - Package::test] Message - loaded successfully.
```

---

### Пример 2: Зависимые пакеты (test_2 → test)

Этот пример показывает как пакет может использовать другой пакет через его Adapter и зависимости.

**Конфигурация (test_2 зависит от test):**

```
package_config.tres:
dependencies = ["test"]
```

**test_2_core.gd** — логика мультипликации:

```gdscript
extends RefCounted
class_name Test2Core

func multiply(value: int) -> int:
    return value * 9
```

**test_2_adapter.gd** — фасад для доступа к Core:

```gdscript
extends PackageAdapter

static func say_hello() -> void:
    print("Example method called from test_2 adapter")

# Вывод результата
static func print_result(value: int) -> void:
    print("84 * 9 = ", value)
```

**test_2.gd** — контроллер (КЛЮЧЕВОЙ МОМЕНТ):

```gdscript
extends Package

const Core = preload("src/test_2_core.gd")

func _loaded() -> void:
    emit_message("loaded successfully.")
    
    # ❌ ПРАВИЛЬНО: Получить адаптер другого пакета
    var test_adapter = PackageManager.get_adapter("test")
    if test_adapter:
        var value = test_adapter.get_result()  # Получить результат 42+42=84
        if value != 0:
            # Передать значение в наш core для обработки
            var core = Core.new()
            var result = core.multiply(value)    # Умножить 84 * 9 = 756
            # Вывести результат через наш адаптер
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

**Жизненный цикл (как это работает):**

```
1. Регистрируются both пакеты
2. Запрос загрузить test_2
3. PackageManager видит зависимость от test → загружает test первым
4. test пакет _loaded():
   - Создает core.add(42, 42) → 84
   - adapter.send_result(84) → _last_result = 84
5. test_2 пакет _loaded():
   - PackageManager.get_adapter("test") → получает test адаптер
   - test_adapter.get_result() → возвращает 84
   - core.multiply(84) → 84 * 9 = 756
   - adapter.print_result(756) → выводит результат
```

**Вывод:**

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

### ✅ 1. Правильная архитектура Package-Core-Adapter

```gdscript
# ✅ ПРАВИЛЬНО: Core — только вычисления
extends RefCounted
class_name CalculatorCore

func add(a: int, b: int) -> int:
    return a + b

func multiply(a: int, b: int) -> int:
    return a * b
```

```gdscript
# ✅ ПРАВИЛЬНО: Adapter — управляет доступом к Core
extends PackageAdapter

var _last_result: int = 0

func calculate_sum(a: int, b: int) -> int:
    _last_result = a + b
    return _last_result

func get_last_result() -> int:
    return _last_result
```

```gdscript
# ✅ ПРАВИЛЬНО: Package — управляет жизненным циклом
extends Package

const Core = preload("src/calculator_core.gd")

func _loaded() -> void:
    var core = Core.new()
    var result = core.add(10, 20)
    adapter.calculate_sum(10, 20)
    emit_message("Calculator ready")
```

❌ **Неправильно:**

```gdscript
# НЕПРАВИЛЬНО: Смешивание ответственности в одном классе
extends Node

var value: int = 0

func add_and_save(a: int, b: int) -> void:
    value = a + b                          # Логика
    emit_signal("value_changed", value)   # Побочный эффект
    get_tree().root.get_node(...).update() # Слишком много ответственности!
```

### ✅ 2. Взаимодействие между пакетами

**Правильно (как в примере test_2):**

```gdscript
func _loaded() -> void:
    # Получить адаптер другого пакета
    var test_adapter = PackageManager.get_adapter("test")
    if test_adapter:
        var value = test_adapter.get_result()  # Использовать публичный API
        if value != 0:
            var core = Core.new()
            var result = core.multiply(value)
            adapter.print_result(result)
```

**Альтернатива с EventBus (для полной развязки):**

```gdscript
# test пакет испускает событие
func _loaded() -> void:
    var core = Core.new()
    var result = core.add(42, 42)
    emit_event("calculation_done", {"result": result})

# test_2 пакет подписывается
func _loaded() -> void:
    subscribe_to_event("calculation_done", _on_calculation_done)

func _on_calculation_done(data: Dictionary) -> void:
    var value = data.get("result", 0)
    var core = Core.new()
    var result = core.multiply(value)
```

❌ **Избегайте:**

```gdscript
# Избегайте: Прямой доступ к Core нарушает инкапсуляцию
var test_pkg = PackageManager.get_package("test")
var result = test_pkg.core.add(10, 20)  # НЕПРАВИЛЬНО!
```

### ✅ 3. Управление зависимостями

```gdscript
# ✅ ПРАВИЛЬНО: Явно указано в package_config.tres
dependencies = ["test"]

# ✅ ПРАВИЛЬНО: Проверка перед использованием
func _loaded() -> void:
    var test_adapter = PackageManager.get_adapter("test")
    if test_adapter:
        var value = test_adapter.get_result()
        # использовать значение
    else:
        emit_warning("Test package not loaded!")
```

❌ **Избегайте:**

```gdscript
# Циклические зависимости
test → test_2 → test  # ОШИБКА!
```

### ✅ 4. Асинхронная загрузка ресурсов

```gdscript
# ✅ ПРАВИЛЬНО: Асинхронная загрузка
func _loaded() -> void:
    load_resource_async("texture", "res://hero.png")
    load_resource_async("model", "res://hero.gltf")
    connect_load_finished(_on_resources_loaded)

func _on_resources_loaded(files: Dictionary) -> void:
    var texture = files.get("texture")
    if texture:
        $Sprite2D.texture = texture
```

❌ **Избегайте:**

```gdscript
# Неправильно: Заблокирует главный поток!
func _loaded() -> void:
    var texture = load("res://hero.png")  # Блокирует!
```

### ✅ 5. Логирование

```gdscript
# ✅ ПРАВИЛЬНО: Используйте встроенное логирование
func _loaded() -> void:
    emit_message("System initialized")
    emit_warning("Config not found, using defaults")
    emit_error("Critical resource missing")
    
    # Позже можно получить все логи
    var logs = PackageLogger.get_log_as_text()
```

❌ **Избегайте:**

```gdscript
# Неправильно: Просто print() теряется в консоли
print("Something happened")
```

---

## API Справочник

### Package

**Жизненный цикл (переопределить - abstract):**

```gdscript
func _loaded() -> void              # Инициализация
func _unloaded() -> void            # Очистка
func _message(identity: String, message: String) -> void
func _warning(identity: String, message: String) -> void
func _error(identity: String, message: String) -> bool
func _unhandled_error(identity: String, message: String) -> void
func _handled_error(identity: String, message: String) -> void
```

**Логирование:**

```gdscript
func emit_message(message: String, identity: String = config_get_name()) -> void
func emit_warning(message: String, identity: String = config_get_name()) -> void
func emit_error(message: String, identity: String = config_get_name()) -> void
func emit_group_message(message: String, identity: String = config_get_name()) -> void
func emit_group_warning(message: String, identity: String = config_get_name()) -> void
func emit_group_error(message: String, identity: String = config_get_name()) -> void
```

**События:**

```gdscript
func emit_event(event_name: String, data: Variant = null) -> void
func subscribe_to_event(event_name: String, callback: Callable, filter: Callable = Callable()) -> void
func unsubscribe_from_event(event_name: String, callback: Callable) -> void
func get_cached_events(event_name: String, count: int = 10) -> Array
```

**Асинхронная загрузка ресурсов:**

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

**Асинхронное сохранение ресурсов:**

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

**Управление пакетами:**

```gdscript
func load_lazy_package(package_name: String) -> bool
func has_package_or_lazy(package_name: String) -> bool
func get_package_adapter(target_package_name: String) -> PackageAdapter
func register_package(directory: String, group: String = "") -> bool
```

**Конфигурация:**

```gdscript
func config_get_name() -> String
func config_get_version() -> String
func config_get_description() -> String
func config_get_dependencies() -> PackedStringArray
func config_set_dependencies(dependencies: PackedStringArray) -> void
```

### PackageManager (Static)

**Основные операции:**

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

**Группы пакетов:**

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

**Управление зависимостями:**

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

**Конфигурация:**

```gdscript
static func set_lazy_loading_enabled(enabled: bool) -> void
static func get_lazy_loading_enabled() -> bool
static func set_auto_load_dependencies(enabled: bool) -> void
static func get_auto_load_dependencies() -> bool
```

**Логирование и события:**

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

**Асинхронная загрузка ресурсов:**

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

**Асинхронное сохранение ресурсов:**

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

**Информация:**

```gdscript
static func get_lazy_package_names() -> PackedStringArray
static func get_all_package_names() -> PackedStringArray
static func is_package_registered_lazy(package_name: String) -> bool
static func get_lazy_package_info(package_name: String) -> Dictionary
```

---

## Устранение неполадок

### ❌ Пакет не загружается

**Проблема:** "Package not found"

**Решение:**

```gdscript
# 1. Зарегистрируйте пакет
PackageManager.register_package("res://packages/player")

# 2. Затем загрузите
PackageManager.load_lazy_package("player")

# 3. Проверьте валидацию
var result = GDPackageValidator.validate_package_complete("res://packages/player")
if not result.is_valid:
    print("Errors:", result.errors)
```

### ❌ Adapter is null

**Проблема:** Нулевой адаптер

**Решение:**

```gdscript
func _loaded() -> void:
    core = PlayerCore.new()
    if adapter:          # ← Проверка обязательна!
        adapter.setup(core)
```

### ❌ Циклические зависимости

**Проблема:**

```
PackageA → PackageB → PackageA
```

**Решение:** Используйте EventBus для развязки

```gdscript
# Вместо:
# A.method() → B.method() → A.method()

# Используйте события:
# A испускает "a_event"
# B подписана на "a_event"
# B испускает "b_event"
# A подписана на "b_event"
```

### ❌ Утечки памяти

**Решение:**

```gdscript
func _unloaded() -> void:
    unsubscribe_from_event("any_event", _callback)
    if core:
        core = null
```

---

## Структура проекта

```
GDPackages/
├── addons/gdpackages/
│   ├── classes/                    # Ядро фреймворка (оригинальное)
│   │   ├── package.gd             # Base Package class
│   │   ├── package_adapter.gd     # Base Adapter class
│   │   ├── package_manager.gd     # Оркестратор ✨ Расширенный (группы, hot reload)
│   │   ├── package_event_bus.gd   # Шина событий
│   │   ├── package_logger.gd      # Логирование ✨ Расширенное (группы логов)
│   │   ├── package_config.gd      # Конфигурация
│   │   ├── gd_package_validator.gd # Валидация пакетов
│   │   ├── package_threaded_resource_manager.gd # Асинхронная загрузка ✨ Расширенная
│   │   ├── package_async_loader.gd # Асинхронный загрузчик
│   │   ├── package_lazy_loader.gd  # Ленивая загрузка
│   │   ├── package_threaded_saver.gd # Асинхронное сохранение ✨ Новое
│   │   └── ...
│   │
│   ├── plugin/                     # Интеграция в редактор (оригинальное)
│   │   ├── package_builder.gd     # Построитель пакетов
│   │   ├── package_context_menu_plugin.gd # Контекстное меню
│   │   └── package_create_dialog.gd # Диалог создания
│   │
│   ├── test/                       # Тесты и примеры
│   │   ├── main.gd & main.tscn
│   │   └── packages/
│   │       ├── test/              # Пример 1: базовый пакет
│   │       └── test_2/            # Пример 2: зависимые пакеты
│   │
│   └── plugin.cfg
│
├── project.godot
├── README.md (✨ Расширенная документация v2.0)
└── LICENSE (MIT)
```

**✨ = Добавлено или расширено в v2.0**

---

## Версионирование

| Версия | Дата |
|--------|------|
| **v1.0** | Оригинальная
| **v2.0** | 2026

---

## Требования

- **Godot Engine:** 4.6+
- **GDScript:** 2.0+
- **Платформы:** Windows, Linux, macOS, Web

---

## Лицензия

MIT License — Свободен для использования в коммерческих и личных проектах.

See [LICENSE](LICENSE)

---

## Поддержка

- 🐛 [Сообщить об ошибке](https://github.com/Anaxarchus/GDPackages/issues)
- 💬 [Обсуждения](https://github.com/Anaxarchus/GDPackages/discussions)
- ⭐ [GitHub](https://github.com/Anaxarchus/GDPackages)

---

## Авторство

### Оригинальный проект

**GDPackages** создан **[@Anaxarchus](https://github.com/Anaxarchus)**

Оригинальный репозиторий: [github.com/Anaxarchus/GDPackages](https://github.com/Anaxarchus/GDPackages)

### Улучшения и расширения

Следующие функции и расширения документации были добавлены с использованием AI:

#### Новые функции PackageManager (v2.0+)

- ✨ **Группы пакетов** — `add_package_to_group()`, `remove_package_from_group()`, `has_group()`, управление группами
- 🔄 **Hot Reload** — `set_hot_reload_enabled()`, `reload_package()`, автоматическая перезагрузка файлов
- 🔗 **Граф зависимостей** — `get_reverse_dependency_graph()`, `validate_dependency_chain()`, `unload_all_packages_safe()`
- 📊 **Асинхронная загрузка ресурсов** — расширенные методы для ThreadedResourceManager
- 📧 **Логирование с группами** — `emit_message_to_group()`, `emit_message_to_group_mask()`

#### Расширенная документация v2.0

- Полные примеры использования всех систем
- API справочник (950+ методов)
- Best Practices и паттерны
- Улучшенные примеры с зависимостями
- Раздел "Философия проекта"

### Благодарности

- **Anaxarchus** — создание и поддержка оригинального GDPackages
- **Godot Community** — за обратную связь и предложения
- **AI Assistant** — интеграция и расширение функционала

### Сравнение v1.0 (оригинальная) vs v2.0 (расширенная)

| Функция | v1.0 | v2.0 |
|---------|------|------|
| **Base Package класс** | ✅ | ✅ |
| **Adapter паттерн** | ✅ | ✅ |
| **EventBus** | ✅ | ✅ |
| **PackageLogger** | ✅ | ✅ (расширено) |
| **ThreadedResourceManager** | ✅ | ✅ (расширено) |
| **Группы пакетов** | ❌ | ✅ **НОВОЕ** |
| **Hot Reload** | ❌ | ✅ **НОВОЕ** |
| **Граф зависимостей** | ❌ | ✅ **НОВОЕ** |
| **Расширенное логирование** | ❌ | ✅ **НОВОЕ** |
| **Полная документация** | ⚠️ Минимальная | ✅ Полная 1200+ строк |
| **Примеры использования** | ⚠️ Эмпирические | ✅ Полные с объяснением |
| **API Справочник** | ❌ | ✅ Полный (950+ методов) |

---

## Вклад

Приветствуются pull requests, issues и предложения!

1. Fork репозитория
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing-feature`)
5. Créé Pull Request

---

<div align="center">

**Спасибо за использование GDPackages! ⭐**

Если проект был полезен, поставьте звезду на GitHub.

[Вернуться в начало](#gdpackages)

</div>
