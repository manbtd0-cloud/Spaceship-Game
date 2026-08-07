extends "res://tests/support/test_case.gd"

func run() -> void:
    assert_equal(EnemyDestructionTimeline.stage_at(0.0), EnemyDestructionTimeline.Stage.BUILDUP, "destruction starts with buildup")
    assert_equal(EnemyDestructionTimeline.stage_at(0.21), EnemyDestructionTimeline.Stage.BLAST, "core blast follows buildup")
    assert_equal(EnemyDestructionTimeline.stage_at(0.60), EnemyDestructionTimeline.Stage.TAIL, "blast transitions to tail")
    assert_equal(EnemyDestructionTimeline.stage_at(1.41), EnemyDestructionTimeline.Stage.COMPLETE, "presentation completes well before respawn")
    assert_true(EnemyDestructionTimeline.core_energy(0.24) > 0.8, "core detonation peaks sharply")
    assert_true(EnemyDestructionTimeline.shockwave_amount(0.50) > 0.0, "shockwave expands after detonation")
    assert_true(is_zero_approx(EnemyDestructionTimeline.shockwave_amount(1.5)), "shockwave self-cleans")
