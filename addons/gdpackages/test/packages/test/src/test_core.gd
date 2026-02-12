extends RefCounted

class_name TestCore

func add(a: int, b: int) -> int:
	var result = a + b
	print("42 + 42 = ", result)
	return result
