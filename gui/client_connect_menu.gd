extends CanvasLayer

@onready var nickname_input = $Panel/VBox/NicknameInput
@onready var ip_input = $Panel/VBox/HBox/IPInput
@onready var port_input = $Panel/VBox/HBox/PortInput
@onready var status_label = $Panel/VBox/StatusLabel
@onready var btn_back = $Panel/VBox/HBoxBtns/BtnBack
@onready var btn_connect = $Panel/VBox/HBoxBtns/BtnConnect

func _ready() -> void:
	nickname_input.text = Settings.nickname
	
	btn_back.pressed.connect(_on_back_pressed)
	btn_connect.pressed.connect(_on_connect_pressed)

func _on_back_pressed() -> void:
	queue_free()

func _on_connect_pressed() -> void:
	if nickname_input.text.strip_edges() == "":
		status_label.text = "Error: Nickname cannot be empty!"
		return
		
	Settings.nickname = nickname_input.text.strip_edges()
	Settings.save_config()
	
	var ip = ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
		
	var port = port_input.text.strip_edges().to_int()
	if port <= 0:
		port = 7777
		
	status_label.text = "Connecting..."
	btn_connect.disabled = true
	
	var p = get_parent()
	if p.has_method("connect_to_server"):
		p.connect_to_server(ip, port)
	elif p.get_parent().has_method("connect_to_server"):
		p.get_parent().connect_to_server(ip, port)

func set_status(msg: String, allow_connect: bool = true) -> void:
	if status_label:
		status_label.text = msg
	if btn_connect:
		btn_connect.disabled = not allow_connect
