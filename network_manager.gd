extends Node

const PORT := 4433
const MAX_PLAYERS := 8

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal connected_ok
signal connection_failed
signal server_started

var players: Dictionary = {}
var my_peer_id: int = 0
var is_host: bool = false
var game_mode: String = "SOLO"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(player_name: String = "Host") -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		print("[net] server create failed: ", err)
		return
	multiplayer.multiplayer_peer = peer
	my_peer_id = 1
	is_host = true
	players[1] = player_name
	print("[net] server started on port ", PORT)
	server_started.emit()

func join_game(ip: String = "127.0.0.1") -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		print("[net] client create failed: ", err)
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	print("[net] connecting to ", ip, ":", PORT)

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	my_peer_id = 0

func _on_peer_connected(id: int) -> void:
	print("[net] peer connected: ", id)
	players[id] = "Player " + str(id)
	player_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[net] peer disconnected: ", id)
	players.erase(id)
	player_left.emit(id)

func _on_connected_to_server() -> void:
	my_peer_id = multiplayer.get_unique_id()
	print("[net] connected! my peer id: ", my_peer_id)
	connected_ok.emit()

func _on_conn_failed() -> void:
	print("[net] connection failed")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[net] server disconnected")
	multiplayer.multiplayer_peer = null
