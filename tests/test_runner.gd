extends SceneTree

const TEST_SCRIPTS: Array[String] = [
    "res://tests/unit/test_test_harness.gd",
    "res://tests/unit/test_flight_model.gd",
]

func _initialize() -> void:
    var failure_count: int = 0

    for script_path: String in TEST_SCRIPTS:
        var suite_script: Script = load(script_path)
        if suite_script == null:
            failure_count += 1
            printerr("%s: failed to load test suite" % script_path)
            continue

        var suite: TestCase = suite_script.new()
        suite.run()

        for failure: String in suite.failures:
            failure_count += 1
            printerr("%s: %s" % [script_path, failure])

    if failure_count == 0:
        print("PASS: %d suites" % TEST_SCRIPTS.size())
        quit(0)
        return

    printerr("FAIL: %d assertions or suites" % failure_count)
    quit(1)
