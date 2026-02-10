extends Node


var ip_adress : String = ""
const port : int = 9999

var peer: ENetMultiplayerPeer

func start_server()-> void:
	peer = ENetMultiplayerPeer.new()
	if peer.create_server(port)!=OK:
		print("server not created")
		return
	multiplayer.multiplayer_peer = peer


func start_client()->void:
	
	if ip_adress.length()==0:
		ip_adress="127.0.0.1"
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip_adress,port)!=OK:
		print("Client not connected")
		return
	multiplayer.multiplayer_peer = peer
