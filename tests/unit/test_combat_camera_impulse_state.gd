extends "res://tests/support/test_case.gd"

func run() -> void:
    var state := CombatCameraImpulseState.new()

    var light := DamageResult.new()
    light.applied_amount = 15.0
    light.applied_to_shield = 15.0
    light.kind = DamagePacket.Kind.PROJECTILE
    state.request_player_damage(light)
    var light_strength := state.get_strength()
    assert_true(light_strength > 0.0, "light player shield hit produces a restrained impulse")
    assert_true(light_strength < 0.30, "ordinary projectile hit stays subtle")

    state.reset()
    var collision := DamageResult.new()
    collision.applied_amount = 60.0
    collision.applied_to_shield = 60.0
    collision.kind = DamagePacket.Kind.COLLISION
    state.request_player_damage(collision)
    var collision_strength := state.get_strength()
    assert_true(collision_strength > light_strength, "meaningful collision is stronger than a normal pulse hit")

    state.reset()
    state.request_shield_break()
    assert_true(state.get_strength() > light_strength, "shield break is stronger than an ordinary hit")

    state.reset()
    state.request_explosion(120.0)
    var nearby := state.get_strength()
    state.reset()
    state.request_explosion(620.0)
    var distant := state.get_strength()
    state.reset()
    state.request_explosion(900.0)
    assert_true(nearby > distant, "nearby destruction produces more camera energy than distant destruction")
    assert_true(distant > 0.0, "mid-distance destruction remains faintly readable")
    assert_true(is_zero_approx(state.get_strength()), "far destruction produces no camera impulse")

    state.reset()
    state.request_shield_break()
    state.advance(1.0 / 60.0)
    var translation := state.get_translation_offset()
    var rotation := state.get_rotation_offset_degrees()
    assert_true(translation.is_finite() and rotation.is_finite(), "camera impulse output remains finite")
    assert_true(translation.length() <= CombatCameraImpulseState.MAX_TRANSLATION_METERS + 0.0001, "translation stays inside presentation-only bound")
    assert_true(rotation.length() <= CombatCameraImpulseState.MAX_ROTATION_DEGREES + 0.0001, "rotation stays inside presentation-only bound")
    state.advance(2.0)
    assert_true(is_zero_approx(state.get_strength()), "camera impulse fully decays")
    assert_true(state.get_translation_offset().is_zero_approx(), "decayed impulse leaves no positional drift")
    assert_true(state.get_rotation_offset_degrees().is_zero_approx(), "decayed impulse leaves no rotational drift")
