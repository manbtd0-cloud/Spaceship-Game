class_name TacticalDogfightIntent
extends RefCounted
var state:EnemyDogfightState.Value=EnemyDogfightState.Value.ACQUIRE
var desired_velocity_world:=Vector3.ZERO
var desired_forward_world:=Vector3(0,0,-1)
var evasion_priority:=false
func duplicate_intent()->TacticalDogfightIntent:
 var c:=TacticalDogfightIntent.new();c.state=state;c.desired_velocity_world=desired_velocity_world;c.desired_forward_world=desired_forward_world;c.evasion_priority=evasion_priority;return c
