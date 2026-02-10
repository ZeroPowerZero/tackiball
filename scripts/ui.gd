extends CanvasLayer

@onready var name_entry: LineEdit = $MainMenu/MarginContainer/VBoxContainer/name_entry
@onready var address_entry: LineEdit = $MainMenu/MarginContainer/VBoxContainer/AddressEntry




func _on_host_button_pressed() -> void:
	Global.my_name = name_entry.text.strip_edges()
	ServerSetup.start_server()
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _on_join_button_pressed() -> void:
	Global.my_name = name_entry.text.strip_edges()
	ServerSetup.ip_adress = address_entry.text.strip_edges()
	ServerSetup.start_client()
	get_tree().change_scene_to_file("res://scenes/map.tscn")
