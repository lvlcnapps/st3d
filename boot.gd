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

func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.is_server() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			spawn_bot()

func spawn_bot() -> void:
	if not current_level: return
	var bot_id = randi() % 10000 + 10000 # id > 10000 чтобы не конфликтовать с игроками
	var bot_nickname = "Bot_" + str(bot_id)
	
	var player = player_scene.instantiate()
	player.name = str(bot_id)
	player.set("sync_nickname", bot_nickname)
	player.set("is_bot", true)
	
	var random_offset = Vector3(randf_range(-50, 50), 0, randf_range(-50, 50))
	player.position = random_offset
	
	var players_node = current_level.get_node_or_null("Players")
	if players_node:
		players_node.add_child(player)
		print("Spawned bot: ", bot_nickname)

var server_config: Dictionary = {}

func get_config_path() -> String:
	if OS.has_feature("editor"):
		return "res://server_config.ini"
	else:
		return OS.get_executable_path().get_base_dir() + "/server_config.ini"

func load_or_create_config() -> void:
	var path = get_config_path()
	var config = ConfigFile.new()
	if config.load(path) != OK:
		config.set_value("server", "port", PORT_DEFAULT)
		config.set_value("server", "max_players", MAX_CLIENTS)
		config.set_value("gameplay", "max_hp", 100.0)
		config.set_value("gameplay", "max_energy", 100.0)
		config.set_value("gameplay", "respawn_time", 5.0)
		config.set_value("gameplay", "acceleration", 15.0)
		config.set_value("gameplay", "angular_acceleration", 10.0)
		config.set_value("gameplay", "bullet_base_speed", 100.0)
		config.set_value("gameplay", "recoil_force", 5.0)
		config.set_value("gameplay", "shoot_cooldown", 0.2)
		config.set_value("gameplay", "energy_regen_rate", 30.0)
		config.set_value("gameplay", "energy_regen_delay_shoot", 3.0)
		config.set_value("gameplay", "energy_regen_delay_boost", 1.0)
		config.set_value("gameplay", "shoot_energy_cost", 15.0)
		config.set_value("gameplay", "boost_energy_cost", 30.0)
		config.set_value("gameplay", "bullet_damage", 40.0)
		config.save(path)
	
	server_config["port"] = config.get_value("server", "port", PORT_DEFAULT)
	server_config["max_players"] = config.get_value("server", "max_players", MAX_CLIENTS)
	server_config["max_hp"] = config.get_value("gameplay", "max_hp", 100.0)
	server_config["max_energy"] = config.get_value("gameplay", "max_energy", 100.0)
	server_config["respawn_time"] = config.get_value("gameplay", "respawn_time", 5.0)
	server_config["acceleration"] = config.get_value("gameplay", "acceleration", 15.0)
	server_config["angular_acceleration"] = config.get_value("gameplay", "angular_acceleration", 10.0)
	server_config["bullet_base_speed"] = config.get_value("gameplay", "bullet_base_speed", 100.0)
	server_config["recoil_force"] = config.get_value("gameplay", "recoil_force", 5.0)
	server_config["shoot_cooldown"] = config.get_value("gameplay", "shoot_cooldown", 0.2)
	server_config["energy_regen_rate"] = config.get_value("gameplay", "energy_regen_rate", 30.0)
	server_config["energy_regen_delay_shoot"] = config.get_value("gameplay", "energy_regen_delay_shoot", 3.0)
	server_config["energy_regen_delay_boost"] = config.get_value("gameplay", "energy_regen_delay_boost", 1.0)
	server_config["shoot_energy_cost"] = config.get_value("gameplay", "shoot_energy_cost", 15.0)
	server_config["boost_energy_cost"] = config.get_value("gameplay", "boost_energy_cost", 30.0)
	server_config["bullet_damage"] = config.get_value("gameplay", "bullet_damage", 40.0)

func _ready() -> void:
	load_or_create_config()
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
	var port = server_config["port"]
		
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, server_config.get("max_players", MAX_CLIENTS))
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
	accept_player.rpc_id(id, server_config)

@rpc("authority", "call_remote", "reliable")
func accept_player(config: Dictionary) -> void:
	server_config = config
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
