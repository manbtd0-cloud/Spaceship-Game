extends SceneTree

const PLAYER_SCENE_PATH := "res://scenes/player/player_interceptor.tscn"
const INITIAL_VELOCITY := Vector3(70.0, 20.0, -110.0)
const PHYSICS_FRAME_COUNT := 120
const MAX_SPEED_DRIFT_MPS := 0.01
const MAX_DIRECTION_DRIFT_DEGREES := 0.01
const FORCE_TOLERANCE := 0.001

func _initialize() -> void:
    call_deferred(&"_run_test")

func _run_test() -> void:
    var failures: Array[String] = []
    var packed := load(PLAYER_SCENE_PATH) as PackedScene
    if packed == null:
        printerr("inertial velocity test: player scene must load")
        quit(1)
        return

    var body := packed.instantiate() as RigidBody3D
    if body == null:
        printerr("inertial velocity test: player scene must instantiate as RigidBody3D")
        quit(1)
        return

    root.add_child(body)
    await physics_frame

    var controller := body.get_node_or_null(
        "ShipFlightController"
    ) as ShipFlightController
    if controller == null:
        failures.append("player must expose ShipFlightController")
    elif not controller.set_flight_mode(FlightMode.Value.MANUAL):
        failures.append("controller must enter Inertial mode")

    var initial_basis := body.global_transform.basis.orthonormalized()
    body.linear_velocity = INITIAL_VELOCITY
    body.angular_velocity = Vector3.ZERO

    Input.action_press(&"pitch_up")
    for _frame: int in range(PHYSICS_FRAME_COUNT):
        await physics_frame
    Input.action_release(&"pitch_up")

    var final_velocity := body.linear_velocity
    var final_basis := body.global_transform.basis.orthonormalized()
    var orientation_change_degrees := rad_to_deg(
        initial_basis.get_rotation_quaternion().angle_to(
            final_basis.get_rotation_quaternion()
        )
    )
    var speed_drift := absf(
        final_velocity.length() - INITIAL_VELOCITY.length()
    )
    var direction_drift_degrees := rad_to_deg(
        INITIAL_VELOCITY.normalized().angle_to(
            final_velocity.normalized()
        )
    )

    if orientation_change_degrees <= 1.0:
        failures.append(
            "orientation must visibly change under sustained pitch torque; change=%.6f degrees"
            % orientation_change_degrees
        )
    if body.angular_velocity.length() <= 0.001:
        failures.append("angular velocity must change under sustained pitch torque")
    if speed_drift > MAX_SPEED_DRIFT_MPS:
        failures.append(
            "pure rotation must preserve speed; drift=%.9f m/s"
            % speed_drift
        )
    if direction_drift_degrees > MAX_DIRECTION_DRIFT_DEGREES:
        failures.append(
            "pure rotation must preserve world velocity direction; drift=%.9f degrees"
            % direction_drift_degrees
        )
    if (
        controller != null
        and controller.get_last_assist_force_local().length()
        > FORCE_TOLERANCE
    ):
        failures.append(
            "Inertial rotation must report zero assist force; force=%s"
            % controller.get_last_assist_force_local()
        )

    Input.action_release(&"pitch_up")
    root.remove_child(body)
    body.free()

    if not failures.is_empty():
        for failure: String in failures:
            printerr("inertial velocity test: %s" % failure)
        printerr("FAIL: inertial rigid-body velocity preservation")
        quit(1)
        return

    print(
        "PASS: inertial rigid-body velocity preservation "
        + "(speed drift %.9f m/s, direction drift %.9f degrees)"
        % [speed_drift, direction_drift_degrees]
    )
    quit(0)
