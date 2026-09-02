extends CanvasLayer

func _ready() -> void:
	var btn_resume = get_node_or_null("ColorRect/CenterContainer/VBoxContainer/BtnResume")
	var btn_settings = get_node_or_null("ColorRect/CenterContainer/VBoxContainer/BtnSettings")
	var btn_lobby = get_node_or_null("ColorRect/CenterContainer/VBoxContainer/BtnLobby")
	
	if btn_resume: btn_resume.pressed.connect(_on_resume)
	if btn_settings: btn_settings.pressed.connect(_on_settings)
	if btn_lobby: btn_lobby.pressed.connect(_on_lobby)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB and visible:
			get_viewport().set_input_as_handled()
			return
			
		if event.keycode == KEY_ESCAPE and visible:
			var settings = get_parent().get_node_or_null("SettingsMenu")
			if settings and settings.visible:
				return # Если открыты настройки, пусть они сами обрабатывают
			
			get_viewport().set_input_as_handled()
			_on_resume()

func _on_resume() -> void:
	var p = get_parent()
	if p.has_method("toggle_pause_menu"):
		p.toggle_pause_menu()
	else:
		hide()

func _on_settings() -> void:
	var p = get_parent()
	var settings = p.get_node_or_null("SettingsMenu")
	if not settings:
		var SettingsMenuScene = load("res://gui/settings_menu.tscn")
		if SettingsMenuScene:
			settings = SettingsMenuScene.instantiate()
			p.add_child(settings)
	
	if settings:
		hide()
		settings.show()
		if p.get("is_menu_open") != null:
			p.is_menu_open = true

func _on_lobby() -> void:
	multiplayer.multiplayer_peer = null
	get_tree().reload_current_scene()
