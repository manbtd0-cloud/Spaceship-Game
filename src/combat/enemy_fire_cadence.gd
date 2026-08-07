class_name EnemyFireCadence
extends RefCounted
var _held:=false;var _until:=0.0;var _side:int=PrimaryFireCadence.MuzzleSide.LEFT
func advance(can_fire:bool,delta:float,rate:float)->Array[int]:
 var out:Array[int]=[]
 if not is_finite(rate) or rate<=0.0 or not can_fire:_held=false;_until=0.0;return out
 var interval:=1.0/rate
 if not _held:_held=true;out.append(_consume());_until=interval;return out
 _until-=maxf(delta,0.0)
 while _until<=0.0:out.append(_consume());_until+=interval
 return out
func reset()->void:_held=false;_until=0.0;_side=PrimaryFireCadence.MuzzleSide.LEFT
func _consume()->int:
 var s:=_side;_side=PrimaryFireCadence.MuzzleSide.RIGHT if _side==PrimaryFireCadence.MuzzleSide.LEFT else PrimaryFireCadence.MuzzleSide.LEFT;return s
