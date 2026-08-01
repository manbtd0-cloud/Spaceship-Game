class_name TestCase
extends RefCounted

var failures: Array[String] = []

func assert_true(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
    if actual != expected:
        failures.append("%s | expected=%s actual=%s" % [message, expected, actual])
