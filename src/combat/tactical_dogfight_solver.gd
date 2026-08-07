class_name TacticalDogfightSolver
extends RefCounted
static func compute(rp:Vector3,ev:Vector3,pv:Vector3,ef:Vector3,eu:Vector3,pf:Vector3,aim:Vector3,pressure:float,current:EnemyDogfightState.Value,state_time:float,cooldown:float,t:EnemyFighterTuning)->TacticalDogfightIntent:
 var out:=TacticalDogfightIntent.new();out.state=current
 if t==null or not rp.is_finite() or not ev.is_finite() or not pv.is_finite() or not ef.is_finite() or not eu.is_finite() or not pf.is_finite() or not is_finite(pressure) or not is_finite(state_time) or not is_finite(cooldown):
  out.desired_forward_world=ef.normalized() if ef.is_finite() and ef.length_squared()>0.000001 else Vector3.FORWARD;return out
 var dist:=rp.length();if dist<=0.000001:return out
 var los:=rp/dist;var to_enemy_from_player:=-los;var pfwd:=pf.normalized() if pf.length_squared()>0.000001 else Vector3.FORWARD
 var threat_angle:=rad_to_deg(acos(clampf(pfwd.dot(to_enemy_from_player),-1,1)))
 var threat:=(dist<=t.threat_range and threat_angle<=t.threat_cone_degrees) or pressure>0.0
 if current==EnemyDogfightState.Value.EVADE and state_time<t.evasion_duration:threat=true
 var closure:=-(pv-ev).dot(los)
 var tangent:=los.cross(eu.normalized() if eu.length_squared()>0.000001 else Vector3.UP)
 if tangent.length_squared()<0.000001:tangent=los.cross(Vector3.RIGHT)
 tangent=tangent.normalized();var upbias:=tangent.cross(los).normalized()
 if threat and (cooldown<=0.0 or current==EnemyDogfightState.Value.EVADE):out.state=EnemyDogfightState.Value.EVADE;out.evasion_priority=true;out.desired_velocity_world=(tangent*0.85+upbias*0.35-los*0.15).normalized()*minf(t.evasion_speed,t.normal_speed_limit)
 elif current==EnemyDogfightState.Value.DISENGAGE and state_time<t.disengage_minimum_time:out.state=EnemyDogfightState.Value.DISENGAGE;out.desired_velocity_world=(-los+tangent*0.25).normalized()*minf(t.disengage_speed,t.normal_speed_limit)
 elif current==EnemyDogfightState.Value.DISENGAGE and dist>=t.reentry_range:out.state=EnemyDogfightState.Value.REENTRY;out.desired_velocity_world=(los+tangent*0.35).normalized()*minf(t.attack_speed,t.normal_speed_limit)
 elif dist<t.close_range or closure>t.overshoot_closure_speed:out.state=EnemyDogfightState.Value.RANGE_CONTROL;out.desired_velocity_world=(-los+tangent*0.8).normalized()*minf(t.range_control_speed,t.normal_speed_limit)
 elif dist>t.preferred_range+t.range_band:out.state=EnemyDogfightState.Value.REENTRY if current==EnemyDogfightState.Value.REENTRY else EnemyDogfightState.Value.ACQUIRE;out.desired_velocity_world=(los+tangent*0.25).normalized()*minf(t.attack_speed,t.normal_speed_limit)
 else:out.state=EnemyDogfightState.Value.ATTACK;out.desired_velocity_world=(los*0.65+tangent*0.25).normalized()*minf(t.attack_speed,t.normal_speed_limit)
 out.desired_velocity_world=out.desired_velocity_world.limit_length(t.normal_speed_limit)
 out.desired_forward_world=aim.normalized() if aim.is_finite() and aim.length_squared()>0.000001 else los
 return out
