# class name isn't important but i add it
class_name Vehicle
extends VehicleBody3D

# gets the movement component
@onready var movement_component: movement = $movement

# gets the authority when it enters scene
func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	movement_component._ready()
	
	if is_multiplayer_authority():
		var camera: SpringArm3D = get_tree().get_first_node_in_group("Camera")
		if camera:
			camera.player = self

func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority(): # it checks authority
		return
	movement_component.current_speed = linear_velocity.length() # gets speed with length() method
	movement_component.time_since_jump += delta
	
	# just calls the callable functions not important
	movement_component._check_ground()
	
	if movement_component.is_grounded:
		movement_component._ground_driving(delta)
		movement_component._apply_stabilization(delta)
		movement_component._apply_downforce()
	else:
		movement_component._air_control(delta)
	
	movement_component._handle_jump()
	movement_component._handle_boost(delta)
	movement_component._handle_drift()
	movement_component._clamp_speed()
