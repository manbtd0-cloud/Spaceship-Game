extends "res://tests/support/test_case.gd"

const SCENE_PATH := "res://scenes/debug/thruster_calibration.tscn"
const EXPECTED_CASES := PackedStringArray([
    "forward",
    "reverse",
    "strafe_left",
    "strafe_right",
    "strafe_up",
    "strafe_down",
    "pitch_up",
    "pitch_down",
    "yaw_left",
    "yaw_right",
    "roll_left",
    "roll_right",
    "assist_translation",
    "assist_rotation",
])

func run() -> void:
    var packed := load(SCENE_PATH) as PackedScene
    assert_true(packed != null, "thruster calibration scene must load")
    if packed == null:
        return

    var calibration := packed.instantiate()
    assert_true(calibration != null, "thruster calibration scene must instantiate")
    if calibration == null:
        return

    assert_true(
        calibration.get_node_or_null("PlayerInterceptor") != null,
        "calibration scene must use the production player interceptor"
    )
    assert_true(
        calibration.get_node_or_null("UI/Panel/Margin/VBox/CaseLabel") is Label,
        "calibration scene must contain an action selector label"
    )
    assert_true(
        calibration.get_node_or_null("UI/Panel/Margin/VBox/ReportLabel") is Label,
        "calibration scene must contain a deterministic report label"
    )
    assert_equal(
        calibration.get_case_names(),
        EXPECTED_CASES,
        "calibration scene must expose twelve pilot and two assisted cases"
    )
    assert_equal(
        calibration.get_action_matrix_path(),
        ShipThrusterVisualController.ACTION_MATRIX_PATH,
        "calibration must use the production checked-in action matrix"
    )

    calibration.free()
