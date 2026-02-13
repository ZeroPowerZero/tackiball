extends SpringArm3D

@export var mouse_sensibility: float = 0.005
@export var follow_speed: float = 10
@export var player: Node3D
@export var offset: Vector3 = Vector3(0, 0.5, 0)
var mouse_captured := true

var quat: Quaternion
var pitch: float = 0.0
var yaw: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Toggle mouse mode when Shift (mouse_mode_change) is pressed
	if event.is_action_pressed("mouse_mode_change"):
		mouse_captured = !mouse_captured
		
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Rotates camera with quaternions
	if mouse_captured and event is InputEventMouseMotion:
		var relative = event.relative * mouse_sensibility
		
		pitch -= relative.y
		yaw -= relative.x
		
		pitch = clampf(pitch, -1.38, 1.38)
		
		quat = Quaternion.from_euler(Vector3(pitch, yaw, 0))

func _physics_process(delta: float) -> void:
	if !player: return
	position = position.lerp(player.position + offset, follow_speed * delta)
	
	# Make smooth rotations
	var newquat = quaternion.slerp(quat, 10 * delta)
	basis = Basis(newquat.normalized())
