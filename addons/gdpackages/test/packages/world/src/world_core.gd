extends RefCounted

class_name WorldCore

var counter: int = 0

func example_method() -> void:
	print("Example method called from world core")

func increment_counter() -> int:
	counter += 1
	print("World counter incremented: ", counter)
	return counter

func get_counter() -> int:
	return counter

func reset_counter() -> void:
	counter = 0

func generate_greeting(name: String) -> String:
	return "World says: Hello to " + name + "!"
