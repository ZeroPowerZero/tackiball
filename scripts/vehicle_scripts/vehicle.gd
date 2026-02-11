class_name Vehicle
extends VehicleBody3D

@export_group("base movement")
@export var engine_power: float = 5000.0
@export var reverse_power: float = 2000.0
@export var stop_power: float = 1.0
@export var brake_power: float = 0.5
@export var max_speed: float = 500.0

@export_group("steer")
@export var max_steer: float = 0.5
@export var min_steer_at_speed: float = 0.08
@export var steer_speed: float = 3

@export_group("#*stabilisation")
@export var anti_roll_torque: float = 80.0
@export var downforce_factor: float = 30.0
@export var ground_stick_force: float = 30.0

@export_group("air_control")
@export var air_pitch_torque: float = 8.0
@export var air_yaw_torque: float = 5.0
@export var air_roll_torque: float = 7.0

@export_group("jump")
@export var jump_impulse: float = 8.0
@export var dodge_impulse: float = 7.0
@export var dodge_spin_torque: float = 6.0
@export var dodge_window: float = 1.5

@export_group("boost")
@export var boost_force: float = 5000.0
@export var max_boost: float = 100.0
@export var boost_drain: float = 33.0
@export var boost_max_speed: float = 800.0

@export_group("drift")
@export var normal_wheel_friction: float = 4
@export var drift_wheel_friction: float = 1.2

var boost_amount: float = 33.0
var is_grounded: bool = false
var jump_count: int = 0
var time_since_jump: float = 999.0
var is_drifting: bool = false
var current_speed: float = 0.0

@onready var ground_ray: RayCast3D = $GroundRay
@onready var wheel_fl: VehicleWheel3D = $lf_vw
@onready var wheel_fr: VehicleWheel3D = $rf_vw
@onready var wheel_bl: VehicleWheel3D = $lb_vw
@onready var wheel_br: VehicleWheel3D = $rb_vw

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if is_multiplayer_authority():
		$SpringArm3D/Camera3D.current = true
	else:
		$SpringArm3D/Camera3D.current = false
	
	center_of_mass_mode = VehicleBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.4, 0)
	
	mass = 150.0
	linear_damp = 0.5
	angular_damp = 3.0
	
	_set_all_wheel_friction(normal_wheel_friction)

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	current_speed = linear_velocity.length()
	time_since_jump += delta
	
	_check_ground()
	
	if is_grounded:
		_ground_driving(delta)
		_apply_stabilization(delta)
		_apply_downforce()
	else:
		_air_control(delta)
	
	_handle_jump()
	_handle_boost(delta)
	_handle_drift()
	_clamp_speed()

func _ground_driving(delta: float) -> void:
	var input_throttle := Input.get_axis("backward", "forward")
	
	if input_throttle > 0:
		engine_force = input_throttle * engine_power
	elif is_equal_approx(input_throttle, 0.0):
		engine_force = move_toward(engine_force, 0.0, delta * stop_power)
	else:
		engine_force = input_throttle * reverse_power
	
	var speed_ratio: float = clampf(current_speed / max_speed, 0.0, 1.0)
	if not Input.is_action_pressed("boost"):
		engine_force *= (1.0 - speed_ratio * 0.8)
	
	var steer_input := Input.get_axis("right", "left")
	
	var effective_max_steer := lerpf(max_steer, min_steer_at_speed, speed_ratio)
	var target_steer := steer_input * effective_max_steer
	
	steering = move_toward(steering, target_steer, steer_speed * delta)
	
	if Input.is_action_pressed("brake"):
		brake = brake_power
		engine_force = 0.0
	else:
		brake = 0.0

func _apply_stabilization(_delta: float) -> void:
	var car_up := transform.basis.y
	var world_up := Vector3.UP
	
	var correction := car_up.cross(world_up)
	apply_torque(correction * anti_roll_torque)

func _apply_downforce() -> void:
	var force_amount := current_speed * downforce_factor
	apply_central_force(-transform.basis.y * force_amount)
	
	apply_central_force(Vector3.DOWN * ground_stick_force)

func _air_control(_delta: float) -> void:
	engine_force = 0.0
	steering = 0.0
	brake = 0.0
	
	var pitch_input := Input.get_axis("backward", "forward")
	var yaw_input := Input.get_axis("right", "left")
	
	if Input.is_action_pressed("air_roll"):
		var roll_input := Input.get_axis("left", "right")
		apply_torque(transform.basis.z * roll_input * air_roll_torque)
	else:
		apply_torque(-transform.basis.y * yaw_input * air_yaw_torque)
	
	apply_torque(transform.basis.x * pitch_input * air_pitch_torque)
	
	apply_central_force(Vector3.DOWN * 20.0)

func _handle_jump() -> void:
	if not Input.is_action_just_pressed("jump"):
		return
	
	if is_grounded:
		linear_velocity.y = 0.0
		apply_central_impulse(Vector3.UP * jump_impulse * mass)
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
				transform.basis.z * -input_dir.y +
				transform.basis.x * input_dir.x
			) * dodge_impulse * mass
			
			dodge_velocity.y = jump_impulse * mass * 0.4
			linear_velocity.y = 0.0
			apply_central_impulse(dodge_velocity)
			
			apply_torque_impulse(
				transform.basis.x * -input_dir.y * dodge_spin_torque * mass
			)
		else:
			linear_velocity.y = 0.0
			apply_central_impulse(Vector3.UP * dodge_impulse * mass * 0.8)
		
		jump_count = 2

func _handle_boost(delta: float) -> void:
	if Input.is_action_pressed("boost") and boost_amount > 0.0:
		var boost_dir := -transform.basis.z
		apply_central_force(boost_dir * boost_force)
		boost_amount = maxf(boost_amount - boost_drain * delta, 0.0)

func add_boost(amount: float) -> void:
	boost_amount = minf(boost_amount + amount, max_boost)

func _handle_drift() -> void:
	var wants_drift := Input.is_action_pressed("drift") and is_grounded
	
	if wants_drift and not is_drifting:
		is_drifting = true
		_set_rear_wheel_friction(drift_wheel_friction)
	elif not wants_drift and is_drifting:
		is_drifting = false
		_set_rear_wheel_friction(normal_wheel_friction)

func _set_all_wheel_friction(value: float) -> void:
	for w in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		w.wheel_friction_slip = value

func _set_rear_wheel_friction(value: float) -> void:
	wheel_bl.wheel_friction_slip = value
	wheel_br.wheel_friction_slip = value

func _clamp_speed() -> void:
	var limit := boost_max_speed if Input.is_action_pressed("boost") else max_speed
	if current_speed > limit:
		linear_velocity = linear_velocity.normalized() * limit

func _check_ground() -> void:
	var was_grounded := is_grounded
	is_grounded = ground_ray.is_colliding()
	
	if is_grounded and not was_grounded:
		jump_count = 0
		time_since_jump = 999.0
