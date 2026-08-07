class_name EnemyFighterController
extends Node
signal respawn_started(duration:float)
signal respawn_progress(seconds_remaining:float)
signal respawned
@export var body_path:NodePath=NodePath("..")
@export var damage_state_path:NodePath=NodePath("../DamageState")
@export var collision_receiver_path:NodePath=NodePath("../CollisionDamageReceiver")
@export var shield_visualizer_path:NodePath=NodePath("../ShieldImpactVisualizer")
@export var visual_root_path:NodePath=NodePath("../VisualRoot")
@export var destruction_pulse_path:NodePath=NodePath("../DestructionPulse")
@export var weapon_controller_path:NodePath=NodePath("../EnemyWeaponController")
@export var tuning:EnemyFighterTuning
var _body:RigidBody3D;var _damage:DamageState;var _collision:CollisionDamageReceiver;var _shield:ShieldImpactVisualizer;var _visual:Node3D;var _pulse:MeshInstance3D;var _weapon:EnemyWeaponController;var _target:RigidBody3D;var _hostile_pool:PulseProjectilePool;var _spawn:=Transform3D.IDENTITY;var _layer:=1;var _mask:=1;var _state:EnemyDogfightState.Value=EnemyDogfightState.Value.ACQUIRE;var _state_time:=0.0;var _cooldown:=0.0;var _intent:=TacticalDogfightIntent.new();var _last_force:=Vector3.ZERO;var _last_torque:=Vector3.ZERO;var _respawn:=0.0;var _dtime:=0.0
func _ready()->void:initialize()
func initialize()->void:
 if _body!=null:return
 _body=get_node_or_null(body_path) as RigidBody3D;_damage=get_node_or_null(damage_state_path) as DamageState;_collision=get_node_or_null(collision_receiver_path) as CollisionDamageReceiver;_shield=get_node_or_null(shield_visualizer_path) as ShieldImpactVisualizer;_visual=get_node_or_null(visual_root_path) as Node3D;_pulse=get_node_or_null(destruction_pulse_path) as MeshInstance3D;_weapon=get_node_or_null(weapon_controller_path) as EnemyWeaponController
 if _body==null or _damage==null or tuning==null:return
 _body.mass=tuning.mass;_spawn=_body.global_transform;_layer=_body.collision_layer;_mask=_body.collision_mask;if _pulse!=null:_pulse.visible=false
 if not _damage.destroyed.is_connected(_on_destroyed):_damage.destroyed.connect(_on_destroyed)
func set_target(b:RigidBody3D)->void:_target=b;if _weapon!=null:_weapon.set_target(b)
func set_hostile_projectile_pool(p:PulseProjectilePool)->void:_hostile_pool=p
func _physics_process(delta:float)->void:step_for_test(delta)
func step_for_test(delta:float)->void:
 initialize();_last_force=Vector3.ZERO;_last_torque=Vector3.ZERO
 if _body==null:return
 if _respawn>0:_advance_respawn(maxf(delta,0));return
 if _damage.is_destroyed() or _target==null or not is_instance_valid(_target):return
 var fallback:=_target.global_position-_body.global_position;var intercept:=ProjectileInterceptSolver.solve(_body.global_position,_body.linear_velocity,_target.global_position,_target.linear_velocity,PulseProjectile.DEFAULT_SPEED);var aim:=intercept.fire_direction_world if intercept.valid else _safe_direction(fallback,-_body.global_transform.basis.z)
 var pressure:=0.0
 if _hostile_pool!=null:
  for p in _hostile_pool.get_active_projectiles():
   if p.global_position.distance_to(_body.global_position)<=tuning.hostile_projectile_awareness_radius:pressure=1.0;break
 var ni:=TacticalDogfightSolver.compute(fallback,_body.linear_velocity,_target.linear_velocity,-_body.global_transform.basis.z,_body.global_transform.basis.y,-_target.global_transform.basis.z,aim,pressure,_state,_state_time,_cooldown,tuning)
 if ni.state!=_state:_state=ni.state;_state_time=0.0
 else:_state_time+=maxf(delta,0)
 _cooldown=maxf(_cooldown-maxf(delta,0),0.0)
 if _state==EnemyDogfightState.Value.EVADE and ni.evasion_priority:_cooldown=tuning.evasion_cooldown
 _intent=ni;_apply_intent()
func _apply_intent()->void:
 var basis:=_body.global_transform.basis.orthonormalized();var local_v:=basis.inverse()*_body.linear_velocity;var desired_local:=basis.inverse()*_intent.desired_velocity_world;var req:=(desired_local-local_v)*_body.mass*tuning.velocity_response
 req.x=clampf(req.x,-tuning.strafe_force,tuning.strafe_force);req.y=clampf(req.y,-tuning.vertical_force,tuning.vertical_force);req.z=clampf(req.z,-tuning.forward_force,tuning.reverse_force);req=FlightSpeedEnvelope.apply_to_force(req,local_v,tuning.normal_speed_soft_start,tuning.normal_speed_limit);_last_force=basis*req;_body.apply_central_force(_last_force)
 var current:=-basis.z;var desired:=_safe_direction(_intent.desired_forward_world,current);var error:=current.cross(desired)
 if error.length_squared()<0.000001 and current.dot(desired)<-0.999: error=basis.y
 var local_err:=basis.inverse()*error;var local_ang:=basis.inverse()*_body.angular_velocity;var tq:=Vector3(local_err.x*tuning.pitch_torque*tuning.attitude_response,local_err.y*tuning.yaw_torque*tuning.attitude_response,local_err.z*tuning.roll_torque*tuning.attitude_response)-local_ang*Vector3(tuning.pitch_torque,tuning.yaw_torque,tuning.roll_torque)*tuning.angular_damping
 tq.x=clampf(tq.x,-tuning.pitch_torque,tuning.pitch_torque);tq.y=clampf(tq.y,-tuning.yaw_torque,tuning.yaw_torque);tq.z=clampf(tq.z,-tuning.roll_torque,tuning.roll_torque);tq=FlightAngularEnvelope.apply_to_torque(tq,local_ang,Vector3(tuning.pitch_angular_soft_start_degrees,tuning.yaw_angular_soft_start_degrees,tuning.roll_angular_soft_start_degrees),Vector3(tuning.pitch_angular_limit_degrees,tuning.yaw_angular_limit_degrees,tuning.roll_angular_limit_degrees));_last_torque=basis*tq;_body.apply_torque(_last_torque)
func reset_to_spawn()->void:
 initialize();_body.freeze=true;_body.global_transform=_spawn;_body.linear_velocity=Vector3.ZERO;_body.angular_velocity=Vector3.ZERO;_body.collision_layer=_layer;_body.collision_mask=_mask;if _visual!=null:_visual.visible=true;if _pulse!=null:_pulse.visible=false;_damage.reset_full();if _collision!=null:_collision.reset_runtime_state();if _shield!=null:_shield.reset_visuals();_state=EnemyDogfightState.Value.ACQUIRE;_state_time=0;_cooldown=0;_intent=TacticalDogfightIntent.new();_last_force=Vector3.ZERO;_last_torque=Vector3.ZERO;_respawn=0;_dtime=0;if _weapon!=null:_weapon.reset_runtime_state();_weapon.set_firing_enabled(true);_body.freeze=false;respawned.emit()
func _on_destroyed(_r:DamageResult)->void:
 if _body==null or _respawn>0:return
 _respawn=tuning.respawn_delay;_body.freeze=true;_body.linear_velocity=Vector3.ZERO;_body.angular_velocity=Vector3.ZERO;_body.collision_layer=0;_body.collision_mask=0;if _weapon!=null:_weapon.set_firing_enabled(false);respawn_started.emit(_respawn);respawn_progress.emit(_respawn)
func _advance_respawn(delta:float)->void:_dtime+=delta;_respawn=maxf(_respawn-delta,0);respawn_progress.emit(_respawn);if _respawn<=0:reset_to_spawn()
func is_respawning()->bool:return _respawn>0
func get_respawn_remaining()->float:return _respawn
func get_tactical_state()->EnemyDogfightState.Value:return _state
func get_last_intent()->TacticalDogfightIntent:return _intent.duplicate_intent()
func get_last_force_world()->Vector3:return _last_force
func get_last_torque_world()->Vector3:return _last_torque
func get_damage_state()->DamageState:return _damage
static func _safe_direction(v:Vector3,f:Vector3)->Vector3:
 if v.is_finite() and v.length_squared()>0.000001:return v.normalized()
 if f.is_finite() and f.length_squared()>0.000001:return f.normalized()
 return Vector3.FORWARD
