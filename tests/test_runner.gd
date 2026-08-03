extends SceneTree

const TEST_SCRIPTS: Array[String] = [
    "res://tests/unit/test_test_harness.gd",
    "res://tests/unit/test_flight_model.gd",
    "res://tests/unit/test_flight_speed_envelope.gd",
    "res://tests/unit/test_boost_thermal_state.gd",
    "res://tests/unit/test_flight_steering_math.gd",
    "res://tests/unit/test_coordinated_turn_state.gd",
    "res://tests/unit/test_player_input_math.gd",
    "res://tests/unit/test_primary_fire_cadence.gd",
    "res://tests/unit/test_damage_state.gd",
    "res://tests/integration/test_input_map.gd",
    "res://tests/integration/test_primary_fire_input.gd",
    "res://tests/integration/test_pulse_projectile.gd",
    "res://tests/unit/test_ship_flight_state.gd",
    "res://tests/unit/test_ship_flight_controller_state.gd",
    "res://tests/unit/test_thruster_action_matrix.gd",
    "res://tests/unit/test_thruster_visual_math.gd",
    "res://tests/unit/test_asteroid_field_layout.gd",
    "res://tests/integration/test_player_scene.gd",
    "res://tests/unit/test_chase_camera_math.gd",
    "res://tests/integration/test_chase_camera_rig.gd",
    "res://tests/integration/test_flight_room_scene.gd",
    "res://tests/integration/test_hero_ship_asset.gd",
    "res://tests/integration/test_ship_thruster_visual_controller.gd",
    "res://tests/integration/test_thruster_calibration_scene.gd",
    "res://tests/integration/test_asteroid_body_scene.gd",
    "res://tests/integration/test_asteroid_field.gd",
]

func _initialize() -> void:
    call_deferred(&"_run_tests")

func _run_tests() -> void:
    var failure_count: int = 0

    for script_path: String in TEST_SCRIPTS:
        var orphan_ids_before := _orphan_id_set()
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

        suite = null
        failure_count += _report_and_free_new_orphans(
            script_path,
            orphan_ids_before
        )

    if failure_count == 0:
        print("PASS: %d suites" % TEST_SCRIPTS.size())
        quit(0)
        return

    printerr("FAIL: %d assertions or suites" % failure_count)
    quit(1)

func _orphan_id_set() -> Dictionary:
    var result: Dictionary = {}
    for orphan_id: int in Node.get_orphan_node_ids():
        result[orphan_id] = true
    return result

func _report_and_free_new_orphans(
    script_path: String,
    orphan_ids_before: Dictionary
) -> int:
    var leak_count := 0
    for orphan_id: int in Node.get_orphan_node_ids():
        if orphan_ids_before.has(orphan_id):
            continue

        leak_count += 1
        var orphan := instance_from_id(orphan_id) as Node
        var description := "id=%d" % orphan_id
        if orphan != null:
            description = "%s (%s, id=%d)" % [
                orphan.name,
                orphan.get_class(),
                orphan_id,
            ]
        printerr(
            "%s: leaked orphan node %s"
            % [script_path, description]
        )
        if orphan != null:
            orphan.free()
    return leak_count
