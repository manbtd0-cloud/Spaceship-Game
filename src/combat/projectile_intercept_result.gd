class_name ProjectileInterceptResult
extends RefCounted
var valid:=false
var time_seconds:=0.0
var intercept_point_world:=Vector3.ZERO
var fire_direction_world:=Vector3.ZERO
static func invalid()->ProjectileInterceptResult:return ProjectileInterceptResult.new()
static func solved(t:float,p:Vector3,d:Vector3)->ProjectileInterceptResult:
 var r:=ProjectileInterceptResult.new();r.valid=true;r.time_seconds=t;r.intercept_point_world=p;r.fire_direction_world=d;return r
