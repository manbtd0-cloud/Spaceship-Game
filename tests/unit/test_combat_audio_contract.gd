extends "res://tests/support/test_case.gd"

const CombatAudioSynth = preload("res://src/combat/combat_audio_synth.gd")

func run() -> void:
    for bus_name: StringName in [&"Master", &"Ship", &"Weapons", &"Impacts", &"Environment"]:
        assert_true(
            AudioServer.get_bus_index(bus_name) >= 0,
            "combat audio bus exists: %s" % bus_name
        )

    var streams := CombatAudioSynth.build_streams()
    for key: StringName in [
        &"pulse",
        &"shield_hit",
        &"shield_break",
        &"hull_hit",
        &"thruster",
        &"explosion",
        &"debris",
    ]:
        var stream := streams.get(key) as AudioStreamWAV
        assert_true(stream != null, "deterministic combat stream exists: %s" % key)
        if stream != null:
            assert_true(stream.data.size() > 2000, "combat stream contains PCM source data: %s" % key)
            assert_equal(stream.mix_rate, 44100, "combat stream uses stable 44.1 kHz rate")

    _assert_preload_contract(
        "res://src/combat/hull_impact_visualizer.gd",
        "const HullImpactMath = preload(\"res://src/combat/hull_impact_math.gd\")"
    )
    _assert_preload_contract(
        "res://src/combat/enemy_thruster_visual_controller.gd",
        "const EnemyThrusterPresentationMath = preload(\"res://src/combat/enemy_thruster_presentation_math.gd\")"
    )
    _assert_preload_contract(
        "res://src/combat/enemy_destruction_presentation_controller.gd",
        "const EnemyDestructionTimeline = preload(\"res://src/combat/enemy_destruction_timeline.gd\")"
    )
    _assert_preload_contract(
        "res://src/combat/enemy_destruction_presentation_controller.gd",
        "const EnemyThrusterVisualController = preload(\"res://src/combat/enemy_thruster_visual_controller.gd\")"
    )
    _assert_preload_contract(
        "res://src/combat/combat_audio_controller.gd",
        "const CombatAudioSynth = preload(\"res://src/combat/combat_audio_synth.gd\")"
    )
    _assert_preload_contract(
        "res://src/combat/combat_audio_controller.gd",
        "const EnemyThrusterVisualController = preload(\"res://src/combat/enemy_thruster_visual_controller.gd\")"
    )
    _assert_preload_contract(
        "res://src/camera/combat_camera_feedback_controller.gd",
        "const CombatCameraImpulseState = preload(\"res://src/camera/combat_camera_impulse_state.gd\")"
    )

func _assert_preload_contract(path: String, expected: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    assert_true(file != null, "presentation dependency source exists: %s" % path)
    if file == null:
        return
    var source := file.get_as_text()
    assert_true(
        source.contains(expected),
        "presentation dependency is explicit for stale class cache: %s" % path
    )
