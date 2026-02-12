class_name movement
extends Node

#region settings
@export_group("Components")
@export var body: VehicleBody3D
@export var ground_ray: Node3D
@export var wheel_fl: Node3D
@export var wheel_fr: Node3D 
@export var wheel_bl: Node3D 
@export var wheel_br: Node3D

@export_group("base movement")
@export var engine_power: float = 10000.0
@export var reverse_power: float = 5000.0
@export var brake_power: float = 0.001
@export var max_speed: float = 10000.0

@export_group("steer")
@export var max_steer: float = 0.3
@export var min_steer_at_speed: float = 0.08
@export var steer_speed: float = 5

@export_group("#*stabilisation")
@export var anti_roll_torque: float = 1000.0
@export var downforce_factor: float = 150.0
@export var ground_stick_force: float = 30.0

@export_group("air_control")
@export var air_pitch_torque: float = 8.0
@export var air_yaw_torque: float = 5.0
@export var air_roll_torque: float = 7.0

@export_group("jump")
@export var jump_impulse: float = 15.0
@export var dodge_impulse: float = 10.0
@export var dodge_spin_torque: float = 6.0
@export var dodge_window: float = 1.5

@export_group("boost")
@export var boost_force: float = 5000.0
@export var max_boost: float = 1000.0
@export var boost_drain: float = 1.0
@export var boost_max_speed: float = 800.0

@export_group("drift")
@export var normal_wheel_friction: float = 12
@export var drift_wheel_friction: float = 0.2
#endregion

var boost_amount: float = 5000.0
var is_grounded: bool = false
var jump_count: int = 0
var time_since_jump: float = 999.0
var is_drifting: bool = false
var current_speed: float = 0.0

func _ready() -> void:
	if body == null:
		return
	
	body.center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_CUSTOM
	body.center_of_mass = Vector3(0, 0.4, 0)
	
	body.mass = 200.0
	body.linear_damp = 1.0
	body.angular_damp = 3.0
	
	_set_all_wheel_friction(normal_wheel_friction)

# Movement Function
func _ground_driving(delta: float) -> void:
	var input_throttle := Input.get_axis("backward", "forward")
	
	if input_throttle > 0:
		body.engine_force = input_throttle * engine_power
	elif input_throttle == 0:
		body.engine_force = 0.0
	else:
		body.engine_force = input_throttle * reverse_power
	
	# Steering system
	var speed_ratio: float = clampf(current_speed / max_speed, 0.0, 1.0)
	if not Input.is_action_pressed("boost"):
		body.engine_force *= (1.0 - speed_ratio * 0.8)
	
	var steer_input := Input.get_axis("right", "left")
	
	var effective_max_steer := lerpf(max_steer, min_steer_at_speed, speed_ratio)
	var target_steer := steer_input * effective_max_steer
	
	body.steering = move_toward(body.steering, target_steer, steer_speed * delta)
	
	# Brake System
	if Input.is_action_pressed("brake"):
		body.brake = brake_power
	else:
		body.brake = 0.0

# Applies Roll Stability
func _apply_stabilization(_delta: float) -> void:
	var car_up := body.transform.basis.y
	var world_up := Vector3.UP
	
	var correction := car_up.cross(world_up)
	body.apply_torque(correction * anti_roll_torque)

# We do this because we don't want to flip the car
func _apply_downforce() -> void:
	var force_amount := current_speed * downforce_factor
	body.apply_central_force(-body.transform.basis.y * force_amount)
	
	body.apply_central_force(Vector3.DOWN * ground_stick_force)

# This is not important but it gives us an air control when we push "Q" button
func _air_control(_delta: float) -> void:
	body.engine_force = 0.0
	body.steering = 0.0
	body.brake = 0.0
	
	var pitch_input := Input.get_axis("backward", "forward")
	var yaw_input := Input.get_axis("right", "left")
	
	if Input.is_action_pressed("air_roll"):
		var roll_input := Input.get_axis("left", "right")
		body.apply_torque(body.transform.basis.z * roll_input * air_roll_torque)
	else:
		body.apply_torque(-body.transform.basis.y * yaw_input * air_yaw_torque)
	
	body.apply_torque(body.transform.basis.x * pitch_input * air_pitch_torque)
	
	body.apply_central_force(Vector3.DOWN * 20.0)

# Common Jumping and flipping system not complex and managable
func _handle_jump() -> void:
	if not Input.is_action_just_pressed("jump"):
		return
	
	if is_grounded:
		body.linear_velocity.y = 0.0
		body.apply_central_impulse(Vector3.UP * jump_impulse * body.mass)
		jump_count = 1
		time_since_jump = 0.0
	elif jump_count == 1 and time_since_jump < dodge_window:
		var input_dir := Vector2(
			Input.get_axis("left", "right"),
			Input.get_axis("backward", "forward")
		)
		
		if input_dir.length() > 0.1:
			input_dir = input_dir.normalized()
			var dodge_velocity := (
				body.transform.basis.z * -input_dir.y +
				body.transform.basis.x * input_dir.x
			) * dodge_impulse * body.mass
			
			dodge_velocity.y = jump_impulse * body.mass * 0.4
			body.linear_velocity.y = 0.0
			body.apply_central_impulse(dodge_velocity)
			
			body.apply_torque_impulse(
				body.transform.basis.x * -input_dir.y * dodge_spin_torque * body.mass
			)
		else:
			body.linear_velocity.y = 0.0
			body.apply_central_impulse(Vector3.UP * dodge_impulse * body.mass * 0.8)
		
		jump_count = 2

# Boosting
func _handle_boost(delta: float) -> void:
	if Input.is_action_pressed("boost") and boost_amount > 0.0:
		var boost_dir := -body.transform.basis.z
		body.apply_central_force(boost_dir * boost_force)
		boost_amount = maxf(boost_amount - boost_drain * delta, 0.0)

func add_boost(amount: float) -> void:
	boost_amount = minf(boost_amount + amount, max_boost)

# Drifting
func _handle_drift() -> void:
	var wants_drift := Input.is_action_pressed("drift") and is_grounded
	
	if wants_drift and not is_drifting:
		is_drifting = true
		_set_rear_wheel_friction(drift_wheel_friction)
	elif not wants_drift and is_drifting:
		is_drifting = false
		_set_rear_wheel_friction(normal_wheel_friction)

# I don't know that it is a good idea but i set the whell frictions in the code from manual
func _set_all_wheel_friction(value: float) -> void:
	for w in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		w.wheel_friction_slip = value

func _set_rear_wheel_friction(value: float) -> void:
	wheel_bl.wheel_friction_slip = value
	wheel_br.wheel_friction_slip = value

# It just limits our speed not important so you can delete this
func _clamp_speed() -> void:
	var limit := boost_max_speed if Input.is_action_pressed("boost") else max_speed
	if current_speed > limit:
		body.linear_velocity = body.linear_velocity.normalized() * limit

# Checks the ground from raycast and attach it to "is_grounded" variable
func _check_ground() -> void:
	var was_grounded := is_grounded
	is_grounded = ground_ray.is_colliding()
	
	if is_grounded and not was_grounded:
		jump_count = 0
		time_since_jump = 999.0
