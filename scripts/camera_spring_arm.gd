extends SpringArm3D

@export var mouse_sensibility: float = 0.005
@export var follow_speed: float = 10
@export var player: Node3D
@export var offset: Vector3 = Vector3(0, 0.5, 0)
var mouse_captured := true

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
	
	# Rotate camera only when mouse is captured
	if mouse_captured and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensibility)
		
		rotation.x = clamp(
			rotation.x - event.relative.y * mouse_sensibility,
			deg_to_rad(-70),
			deg_to_rad(45)
		)

func _physics_process(delta: float) -> void:
	if !player: return
	position = position.lerp(player.position + offset, follow_speed * delta)
