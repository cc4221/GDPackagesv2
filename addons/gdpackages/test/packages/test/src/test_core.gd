extends RefCounted

class_name TestCore

func add(a: int, b: int) -> int:
	# ИСПРАВЛЕНО: Добавлен тип возвращаемого значения для переменной
	var result: int = a + b
	print("42 + 42 = ", result)
	return result
