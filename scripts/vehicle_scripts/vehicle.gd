class_name vehicle extends VehicleBody3D

@onready var set_position: SetPosition = $SetPosition


@export var max_steer: float = 0.9
@export var engine_power : float = 300


func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if is_multiplayer_authority():
		$SpringArm3D/Camera3D.current = true
	else:
		$SpringArm3D/Camera3D.current = false
		
	print("spanned vehicle")
	
	#if multiplayer.is_server():
		#position = Vector3(0,1,18)
	#else:
		#position = Vector3(0,1,-18)
		#rotation = Vector3(0,180,0)
	set_position.set_pos()

# Called every frame. 'delta' is the elapsed time since the previous frame.


func _physics_process(delta: float) -> void:
	if !is_multiplayer_authority():
		return
	

	# input + physics only on owning peer
	engine_force = Input.get_axis("backward","forward") * engine_power
	steering = move_toward(steering,Input.get_axis("right","left")* max_steer , delta * 10)
