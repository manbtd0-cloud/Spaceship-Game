extends "res://tests/support/test_case.gd"

const TEST_RUNNER_PATH := "res://tests/test_runner.gd"

func run() -> void:
    assert_equal(2 + 2, 4, "test harness must compare values")
    assert_true(true, "test harness must accept true conditions")

    var runner_file := FileAccess.open(TEST_RUNNER_PATH, FileAccess.READ)
    assert_true(runner_file != null, "test runner source must be readable")
    if runner_file == null:
        return

    var source := runner_file.get_as_text()
    assert_true(
        source.contains("call_deferred(&\"_run_tests\")"),
        "test runner must defer suites until the SceneTree root is active"
    )
    assert_true(
        source.contains("func _run_tests() -> void:"),
        "test runner must execute suites from a deferred callback"
    )
    assert_true(
        source.contains("Node.get_orphan_node_ids()"),
        "test runner must detect orphan Nodes created by a suite"
    )
    assert_true(
        source.contains("leaked orphan node"),
        "test runner must report orphan Nodes as suite failures"
    )
