extends MultiplayerSpawner

@export var player_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !multiplayer.is_server(): return
	

	multiplayer.peer_connected.connect(spawn_player)
	spawn_player(multiplayer.get_unique_id())


func spawn_player(id: int) -> void:
	if !multiplayer.is_server():
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = Vector3(
		randf_range(-4, 3),
		10,
		randf_range(-4, 3)
	)

	get_node(spawn_path).call_deferred("add_child", player)
