extends CanvasLayer

@onready var controls_vbox = $Panel/VBox/Tabs/Controls/VBox
@onready var audio_vbox = $Panel/VBox/Tabs/Audio
@onready var misc_vbox = $Panel/VBox/Tabs/Misc
@onready var btn_close = $Panel/VBox/BtnClose

var waiting_for_key_action: String = ""
var waiting_button: Button = null

var actions = {
	"forward": "Forward",
	"backward": "Backward",
	"left": "Turn Left",
	"right": "Turn Right",
	"strafe_left": "Strafe Left",
	"strafe_right": "Strafe Right",
	"shoot": "Shoot",
	"boost": "Boost",
	"sas": "Manual Brake",
	"auto_sas": "Auto SAS",
	"module1": "Module 1",
	"module2": "Module 2",
	"respawn": "Respawn",
	"cam_up": "Camera Zoom In",
	"cam_down": "Camera Zoom Out",
	"cam_rot_left": "Camera Pitch Up",
	"cam_rot_right": "Camera Pitch Down",
	"cam_yaw_left": "Camera Rotate Left",
	"cam_yaw_right": "Camera Rotate Right",
	"scoreboard": "Scoreboard",
	"look_back": "Look Back",
	"cam_mode": "Toggle Camera Mode"
}

func _ready() -> void:
	btn_close.pressed.connect(_on_close)
	build_controls()
	build_audio()
	build_misc()
	
func build_controls() -> void:
	for action in actions.keys():
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = actions[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 0)
		btn.text = OS.get_keycode_string(Settings.get("bind_" + action))
		btn.pressed.connect(func(): _on_bind_pressed(action, btn))
		
		var reset_btn = Button.new()
		reset_btn.text = "Reset"
		reset_btn.pressed.connect(func(): 
			Settings.reset_bind(action)
			btn.text = OS.get_keycode_string(Settings.get("bind_" + action))
		)
		
		hbox.add_child(label)
		hbox.add_child(btn)
		hbox.add_child(reset_btn)
		controls_vbox.add_child(hbox)

func build_audio() -> void:
	var m_lbl = Label.new()
	m_lbl.text = "Master Volume"
	var m_slider = HSlider.new()
	m_slider.value = Settings.volume_master
	m_slider.value_changed.connect(func(v): Settings.volume_master = v)
	audio_vbox.add_child(m_lbl)
	audio_vbox.add_child(m_slider)
	
	var mus_lbl = Label.new()
	mus_lbl.text = "Music Volume"
	var mus_slider = HSlider.new()
	mus_slider.value = Settings.volume_music
	mus_slider.value_changed.connect(func(v): Settings.volume_music = v)
	audio_vbox.add_child(mus_lbl)
	audio_vbox.add_child(mus_slider)

func build_misc() -> void:
	var fps_chk = CheckBox.new()
	fps_chk.text = "Show FPS"
	fps_chk.button_pressed = Settings.show_fps
	fps_chk.toggled.connect(func(v): Settings.show_fps = v)
	misc_vbox.add_child(fps_chk)
	
	var ping_chk = CheckBox.new()
	ping_chk.text = "Show Ping"
	ping_chk.button_pressed = Settings.show_ping
	ping_chk.toggled.connect(func(v): Settings.show_ping = v)
	misc_vbox.add_child(ping_chk)

func _on_bind_pressed(action: String, btn: Button) -> void:
	waiting_for_key_action = action
	waiting_button = btn
	btn.text = "Press any key..."

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if waiting_for_key_action != "" and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			waiting_button.text = OS.get_keycode_string(Settings.get("bind_" + waiting_for_key_action))
			waiting_for_key_action = ""
			waiting_button = null
			return
			
		Settings.set("bind_" + waiting_for_key_action, event.keycode)
		waiting_button.text = OS.get_keycode_string(event.keycode)
		waiting_for_key_action = ""
		waiting_button = null
		
	elif event is InputEventMouseButton and event.pressed and waiting_for_key_action != "":
		waiting_button.text = OS.get_keycode_string(Settings.get("bind_" + waiting_for_key_action))
		waiting_for_key_action = ""
		waiting_button = null
		
	elif event is InputEventKey and event.pressed and waiting_for_key_action == "":
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_close()
		elif event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()

func _on_close() -> void:
	Settings.save_config()
	var p = get_parent()
	hide()
	var pause_menu = p.get_node_or_null("PauseMenu")
	if pause_menu:
		pause_menu.show()
	else:
		if p.get("is_menu_open") != null:
			p.is_menu_open = false
		queue_free()
