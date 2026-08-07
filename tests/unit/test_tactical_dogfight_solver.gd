extends "res://tests/support/test_case.gd"
func run()->void:
 var t:=EnemyFighterTuning.new()
 var a:=TacticalDogfightSolver.compute(Vector3(0,0,-700),Vector3.ZERO,Vector3.ZERO,Vector3.FORWARD,Vector3.UP,Vector3.RIGHT,Vector3.FORWARD,0,EnemyDogfightState.Value.ACQUIRE,0,0,t);assert_equal(a.state,EnemyDogfightState.Value.ACQUIRE,"far acquire");assert_true(a.desired_velocity_world.z<0,"closes")
 var atk:=TacticalDogfightSolver.compute(Vector3(0,0,-280),Vector3.ZERO,Vector3.ZERO,Vector3.FORWARD,Vector3.UP,Vector3.RIGHT,Vector3(0.2,0,-1).normalized(),0,EnemyDogfightState.Value.ATTACK,.5,1,t);assert_equal(atk.state,EnemyDogfightState.Value.ATTACK,"attack band")
 var close:=TacticalDogfightSolver.compute(Vector3(0,0,-80),Vector3(0,0,-130),Vector3.ZERO,Vector3.FORWARD,Vector3.UP,Vector3.RIGHT,Vector3.FORWARD,0,EnemyDogfightState.Value.ATTACK,.5,1,t);assert_true(close.state==EnemyDogfightState.Value.RANGE_CONTROL or close.state==EnemyDogfightState.Value.DISENGAGE,"overshoot handled")
 var evade:=TacticalDogfightSolver.compute(Vector3(0,0,-300),Vector3.ZERO,Vector3.ZERO,Vector3.FORWARD,Vector3.UP,Vector3.BACK,Vector3.FORWARD,1,EnemyDogfightState.Value.ATTACK,.5,0,t);assert_equal(evade.state,EnemyDogfightState.Value.EVADE,"pressure evade");assert_true(evade.desired_velocity_world.length()<=t.normal_speed_limit+.001,"bounded")
