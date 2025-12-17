extends RefCounted

class_name HelloCore

var counter: int = 0

func example_method() -> void:
	print("Example method called from hello core")

func increment_counter() -> int:
	counter += 1
	print("Hello counter incremented: ", counter)
	return counter

func get_counter() -> int:
	return counter

func reset_counter() -> void:
	counter = 0