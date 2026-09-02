extends CanvasLayer

var config_path = ""
var config_data = {}
var config_controls = {}

const DEFAULT_CONFIG = {
	"server": {
		"port": 7777,
		"max_players": 32
	},
	"gameplay": {
		"max_hp": 100,
		"max_energy": 100,
		"respawn_time": 5.0,
		"acceleration": 15.0,
		"angular_acceleration": 10.0,
		"bullet_base_speed": 100,
		"recoil_force": 5.0,
		"shoot_cooldown": 0.2,
		"energy_regen_rate": 30,
		"energy_regen_delay_shoot": 3.0,
		"energy_regen_delay_boost": 1.0,
		"shoot_energy_cost": 15,
		"boost_energy_cost": 30,
		"bullet_damage": 40,
		"bonus_respawn_time": 10.0,
		"module_grapeshot_charges": 2,
		"module_grapeshot_cooldown": 3.0,
		"module_impulse_charges": 3,
		"module_impulse_cooldown": 5.0,
		"module_grapeshot_speed": 50.0,
		"module_impulse_duration": 1.0,
		"module_impulse_acceleration": 60.0
	}
}

@onready var vbox_container = $Panel/VBox/Scroll/VBox
@onready var btn_back = $Panel/VBox/HBox/BtnBack
@onready var btn_start = $Panel/VBox/HBox/BtnStart

func _ready() -> void:
	if OS.has_feature("editor"):
		config_path = "res://server_config.ini"
	else:
		config_path = OS.get_executable_path().get_base_dir() + "/server_config.ini"
		
	btn_back.pressed.connect(_on_back_pressed)
	btn_start.pressed.connect(_on_start_pressed)
	
	load_config()
	build_ui()

func load_config() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(config_path) == OK:
		for section in DEFAULT_CONFIG.keys():
			if not config_data.has(section):
				config_data[section] = {}
			for key in DEFAULT_CONFIG[section].keys():
				config_data[section][key] = cfg.get_value(section, key, DEFAULT_CONFIG[section][key])
	else:
		# Если файл не существует, используем дефолтные
		for section in DEFAULT_CONFIG.keys():
			config_data[section] = DEFAULT_CONFIG[section].duplicate()

func save_config() -> void:
	var cfg = ConfigFile.new()
	for section in config_data.keys():
		for key in config_data[section].keys():
			cfg.set_value(section, key, config_data[section][key])
	cfg.save(config_path)

func build_ui() -> void:
	for child in vbox_container.get_children():
		child.queue_free()
		
	for section in DEFAULT_CONFIG.keys():
		var section_lbl = Label.new()
		section_lbl.text = "-- " + section.capitalize() + " --"
		section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))
		vbox_container.add_child(section_lbl)
		
		for key in DEFAULT_CONFIG[section].keys():
			var hbox = HBoxContainer.new()
			
			var lbl = Label.new()
			lbl.text = key.capitalize().replace("_", " ")
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(lbl)
			
			var spinbox = SpinBox.new()
			var default_val = DEFAULT_CONFIG[section][key]
			var current_val = config_data[section][key]
			
			if default_val is float:
				spinbox.step = 0.1
				spinbox.max_value = 100000.0
				spinbox.value = float(current_val)
			else:
				spinbox.step = 1
				spinbox.max_value = 100000
				spinbox.value = int(current_val)
				
			spinbox.custom_minimum_size = Vector2(100, 0)
			spinbox.value_changed.connect(func(v): config_data[section][key] = v)
			hbox.add_child(spinbox)
			
			var btn_reset = Button.new()
			btn_reset.text = "Reset"
			btn_reset.pressed.connect(func():
				spinbox.value = default_val
			)
			hbox.add_child(btn_reset)
			
			vbox_container.add_child(hbox)
			config_controls[section + "_" + key] = spinbox
			
func _on_back_pressed() -> void:
	queue_free()

func _on_start_pressed() -> void:
	save_config()
	var p = get_parent()
	if p.has_method("start_server"):
		p.load_or_create_config()
		p.start_server()
	elif p.get_parent().has_method("start_server"):
		p.get_parent().load_or_create_config()
		p.get_parent().start_server()
		
	queue_free()
