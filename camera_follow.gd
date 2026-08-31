extends Camera3D

@export var target: Node3D
@export var rotate_with_target: bool = true
@export var camera_height: float = 35.0
@export var min_camera_height: float = 10.0
@export var max_camera_height: float = 100.0
@export var zoom_speed: float = 5.0
@export var spectator_speed: float = 50.0

@export var pitch_speed: float = 60.0
var camera_pitch: float = -90.0
var server_scoreboard: PanelContainer = null
var xray_enabled: bool = false

func _ready() -> void:
	make_current()
	
	if multiplayer.is_server():
		var canvas = CanvasLayer.new()
		add_child(canvas)
		
		var global_margin = MarginContainer.new()
		global_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		global_margin.add_theme_constant_override("margin_left", 20)
		global_margin.add_theme_constant_override("margin_top", 20)
		global_margin.add_theme_constant_override("margin_right", 20)
		global_margin.add_theme_constant_override("margin_bottom", 20)
		canvas.add_child(global_margin)
		
		server_scoreboard = PanelContainer.new()
		server_scoreboard.size_flags_horizontal = Control.SIZE_SHRINK_END
		server_scoreboard.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		global_margin.add_child(server_scoreboard)
		
		var margin = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.add_theme_constant_override("margin_left", 15)
		margin.add_theme_constant_override("margin_top", 15)
		margin.add_theme_constant_override("margin_right", 15)
		margin.add_theme_constant_override("margin_bottom", 15)
		server_scoreboard.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.name = "VBox"
		margin.add_child(vbox)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			rotate_with_target = !rotate_with_target
		elif event.keycode == KEY_V:
			xray_enabled = !xray_enabled
			
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_height -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_height += zoom_speed
			
		camera_height = clamp(camera_height, min_camera_height, max_camera_height)

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Z):
		camera_pitch -= pitch_speed * delta
	if Input.is_key_pressed(KEY_X):
		camera_pitch += pitch_speed * delta
	camera_pitch = clamp(camera_pitch, -90.0, -30.0)
	
	if Input.is_key_pressed(KEY_UP):
		camera_height -= zoom_speed * 20.0 * delta
	if Input.is_key_pressed(KEY_DOWN):
		camera_height += zoom_speed * 20.0 * delta
	camera_height = clamp(camera_height, min_camera_height, max_camera_height)
	
	if target and "sync_hp" in target and target.sync_hp <= 0:
		target = null
		
	if not target:
		var players_node = get_node_or_null("../Players")
		if players_node:
			var local_id = str(multiplayer.get_unique_id())
			if players_node.has_node(local_id):
				var p = players_node.get_node(local_id)
				if "sync_hp" in p and p.sync_hp > 0:
					target = p
					
	if server_scoreboard:
		var has_local_player = false
		var players_node = get_node_or_null("../Players")
		if players_node and players_node.has_node(str(multiplayer.get_unique_id())):
			has_local_player = true
			
		if not has_local_player:
			server_scoreboard.show()
			var vbox = server_scoreboard.get_node("MarginContainer/VBox")
			for child in vbox.get_children():
				child.queue_free()
				
			var players_list = []
			if players_node:
				for child in players_node.get_children():
					if child is CharacterBody3D and "sync_kills" in child:
						players_list.append(child)
			
			players_list.sort_custom(func(a, b): return a.sync_kills > b.sync_kills)
			
			var header = Label.new()
			header.text = "Player | Kills | Deaths"
			header.add_theme_color_override("font_color", Color(1, 1, 0))
			vbox.add_child(header)
			
			for p in players_list:
				var l = Label.new()
				var p_name = p.sync_nickname if p.sync_nickname != "" else p.name
				l.text = "%s | %d | %d" % [p_name, p.sync_kills, p.sync_deaths]
				vbox.add_child(l)
		else:
			server_scoreboard.hide()
			
	# Режим Spectator (наблюдатель) - если у нас нет корабля
	if not target:
		var move_dir = Vector3.ZERO
		if Input.is_key_pressed(KEY_W): move_dir.z -= 1.0
		if Input.is_key_pressed(KEY_S): move_dir.z += 1.0
		if Input.is_key_pressed(KEY_A): move_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D): move_dir.x += 1.0
		
		if move_dir != Vector3.ZERO:
			move_dir = move_dir.normalized()
			global_position += move_dir * spectator_speed * delta
			
		global_position.y = camera_height
		rotation_degrees = Vector3(camera_pitch, 0, 0)
		return
			
	var horizontal_dist = 0.0
	if abs(camera_pitch + 90.0) > 0.1:
		var pitch_rad = deg_to_rad(camera_pitch)
		horizontal_dist = camera_height / tan(-pitch_rad)
		
	if rotate_with_target:
		# Камера вращается вместе с кораблем (находится сзади, то есть по локальной +Z)
		var backward_dir = target.transform.basis.z.normalized()
		global_position = target.global_position + backward_dir * horizontal_dist
		global_position.y = target.global_position.y + camera_height
		
		rotation_degrees.y = target.rotation_degrees.y
		rotation_degrees.x = camera_pitch
		rotation_degrees.z = 0
	else:
		# Статичная ориентация (камера сзади по глобальной +Z)
		global_position = target.global_position + Vector3(0, 0, horizontal_dist)
		global_position.y = target.global_position.y + camera_height
		
		rotation_degrees = Vector3(camera_pitch, 0, 0)
