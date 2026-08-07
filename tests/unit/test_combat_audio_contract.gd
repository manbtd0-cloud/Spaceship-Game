extends "res://tests/support/test_case.gd"

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
