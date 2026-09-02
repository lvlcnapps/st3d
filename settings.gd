extends Node

const CONFIG_PATH = "user://settings.cfg"

var bind_forward: int = KEY_W
var bind_backward: int = KEY_S
var bind_left: int = KEY_A
var bind_right: int = KEY_D
var bind_strafe_left: int = KEY_LEFT
var bind_strafe_right: int = KEY_RIGHT
var bind_shoot: int = KEY_SPACE
var bind_boost: int = KEY_SHIFT
var bind_sas: int = KEY_CTRL
var bind_auto_sas: int = KEY_ALT
var bind_module1: int = KEY_Q
var bind_module2: int = KEY_E
var bind_respawn: int = KEY_R
var bind_cam_up: int = KEY_UP
var bind_cam_down: int = KEY_DOWN
var bind_cam_rot_left: int = KEY_Z
var bind_cam_rot_right: int = KEY_X
var bind_cam_yaw_left: int = KEY_COMMA
var bind_cam_yaw_right: int = KEY_PERIOD
var bind_scoreboard: int = KEY_TAB
var bind_look_back: int = KEY_B
var bind_cam_mode: int = KEY_C

var volume_master: float = 100.0
var volume_music: float = 100.0

var show_fps: bool = false
var show_ping: bool = true

var nickname: String = ""

func _ready() -> void:
	load_config()

func load_config() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK:
		return # Используем дефолтные значения
		
	bind_forward = config.get_value("controls", "forward", KEY_W)
	bind_backward = config.get_value("controls", "backward", KEY_S)
	bind_left = config.get_value("controls", "left", KEY_A)
	bind_right = config.get_value("controls", "right", KEY_D)
	bind_strafe_left = config.get_value("controls", "strafe_left", KEY_LEFT)
	bind_strafe_right = config.get_value("controls", "strafe_right", KEY_RIGHT)
	bind_shoot = config.get_value("controls", "shoot", KEY_SPACE)
	bind_boost = config.get_value("controls", "boost", KEY_SHIFT)
	bind_sas = config.get_value("controls", "sas", KEY_CTRL)
	bind_auto_sas = config.get_value("controls", "auto_sas", KEY_ALT)
	bind_module1 = config.get_value("controls", "module1", KEY_Q)
	bind_module2 = config.get_value("controls", "module2", KEY_E)
	bind_respawn = config.get_value("controls", "respawn", KEY_R)
	bind_cam_up = config.get_value("controls", "cam_up", KEY_UP)
	bind_cam_down = config.get_value("controls", "cam_down", KEY_DOWN)
	bind_cam_rot_left = config.get_value("controls", "cam_rot_left", KEY_Z)
	bind_cam_rot_right = config.get_value("controls", "cam_rot_right", KEY_X)
	bind_cam_yaw_left = config.get_value("controls", "cam_yaw_left", KEY_COMMA)
	bind_cam_yaw_right = config.get_value("controls", "cam_yaw_right", KEY_PERIOD)
	bind_scoreboard = config.get_value("controls", "scoreboard", KEY_TAB)
	bind_look_back = config.get_value("controls", "look_back", KEY_B)
	bind_cam_mode = config.get_value("controls", "cam_mode", KEY_C)
	
	volume_master = config.get_value("audio", "master", 100.0)
	volume_music = config.get_value("audio", "music", 100.0)
	
	show_fps = config.get_value("ui", "show_fps", false)
	show_ping = config.get_value("ui", "show_ping", true)
	
	nickname = config.get_value("ui", "nickname", "")

func save_config() -> void:
	var config = ConfigFile.new()
	
	config.set_value("controls", "forward", bind_forward)
	config.set_value("controls", "backward", bind_backward)
	config.set_value("controls", "left", bind_left)
	config.set_value("controls", "right", bind_right)
	config.set_value("controls", "strafe_left", bind_strafe_left)
	config.set_value("controls", "strafe_right", bind_strafe_right)
	config.set_value("controls", "shoot", bind_shoot)
	config.set_value("controls", "boost", bind_boost)
	config.set_value("controls", "sas", bind_sas)
	config.set_value("controls", "auto_sas", bind_auto_sas)
	config.set_value("controls", "module1", bind_module1)
	config.set_value("controls", "module2", bind_module2)
	config.set_value("controls", "respawn", bind_respawn)
	config.set_value("controls", "cam_up", bind_cam_up)
	config.set_value("controls", "cam_down", bind_cam_down)
	config.set_value("controls", "cam_rot_left", bind_cam_rot_left)
	config.set_value("controls", "cam_rot_right", bind_cam_rot_right)
	config.set_value("controls", "cam_yaw_left", bind_cam_yaw_left)
	config.set_value("controls", "cam_yaw_right", bind_cam_yaw_right)
	config.set_value("controls", "scoreboard", bind_scoreboard)
	config.set_value("controls", "look_back", bind_look_back)
	config.set_value("controls", "cam_mode", bind_cam_mode)
	
	config.set_value("audio", "master", volume_master)
	config.set_value("audio", "music", volume_music)
	
	config.set_value("ui", "show_fps", show_fps)
	config.set_value("ui", "show_ping", show_ping)
	config.set_value("ui", "nickname", nickname)
	
	config.save(CONFIG_PATH)

func reset_bind(action: String) -> void:
	if action == "forward": bind_forward = KEY_W
	elif action == "backward": bind_backward = KEY_S
	elif action == "left": bind_left = KEY_A
	elif action == "right": bind_right = KEY_D
	elif action == "strafe_left": bind_strafe_left = KEY_LEFT
	elif action == "strafe_right": bind_strafe_right = KEY_RIGHT
	elif action == "shoot": bind_shoot = KEY_SPACE
	elif action == "boost": bind_boost = KEY_SHIFT
	elif action == "sas": bind_sas = KEY_CTRL
	elif action == "auto_sas": bind_auto_sas = KEY_ALT
	elif action == "module1": bind_module1 = KEY_Q
	elif action == "module2": bind_module2 = KEY_E
	elif action == "respawn": bind_respawn = KEY_R
	elif action == "cam_up": bind_cam_up = KEY_UP
	elif action == "cam_down": bind_cam_down = KEY_DOWN
	elif action == "cam_rot_left": bind_cam_rot_left = KEY_Z
	elif action == "cam_rot_right": bind_cam_rot_right = KEY_X
	elif action == "cam_yaw_left": bind_cam_yaw_left = KEY_COMMA
	elif action == "cam_yaw_right": bind_cam_yaw_right = KEY_PERIOD
	elif action == "scoreboard": bind_scoreboard = KEY_TAB
	elif action == "look_back": bind_look_back = KEY_B
	elif action == "cam_mode": bind_cam_mode = KEY_C
