class_name FlightTuning
extends Resource

@export var forward_force: float = 120000.0
@export var reverse_force: float = 50000.0
@export var strafe_force: float = 65000.0
@export var pitch_torque: float = 52000.0
@export var yaw_torque: float = 48000.0
@export var roll_torque: float = 60000.0
@export var boost_multiplier: float = 1.8

@export var normal_speed_soft_start: float = 120.0
@export var normal_speed_limit: float = 160.0
@export var boost_speed_soft_start: float = 180.0
@export var boost_speed_limit: float = 240.0

@export var assist_lateral_damping: float = 12000.0
@export var assist_vertical_damping: float = 12000.0
@export var assist_angular_damping: float = 35000.0

@export var boost_heat_per_second: float = 1.0 / 12.0
@export var boost_cooling_per_second: float = 1.0 / 15.0
@export_range(0.0, 1.0) var boost_recovery_threshold: float = 0.60

@export var assist_steering_strength: float = 1.25
@export var assist_min_steering_speed: float = 8.0
@export var assist_max_steering_acceleration: float = 18.0

@export var auto_bank_max_degrees: float = 22.0
@export var auto_bank_response: float = 5.0

@export var camera_speed_pullback: float = 0.05
@export var camera_max_pullback: float = 14.0
@export var camera_forward_look_ahead: float = 10.0
@export var camera_normal_max_fov: float = 82.0
@export var camera_boost_max_fov: float = 85.0
@export var camera_boost_fov_bonus: float = 1.0
