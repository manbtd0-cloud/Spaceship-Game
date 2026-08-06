extends "res://tests/support/test_case.gd"

var _owned_states: Array[DamageState] = []

func run() -> void:
    _test_shield_absorption_and_hull_overflow()
    _test_break_and_destroy_signals_emit_once()
    _test_normal_shield_regeneration_delay_and_rate()
    _test_zero_shield_reboot_and_damage_timer_reset()
    _test_player_hull_repair_requires_full_shield_delay()
    _test_drone_never_repairs_hull()
    _test_destroyed_state_does_not_recover()
    _test_disabled_and_zero_damage_are_inert()
    _test_reset_restores_full_enabled_state()
    _test_runtime_auto_advance()
    _free_owned_states()

func _test_shield_absorption_and_hull_overflow() -> void:
    var state := _make_state(true)
    var first := state.apply_damage(_packet(50.0))
    assert_true(is_equal_approx(state.get_shield(), 100.0), "shield absorbs initial damage")
    assert_true(is_equal_approx(state.get_hull(), 200.0), "hull remains full behind shield")
    assert_true(is_equal_approx(first.applied_to_shield, 50.0), "result records shield application")
    assert_true(is_equal_approx(first.applied_to_hull, 0.0), "result records zero hull application")

    state.reset_full()
    state.apply_damage(_packet(130.0))
    var overflow := state.apply_damage(_packet(50.0))
    assert_true(is_equal_approx(state.get_shield(), 0.0), "overflow depletes remaining shield")
    assert_true(is_equal_approx(state.get_hull(), 170.0), "overflow carries exactly into hull")
    assert_true(is_equal_approx(overflow.applied_to_shield, 20.0), "overflow result records shield portion")
    assert_true(is_equal_approx(overflow.applied_to_hull, 30.0), "overflow result records hull portion")
    assert_true(overflow.shield_broken, "positive-to-zero shield transition is reported")
    assert_true(overflow.hull_damaged, "overflow reports hull damage")

func _test_break_and_destroy_signals_emit_once() -> void:
    var state := _make_state(true)
    var break_count := [0]
    var destroy_count := [0]
    state.shield_broken.connect(func(_result: DamageResult) -> void: break_count[0] += 1)
    state.destroyed.connect(func(_result: DamageResult) -> void: destroy_count[0] += 1)

    var lethal := state.apply_damage(_packet(350.0))
    assert_true(lethal.shield_broken, "lethal packet reports one shield break")
    assert_true(lethal.destroyed, "lethal packet reports destruction")
    state.apply_damage(_packet(10.0))
    assert_equal(break_count[0], 1, "shield break signal emits once")
    assert_equal(destroy_count[0], 1, "destroyed signal emits once")

func _test_normal_shield_regeneration_delay_and_rate() -> void:
    var state := _make_state(true)
    state.apply_damage(_packet(30.0))
    state.advance(7.99)
    assert_true(is_equal_approx(state.get_shield(), 120.0), "shield waits through normal delay")
    state.advance(0.01)
    assert_true(is_equal_approx(state.get_shield(), 120.0), "delay boundary does not add free charge")
    state.advance(1.0)
    assert_true(is_equal_approx(state.get_shield(), 123.0), "shield regenerates at three per second")
    assert_true(state.is_recharging(), "state reports active shield recharge")

func _test_zero_shield_reboot_and_damage_timer_reset() -> void:
    var state := _make_state(true)
    state.apply_damage(_packet(150.0))
    assert_true(state.is_rebooting(), "zero shield enters reboot")
    state.advance(19.0)
    state.apply_damage(_packet(1.0))
    state.advance(1.1)
    assert_true(is_equal_approx(state.get_shield(), 0.0), "new damage restarts shield reboot")
    state.advance(18.9)
    assert_true(is_equal_approx(state.get_shield(), 0.0), "reboot boundary adds no free charge")
    state.advance(1.0)
    assert_true(is_equal_approx(state.get_shield(), 3.0), "shield charges after restarted reboot")

    state.reset_full()
    state.apply_damage(_packet(30.0))
    state.advance(7.0)
    state.apply_damage(_packet(1.0))
    state.advance(1.1)
    assert_true(is_equal_approx(state.get_shield(), 119.0), "new damage restarts normal recharge delay")

func _test_player_hull_repair_requires_full_shield_delay() -> void:
    var state := _make_state(true)
    state.apply_damage(_packet(160.0))
    state.advance(20.0)
    state.advance(50.0)
    assert_true(is_equal_approx(state.get_shield(), 150.0), "shield reaches full before hull repair")
    assert_true(is_equal_approx(state.get_hull(), 190.0), "hull does not repair while shield fills")
    state.advance(9.99)
    assert_true(is_equal_approx(state.get_hull(), 190.0), "hull waits through full-shield delay")
    state.advance(0.01)
    assert_true(is_equal_approx(state.get_hull(), 190.0), "repair boundary adds no free hull")
    state.advance(1.0)
    assert_true(is_equal_approx(state.get_hull(), 191.0), "player hull repairs at one per second")
    assert_true(state.is_repairing_hull(), "state reports active hull repair")

func _test_drone_never_repairs_hull() -> void:
    var state := _make_state(false)
    state.apply_damage(_packet(160.0))
    state.advance(20.0)
    state.advance(50.0)
    state.advance(100.0)
    assert_true(is_equal_approx(state.get_shield(), 150.0), "drone shield still regenerates")
    assert_true(is_equal_approx(state.get_hull(), 190.0), "drone hull never repairs")
    assert_true(not state.is_repairing_hull(), "drone never reports hull repair")

func _test_destroyed_state_does_not_recover() -> void:
    var state := _make_state(true)
    state.apply_damage(_packet(350.0))
    state.advance(1000.0)
    assert_true(is_equal_approx(state.get_shield(), 0.0), "destroyed shield remains zero")
    assert_true(is_equal_approx(state.get_hull(), 0.0), "destroyed hull remains zero")
    assert_true(state.is_destroyed(), "destroyed flag remains set")

func _test_disabled_and_zero_damage_are_inert() -> void:
    var state := _make_state(true)
    state.apply_damage(_packet(30.0))
    state.advance(7.0)
    var before_shield := state.get_shield()
    var zero := state.apply_damage(_packet(0.0))
    state.advance(1.1)
    assert_true(state.get_shield() > before_shield, "zero damage does not reset recharge timing")
    assert_true(is_equal_approx(zero.applied_to_shield, 0.0), "zero packet applies no shield damage")
    assert_true(is_equal_approx(zero.applied_to_hull, 0.0), "zero packet applies no hull damage")

    state.set_damage_enabled(false)
    var shield_before_disabled := state.get_shield()
    var hull_before_disabled := state.get_hull()
    var ignored := state.apply_damage(_packet(100.0))
    assert_true(is_equal_approx(state.get_shield(), shield_before_disabled), "disabled intake preserves shield")
    assert_true(is_equal_approx(state.get_hull(), hull_before_disabled), "disabled intake preserves hull")
    assert_true(is_equal_approx(ignored.applied_to_shield, 0.0), "disabled result applies no shield damage")
    assert_true(is_equal_approx(ignored.applied_to_hull, 0.0), "disabled result applies no hull damage")
    assert_true(ignored.ignored, "disabled result is marked ignored")
    assert_true(not state.is_damage_enabled(), "damage-disabled state is observable")

func _test_reset_restores_full_enabled_state() -> void:
    var state := _make_state(true)
    state.apply_damage(_packet(350.0))
    state.set_damage_enabled(false)
    state.reset_full()
    assert_true(is_equal_approx(state.get_shield(), 150.0), "reset restores full shield")
    assert_true(is_equal_approx(state.get_hull(), 200.0), "reset restores full hull")
    assert_true(not state.is_destroyed(), "reset clears destruction")
    assert_true(not state.is_rebooting(), "reset clears reboot timer")
    assert_true(not state.is_recharging(), "reset clears recharge state")
    assert_true(not state.is_repairing_hull(), "reset clears repair state")
    assert_true(state.is_damage_enabled(), "reset re-enables damage")

func _test_runtime_auto_advance() -> void:
    var state := _make_state(true)
    state.apply_damage(_packet(30.0))
    for _index: int in range(540):
        state._physics_process(1.0 / 60.0)
    assert_true(
        state.get_shield() > 120.0,
        "runtime DamageState advances regeneration"
    )

func _make_state(repair_enabled: bool) -> DamageState:
    var tuning := DamageTuning.new()
    tuning.maximum_shield = 150.0
    tuning.maximum_hull = 200.0
    tuning.shield_regeneration_delay = 8.0
    tuning.shield_regeneration_rate = 3.0
    tuning.shield_reboot_delay = 20.0
    tuning.hull_repair_enabled = repair_enabled
    tuning.hull_repair_delay_after_full_shield = 10.0
    tuning.hull_repair_rate = 1.0

    var state := DamageState.new()
    state.tuning = tuning
    state.reset_full()
    _owned_states.append(state)
    return state

func _free_owned_states() -> void:
    for state: DamageState in _owned_states:
        if is_instance_valid(state):
            state.free()
    _owned_states.clear()

func _packet(amount: float) -> DamagePacket:
    return DamagePacket.create(
        amount,
        DamagePacket.Kind.PROJECTILE,
        Vector3(1.0, 2.0, 3.0),
        Vector3.BACK,
        42,
        7,
        &"test"
    )
