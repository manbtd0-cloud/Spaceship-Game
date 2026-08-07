extends "res://tests/support/test_case.gd"
func run()->void:
 var c:=EnemyFireCadence.new();var f:=c.advance(true,0,3);assert_equal(f.size(),1,"first shot");assert_equal(f[0],PrimaryFireCadence.MuzzleSide.LEFT,"left first");assert_equal(c.advance(true,.1,3).size(),0,"cadence block");var s:=c.advance(true,.24,3);assert_equal(s.size(),1,"second shot");assert_equal(s[0],PrimaryFireCadence.MuzzleSide.RIGHT,"right second");c.reset();assert_equal(c.advance(true,0,NAN).size(),0,"nan closed")
