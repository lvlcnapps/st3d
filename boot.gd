extends Node

const PORT_DEFAULT = 7777
const MAX_CLIENTS = 32
const CONFIG_PATH = "user://server_config.ini"

@export var main_scene: PackedScene = preload("res://main.tscn")
@export var player_scene: PackedScene = preload("res://player.tscn")

@onready var ui = $UI
@onready var nickname_input = $UI/VBoxContainer/NicknameInput
@onready var ip_input = $UI/VBoxContainer/IPInput
@onready var connect_btn = $UI/VBoxContainer/ConnectBtn
@onready var host_btn = $UI/VBoxContainer/HostBtn
@onready var status_label = $UI/VBoxContainer/StatusLabel

var current_level: Node3D
var connected_players: Dictionary = {} # id -> nickname

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.close()
		get_tree().quit()

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	connect_btn.pressed.connect(_on_connect_pressed)
	host_btn.pressed.connect(start_server)
	
	var args = OS.get_cmdline_args()
	if "server" in args:
		start_server()

func start_server() -> void:
	var port = PORT_DEFAULT
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		config.set_value("server", "port", PORT_DEFAULT)
		config.save(CONFIG_PATH)
	else:
		port = config.get_value("server", "port", PORT_DEFAULT)
		
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		print("Failed to start server on port ", port)
		if ui and status_label:
			ui.show()
			status_label.text = "Port %d is already in use!" % port
		return
		
	ui.hide()
	multiplayer.multiplayer_peer = peer
	print("Server started on port ", port)
	
	load_level()

func spawn_player(id: int, nickname: String) -> void:
	var player = player_scene.instantiate()
	player.name = str(id)
	player.set("sync_nickname", nickname)
	var random_offset = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
	player.position = random_offset
	var players_node = current_level.get_node_or_null("Players")
	if players_node:
		players_node.add_child(player)

func _on_connect_pressed() -> void:
	var nickname = nickname_input.text.strip_edges()
	if nickname == "":
		status_label.text = "Enter nickname!"
		return

	var ip = ip_input.text
	if ip == "":
		ip = "127.0.0.1"
		
	var port = PORT_DEFAULT
	
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		status_label.text = "Failed to create client"
		return
		
	multiplayer.multiplayer_peer = peer
	status_label.text = "Connecting..."
	connect_btn.disabled = true
	
	await get_tree().create_timer(5.0).timeout
	if multiplayer.multiplayer_peer == peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		multiplayer.multiplayer_peer = null
		status_label.text = "Connection timed out!"
		connect_btn.disabled = false

func _on_connected_to_server() -> void:
	load_level() # Сначала грузим уровень, чтобы MultiplayerSpawner был готов
	var nickname = nickname_input.text.strip_edges()
	register_player.rpc_id(1, nickname)
	status_label.text = "Authenticating..."

@rpc("any_peer", "call_remote", "reliable")
func register_player(nickname: String) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	
	if nickname in connected_players.values():
		reject_player.rpc_id(id, "Nickname taken!")
		multiplayer.disconnect_peer(id)
		return
		
	connected_players[id] = nickname
	spawn_player(id, nickname)
	accept_player.rpc_id(id)

@rpc("authority", "call_remote", "reliable")
func accept_player() -> void:
	status_label.text = "Connected!"
	ui.hide()

@rpc("authority", "call_remote", "reliable")
func reject_player(reason: String) -> void:
	status_label.text = reason
	multiplayer.multiplayer_peer = null
	ui.show()
	connect_btn.disabled = false
	if current_level:
		current_level.queue_free()
		current_level = null

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"
	connect_btn.disabled = false
	
func _on_server_disconnected() -> void:
	status_label.text = "Server disconnected!"
	ui.show()
	connect_btn.disabled = false
	connected_players.clear()
	if current_level:
		current_level.queue_free()

func load_level() -> void:
	if current_level:
		current_level.queue_free()
	
	current_level = main_scene.instantiate()
	add_child(current_level)
	
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		print("Client connected: ", id)
		# Ждем RPC register_player от клиента для спавна

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		print("Client disconnected: ", id)
		connected_players.erase(id)
		var players_node = current_level.get_node_or_null("Players")
		if players_node and players_node.has_node(str(id)):
			players_node.get_node(str(id)).queue_free()
