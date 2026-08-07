extends "res://tests/support/test_case.gd"
func run()->void:
 var r:=ProjectileInterceptSolver.solve(Vector3.ZERO,Vector3.ZERO,Vector3(0,0,-900),Vector3.ZERO,900.0);assert_true(r.valid,"stationary target solves");assert_true(is_equal_approx(r.time_seconds,1.0),"time exact");assert_true(r.fire_direction_world.is_equal_approx(Vector3(0,0,-1)),"straight ahead")
 var lead:=ProjectileInterceptSolver.solve(Vector3.ZERO,Vector3.ZERO,Vector3(0,0,-450),Vector3(90,0,0),900.0);assert_true(lead.valid and lead.fire_direction_world.x>0,"lateral lead")
 var impossible:=ProjectileInterceptSolver.solve(Vector3.ZERO,Vector3.ZERO,Vector3(0,0,-100),Vector3(0,0,-1000),900.0);assert_true(not impossible.valid,"impossible rejected")
 assert_true(not ProjectileInterceptSolver.solve(Vector3(INF,0,0),Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,900).valid,"nan closed")
