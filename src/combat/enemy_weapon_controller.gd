class_name EnemyWeaponController
extends Node
signal shot_fired(side:int,world_transform:Transform3D)
@export var body_path:NodePath=NodePath("..")
@export var model_path:NodePath=NodePath("../VisualRoot/SmallSciFiFighter")
@export var projectile_pool_path:NodePath=NodePath("../PulseProjectilePool")
@export var damage_state_path:NodePath=NodePath("../DamageState")
@export var tuning:EnemyFighterTuning
var _body:RigidBody3D;var _model:Node3D;var _pool:PulseProjectilePool;var _damage:DamageState;var _left:Node3D;var _right:Node3D;var _target:RigidBody3D;var _cadence:=EnemyFireCadence.new();var _enabled:=true;var _last:=ProjectileInterceptResult.invalid();var _legal:=false
func _ready()->void:initialize()
func initialize()->void:
 if _body!=null:return
 _body=get_node_or_null(body_path) as RigidBody3D;_model=get_node_or_null(model_path) as Node3D;_pool=get_node_or_null(projectile_pool_path) as PulseProjectilePool;_damage=get_node_or_null(damage_state_path) as DamageState
 if _body==null or _model==null or _pool==null or _damage==null or tuning==null:return
 var roots:=_model.find_children("Weapons","Node3D",true,false)
 if roots.size()!=1:return
 _left=roots[0].get_node_or_null("Primary/LeftMuzzle") as Node3D;_right=roots[0].get_node_or_null("Primary/RightMuzzle") as Node3D;_pool.initialize()
func set_target(b:RigidBody3D)->void:_target=b
func set_firing_enabled(v:bool)->void:_enabled=v;if not v:_cadence.reset();_legal=false
func reset_runtime_state()->void:_cadence.reset();_last=ProjectileInterceptResult.invalid();_legal=false;_pool.clear_all() if _pool!=null else null
func _physics_process(delta:float)->void:step_for_test(delta)
func step_for_test(delta:float)->void:
 initialize();_legal=false
 if _body==null or _target==null or not is_instance_valid(_target) or _left==null or _right==null:return
 _last=ProjectileInterceptSolver.solve(_body.global_position,_body.linear_velocity,_target.global_position,_target.linear_velocity,PulseProjectile.DEFAULT_SPEED)
 var delta_pos:=_target.global_position-_body.global_position;var distance:=delta_pos.length();var forward:=-_body.global_transform.basis.z.normalized();var angle:=INF
 if _last.valid:angle=rad_to_deg(acos(clampf(forward.dot(_last.fire_direction_world),-1,1)))
 _legal=_enabled and not _damage.is_destroyed() and _last.valid and distance<=tuning.weapon_range and angle<=tuning.firing_cone_degrees and _has_clear_line_of_sight()
 for side in _cadence.advance(_legal,delta,tuning.shots_per_second):_fire(side)
func _fire(side:int)->void:
 var muzzle:=_left if side==PrimaryFireCadence.MuzzleSide.LEFT else _right
 var forward:=-_body.global_transform.basis.z.normalized();var v:=_body.linear_velocity+forward*PulseProjectile.DEFAULT_SPEED
 if _pool.fire(muzzle.global_transform,v,_body)!=null:shot_fired.emit(side,muzzle.global_transform)
func _has_clear_line_of_sight()->bool:
 if _body==null or not _body.is_inside_tree() or _body.get_world_3d()==null or _target==null:return false
 var q:=PhysicsRayQueryParameters3D.create(_body.global_position,_target.global_position);q.collision_mask=0xFFFFFFFF;q.collide_with_bodies=true;q.collide_with_areas=false;q.exclude=[_body.get_rid()]
 var hit:Dictionary=_body.get_world_3d().direct_space_state.intersect_ray(q);return not hit.is_empty() and hit.get("collider")==_target
func has_legal_firing_solution()->bool:return _legal
func get_last_intercept()->ProjectileInterceptResult:return _last
