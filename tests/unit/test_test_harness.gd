extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(2 + 2, 4, "test harness must compare values")
    assert_true(true, "test harness must accept true conditions")
