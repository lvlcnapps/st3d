extends CharacterBody3D

@export var max_speed: float = 50.0
@export var acceleration: float = 15.0

@export var max_angular_speed: float = 3.0
@export var angular_acceleration: float = 10.0

@export var bullet_scene: PackedScene = preload("res://bullet.tscn")
@export var recoil_force: float = 5.0
@export var shoot_cooldown: float = 0.25
@export var bullet_base_speed: float = 100.0

var current_angular_velocity: float = 0.0
var current_cooldown: float = 0.0

@export var sync_velocity: Vector3 = Vector3.ZERO
@export var sync_hp: float = 100.0
@export var sync_energy: float = 100.0
@export var sync_nickname: String = ""
@export var is_bot: bool = false
@export var sync_acceleration: Vector3 = Vector3.ZERO
@export var sync_kills: int = 0
@export var sync_deaths: int = 0

# Инвентарь
@export var sync_slot1_type: String = ""
@export var sync_slot1_charges: int = 0
@export var sync_slot2_type: String = ""
@export var sync_slot2_charges: int = 0
@export var sync_slot1_ready: bool = true
@export var sync_slot2_ready: bool = true

var cooldown_slot1: float = 0.0
var cooldown_slot2: float = 0.0
var impulse_time_left: float = 0.0

var module_grapeshot_speed: float = 50.0
var module_impulse_duration: float = 1.0
var module_impulse_acceleration: float = 30.0

var client_input = {"turn": 0.0, "move": 0.0, "strafe": 0.0, "shoot": false, "auto_sas": false, "ctrl_sas": false, "boost": false, "respawn": false, "module_1": false, "module_2": false}

@export var max_hp: float = 100.0
@export var max_energy: float = 100.0
@export var respawn_time: float = 5.0
@export var energy_regen_rate: float = 30.0
@export var energy_regen_delay_shoot: float = 3.0
@export var energy_regen_delay_boost: float = 1.0
@export var shoot_energy_cost: float = 15.0
@export var boost_energy_cost: float = 30.0

var auto_sas_enabled: bool = false
var dead_timer: float = 0.0
var energy_regen_delay: float = 0.0

var local_dead_timer: float = 5.0
var was_dead: bool = false

var health_bar_node: Node3D
var health_bar_fill: MeshInstance3D
var xray_material: StandardMaterial3D

@onready var laser_pivot = get_node_or_null("LaserPivot")
@onready var laser_mesh = get_node_or_null("LaserPivot/LaserMesh")
@onready var ship_model = get_node_or_null("ShipModel")
@onready var collision_shape = get_node_or_null("CollisionShape3D")
@onready var nickname_label = get_node_or_null("NicknameLabel")
@onready var dead_label = get_node_or_null("HUD/CenterContainer/DeadLabel")
@onready var debug_label = get_node_or_null("HUD/MarginContainer/DebugLabel")

var current_ping: int = 0
var ping_timer: float = 0.0

@onready var slot1_icon = get_node_or_null("HUD/MainInterface/Slot1Icon")
@onready var slot2_icon = get_node_or_null("HUD/MainInterface/Slot2Icon")
@onready var slot1_charges_label = get_node_or_null("HUD/MainInterface/Slot1Icon/ChargesLabel")
@onready var slot2_charges_label = get_node_or_null("HUD/MainInterface/Slot2Icon/ChargesLabel")
@onready var hp_bar = get_node_or_null("HUD/MainInterface/HPBar")
@onready var hp_label = get_node_or_null("HUD/MainInterface/HPBar/HPLabel")
@onready var energy_bar = get_node_or_null("HUD/MainInterface/EnergyBar")
@onready var energy_label = get_node_or_null("HUD/MainInterface/EnergyBar/EnergyLabel")

var tex_grapeshot = preload("res://gui/module_grapeshot.png")
var tex_impulse = preload("res://gui/module_impulse.png")

func _ready() -> void:
	var boot = get_node_or_null("/root/Boot")
	if boot and boot.server_config.size() > 0:
		acceleration = boot.server_config.get("acceleration", acceleration)
		angular_acceleration = boot.server_config.get("angular_acceleration", angular_acceleration)
		bullet_base_speed = boot.server_config.get("bullet_base_speed", bullet_base_speed)
		recoil_force = boot.server_config.get("recoil_force", recoil_force)
		shoot_cooldown = boot.server_config.get("shoot_cooldown", shoot_cooldown)
		max_hp = boot.server_config.get("max_hp", max_hp)
		max_energy = boot.server_config.get("max_energy", max_energy)
		respawn_time = boot.server_config.get("respawn_time", respawn_time)
		energy_regen_rate = boot.server_config.get("energy_regen_rate", energy_regen_rate)
		energy_regen_delay_shoot = boot.server_config.get("energy_regen_delay_shoot", energy_regen_delay_shoot)
		energy_regen_delay_boost = boot.server_config.get("energy_regen_delay_boost", energy_regen_delay_boost)
		shoot_energy_cost = boot.server_config.get("shoot_energy_cost", shoot_energy_cost)
		boost_energy_cost = boot.server_config.get("boost_energy_cost", boost_energy_cost)
		module_grapeshot_speed = boot.server_config.get("module_grapeshot_speed", module_grapeshot_speed)
		module_impulse_duration = boot.server_config.get("module_impulse_duration", module_impulse_duration)
		module_impulse_acceleration = boot.server_config.get("module_impulse_acceleration", module_impulse_acceleration)
		
	local_dead_timer = respawn_time
	
	if multiplayer.is_server():
		sync_hp = max_hp
		sync_energy = max_energy
		
	if str(name) != str(multiplayer.get_unique_id()):
		if has_node("HUD"):
			$HUD.hide()
		if laser_pivot:
			laser_pivot.hide()
		if nickname_label:
			# Чужие ники белые
			nickname_label.modulate = Color(1.0, 1.0, 1.0) 
	else:
		if nickname_label:
			nickname_label.hide() # Скрываем свой ник
		if laser_mesh:
			laser_mesh.extra_cull_margin = 10000.0
			laser_mesh.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
			
	if str(name) != str(multiplayer.get_unique_id()):
		var ui_board = Node3D.new()
		ui_board.name = "UIBoard"
		ui_board.position = Vector3(0, 3.5, 0)
		add_child(ui_board)
		
		if nickname_label:
			nickname_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			remove_child(nickname_label)
			ui_board.add_child(nickname_label)
			nickname_label.position = Vector3(0, 0.6, 0)
			nickname_label.scale = Vector3(10, 10, 10)
		
		# Создание хелсбара
		health_bar_node = Node3D.new()
		health_bar_node.name = "HealthBar"
		health_bar_node.position = Vector3(0, -0.6, 0)
		health_bar_node.scale = Vector3(0.8, 0.8, 0.8)
		ui_board.add_child(health_bar_node)
		
		var bg_mesh = QuadMesh.new()
		bg_mesh.size = Vector2(2.0, 0.2)
		var bg_mat = StandardMaterial3D.new()
		bg_mat.albedo_color = Color(0.2, 0.2, 0.2, 1.0)
		bg_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		bg_mat.no_depth_test = true
		bg_mat.render_priority = 10
		bg_mesh.material = bg_mat
		
		var bg_inst = MeshInstance3D.new()
		bg_inst.mesh = bg_mesh
		health_bar_node.add_child(bg_inst)
		
		var fill_mesh = QuadMesh.new()
		fill_mesh.size = Vector2(2.0, 0.2)
		fill_mesh.center_offset = Vector3(0, 0, 0.01) # Чтобы не было Z-fighting с фоном
		var fill_mat = StandardMaterial3D.new()
		fill_mat.albedo_color = Color(0.0, 1.0, 0.0, 1.0)
		fill_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		fill_mat.no_depth_test = true
		fill_mat.render_priority = 11
		fill_mesh.material = fill_mat
		
		health_bar_fill = MeshInstance3D.new()
		health_bar_fill.mesh = fill_mesh
		health_bar_node.add_child(health_bar_fill)
		
		# X-Ray материал
		xray_material = StandardMaterial3D.new()
		xray_material.albedo_color = Color(1.0, 0.0, 0.0, 0.0)
		xray_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		xray_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		xray_material.no_depth_test = true
		xray_material.cull_mode = StandardMaterial3D.CULL_DISABLED
		xray_material.emission_enabled = true
		xray_material.emission = Color(1.0, 0.0, 0.0, 1.0)
		xray_material.emission_energy_multiplier = 4.0
		
		if ship_model:
			var stack = [ship_model]
			while stack.size() > 0:
				var node = stack.pop_back()
				if node is MeshInstance3D:
					node.material_overlay = xray_material
				for c in node.get_children():
					stack.push_back(c)

func _physics_process(delta: float) -> void:
	if not is_bot and str(name) == str(multiplayer.get_unique_id()):
		var turn_input: float = 0.0
		var move_input: float = 0.0
		var strafe_input: float = 0.0
		var shoot = false
		var ctrl_sas = false
		var boost = false
		var respawn = false
		var module_1 = false
		var module_2 = false
		
		if sync_hp > 0:
			if Input.is_key_pressed(KEY_A): turn_input += 1.0
			if Input.is_key_pressed(KEY_D): turn_input -= 1.0
			if Input.is_key_pressed(KEY_W): move_input += 1.0
			if Input.is_key_pressed(KEY_S): move_input -= 1.0
			if Input.is_key_pressed(KEY_LEFT): strafe_input -= 1.0
			if Input.is_key_pressed(KEY_RIGHT): strafe_input += 1.0
			shoot = Input.is_key_pressed(KEY_SPACE)
			ctrl_sas = Input.is_key_pressed(KEY_CTRL)
			boost = Input.is_key_pressed(KEY_SHIFT)
			module_1 = Input.is_key_pressed(KEY_Q)
			module_2 = Input.is_key_pressed(KEY_E)
		else:
			respawn = Input.is_key_pressed(KEY_R)
		
		var input_data = {
			"turn": turn_input, 
			"move": move_input, 
			"strafe": strafe_input,
			"shoot": shoot,
			"auto_sas": auto_sas_enabled,
			"ctrl_sas": ctrl_sas,
			"boost": boost,
			"respawn": respawn,
			"module_1": module_1,
			"module_2": module_2
		}
		receive_input.rpc_id(1, input_data)
		
	if multiplayer.is_server():
		if is_bot:
			process_bot_ai(delta)
		apply_physics(delta)
		
func _unhandled_input(event: InputEvent) -> void:
	if not is_bot and str(name) == str(multiplayer.get_unique_id()):
		if sync_hp > 0 and event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ALT:
				auto_sas_enabled = !auto_sas_enabled

func _process(_delta: float) -> void:
	var is_dead = sync_hp <= 0
	if ship_model: ship_model.visible = not is_dead
	
	var is_local = str(name) == str(multiplayer.get_unique_id())
	
	if nickname_label:
		if is_local:
			nickname_label.visible = false
			var ui_board = get_node_or_null("UIBoard")
			if ui_board: ui_board.visible = false
		else:
			var ui_board = get_node_or_null("UIBoard")
			if is_dead:
				if ui_board: ui_board.visible = false
			else:
				if ui_board: ui_board.visible = true
				nickname_label.text = sync_nickname
				
				var cam = get_viewport().get_camera_3d()
				if cam:
					var dist = global_position.distance_to(cam.global_position)
					
					if ui_board:
						var dir = (ui_board.global_position - cam.global_position).normalized()
						var up = Vector3.UP
						if abs(dir.dot(up)) > 0.99:
							up = Vector3.FORWARD
						ui_board.look_at(ui_board.global_position + dir, up)
						
						var ui_s = 1.0 + dist * 0.02
						ui_board.scale = Vector3(ui_s, ui_s, ui_s)
						
						if health_bar_node:
							var hp_percent = clamp(sync_hp / max_hp, 0.0, 1.0)
							var current_width = 2.0 * hp_percent
							health_bar_fill.mesh.size.x = max(current_width, 0.001)
							health_bar_fill.mesh.center_offset.x = -1.0 + (current_width / 2.0)
						
					if xray_material and "xray_enabled" in cam:
						xray_material.albedo_color.a = 0.5 if cam.xray_enabled else 0.0
	
	if str(name) == str(multiplayer.get_unique_id()):
		if debug_label:
			ping_timer += _delta
			if ping_timer >= 1.0:
				ping_timer = 0.0
				rpc_id(1, "ping_request", Time.get_ticks_msec())
			debug_label.text = "Ping: %d ms\nFPS: %d" % [current_ping, Engine.get_frames_per_second()]
			
		if hp_bar:
			hp_bar.max_value = max_hp
			hp_bar.value = sync_hp
			if hp_label: hp_label.text = str(int(sync_hp))
			
		if energy_bar:
			energy_bar.max_value = max_energy
			energy_bar.value = sync_energy
			if energy_label: energy_label.text = str(int(sync_energy))
			
		if slot1_icon:
			if sync_slot1_type == "grapeshot":
				slot1_icon.texture = tex_grapeshot
			elif sync_slot1_type == "impulse":
				slot1_icon.texture = tex_impulse
			else:
				slot1_icon.texture = null
				
			var color = Color(1, 1, 1, 1) if sync_slot1_ready else Color(0.5, 0.5, 0.5, 1)
			slot1_icon.modulate = color
			
			if slot1_charges_label:
				slot1_charges_label.text = str(sync_slot1_charges) if sync_slot1_charges > 0 else ""
				
		if slot2_icon:
			if sync_slot2_type == "grapeshot":
				slot2_icon.texture = tex_grapeshot
			elif sync_slot2_type == "impulse":
				slot2_icon.texture = tex_impulse
			else:
				slot2_icon.texture = null
				
			var color = Color(1, 1, 1, 1) if sync_slot2_ready else Color(0.5, 0.5, 0.5, 1)
			slot2_icon.modulate = color
			
			if slot2_charges_label:
				slot2_charges_label.text = str(sync_slot2_charges) if sync_slot2_charges > 0 else ""

		if dead_label:
			if is_dead:
				if not was_dead:
					was_dead = true
					local_dead_timer = respawn_time
				local_dead_timer -= _delta
				if local_dead_timer > 0:
					dead_label.text = "Respawn in %d..." % ceil(local_dead_timer)
				else:
					dead_label.text = "Press R to respawn"
				dead_label.show()
			else:
				was_dead = false
				dead_label.hide()

		if laser_pivot and laser_mesh and not is_dead:
			var forward_dir = -transform.basis.z
			var predicted_bullet_vel = forward_dir * bullet_base_speed + sync_velocity
			var speed_len = predicted_bullet_vel.length()
			
			if speed_len > 0.1:
				var look_pos = global_position + predicted_bullet_vel
				if abs(predicted_bullet_vel.normalized().dot(Vector3.UP)) < 0.99:
					laser_pivot.look_at(look_pos, Vector3.UP)
				else:
					laser_pivot.look_at(look_pos, Vector3.RIGHT)
					
				var laser_length = 50.0
				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(global_position, look_pos)
				query.exclude = [self.get_rid()]
				var result = space_state.intersect_ray(query)
				
				if result:
					var hit_dist = global_position.distance_to(result.position)
					laser_length = min(laser_length, hit_dist)
					
				laser_mesh.scale.y = laser_length
				laser_mesh.position.z = -laser_length / 2.0
				laser_pivot.show()
			else:
				laser_pivot.hide()
		elif laser_pivot:
			laser_pivot.hide()
			
		var scoreboard_panel = get_node_or_null("HUD/MarginContainer/ScoreboardPanel")
		if scoreboard_panel:
			var show_scoreboard = Input.is_key_pressed(KEY_TAB) or sync_hp <= 0
			if show_scoreboard:
				scoreboard_panel.show()
				var vbox = scoreboard_panel.get_node("MarginContainer/VBoxContainer")
				for child in vbox.get_children():
					child.queue_free()
				
				var players_list = []
				for child in get_parent().get_children():
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
					if str(p.name) == str(multiplayer.get_unique_id()):
						l.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
					vbox.add_child(l)
			else:
				scoreboard_panel.hide()

@rpc("any_peer", "call_local", "unreliable")
func receive_input(input_data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	if str(multiplayer.get_remote_sender_id()) != str(name): return
	client_input = input_data

func apply_physics(delta: float) -> void:
	var old_velocity_before_apply = velocity
	
	if sync_hp <= 0:
		if collision_shape: collision_shape.disabled = true
		dead_timer -= delta
		
		if dead_timer <= 0 and client_input.get("respawn", false):
			sync_hp = max_hp
			sync_energy = max_energy
			velocity = Vector3.ZERO
			current_angular_velocity = 0.0
			position = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
			if collision_shape: collision_shape.disabled = false
		return
	else:
		if collision_shape and collision_shape.disabled:
			collision_shape.disabled = false
			
	if energy_regen_delay > 0:
		energy_regen_delay -= delta
	else:
		sync_energy = min(sync_energy + energy_regen_rate * delta, max_energy)

	var turn_input = client_input.get("turn", 0.0)
	var move_input = client_input.get("move", 0.0)
	var strafe_input = client_input.get("strafe", 0.0)
	var is_shooting = client_input.get("shoot", false)
	var is_sas = client_input.get("auto_sas", false) or client_input.get("ctrl_sas", false)
	var is_boost = client_input.get("boost", false)
	
	if turn_input != 0.0:
		current_angular_velocity += turn_input * angular_acceleration * delta
	elif is_sas:
		current_angular_velocity = move_toward(current_angular_velocity, 0.0, angular_acceleration * delta)
		
	current_angular_velocity = clamp(current_angular_velocity, -max_angular_speed, max_angular_speed)
	rotation.y += current_angular_velocity * delta
	
	var current_accel = acceleration
	
	if is_boost and (move_input != 0.0 or strafe_input != 0.0) and sync_energy > 0:
		current_accel *= 2.0
		sync_energy = max(0.0, sync_energy - boost_energy_cost * delta)
		energy_regen_delay = energy_regen_delay_boost
	
	var forward_dir: Vector3 = -transform.basis.z
	var right_dir: Vector3 = transform.basis.x
	
	# Обработка кулдаунов модулей
	if cooldown_slot1 > 0:
		cooldown_slot1 -= delta
	sync_slot1_ready = cooldown_slot1 <= 0
		
	if cooldown_slot2 > 0:
		cooldown_slot2 -= delta
	sync_slot2_ready = cooldown_slot2 <= 0
		
	# Использование модулей
	if client_input.get("module_1", false):
		use_module(1, forward_dir)
	if client_input.get("module_2", false):
		use_module(2, forward_dir)
		
	# Применение ускорения от Impulse
	if impulse_time_left > 0:
		impulse_time_left -= delta
		velocity += forward_dir * module_impulse_acceleration * delta
	
	velocity += forward_dir * move_input * current_accel * delta
	velocity += right_dir * strafe_input * current_accel * delta
	
	if current_cooldown > 0:
		current_cooldown -= delta
		
	if is_shooting and current_cooldown <= 0 and sync_energy >= shoot_energy_cost:
		shoot(forward_dir)
		sync_energy -= shoot_energy_cost
		energy_regen_delay = energy_regen_delay_shoot
		current_cooldown = shoot_cooldown
	
	
	var old_velocity = velocity
	move_and_slide()
	
	sync_acceleration = (velocity - old_velocity_before_apply) / delta
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var n = collision.get_normal()
		
		if collider is CharacterBody3D and "sync_hp" in collider:
			var rel_vel = old_velocity - collider.velocity
			var speed_along_normal = rel_vel.dot(n)
			if speed_along_normal < 0:
				var j = -speed_along_normal * 0.65 # (1 + 0.3) / 2 = 0.65, где 0.3 это упругость
				var impulse = j * n
				velocity = old_velocity + impulse
				collider.velocity -= impulse
		else:
			var speed_along_normal = old_velocity.dot(n)
			if speed_along_normal < 0:
				velocity = old_velocity - 1.3 * speed_along_normal * n # 1 + 0.3 = 1.3
				old_velocity = velocity
	
	sync_velocity = velocity

func shoot(forward_dir: Vector3) -> void:
	if not bullet_scene: return
		
	var bullet = bullet_scene.instantiate()
	bullet.position = global_position + forward_dir * 3.5
	bullet.linear_velocity = forward_dir * bullet_base_speed + velocity
	bullet.owner_id = int(str(name))
	
	var bullets_node = get_node_or_null("../../Bullets")
	if bullets_node:
		bullets_node.add_child(bullet, true)
	else:
		get_parent().add_child(bullet, true)
	
	velocity -= forward_dir * recoil_force

func use_module(slot_idx: int, forward_dir: Vector3) -> void:
	var module_type = ""
	var is_ready = false
	
	if slot_idx == 1:
		if sync_slot1_charges <= 0: return
		module_type = sync_slot1_type
		is_ready = cooldown_slot1 <= 0
	elif slot_idx == 2:
		if sync_slot2_charges <= 0: return
		module_type = sync_slot2_type
		is_ready = cooldown_slot2 <= 0
		
	if not is_ready or module_type == "": return
	
	var boot = get_node_or_null("/root/Boot")
	var cooldown = 3.0
	
	if module_type == "grapeshot":
		cooldown = boot.server_config.get("module_grapeshot_cooldown", 3.0) if boot else 3.0
		# Спавним 5 пуль веером
		var angles = [-20.0, -10.0, 0.0, 10.0, 20.0]
		var bullets_node = get_node_or_null("../../Bullets")
		if not bullets_node: bullets_node = get_parent()
		
		for deg in angles:
			var rad = deg_to_rad(deg)
			var shoot_dir = forward_dir.rotated(Vector3.UP, rad)
			if bullet_scene:
				var bullet = bullet_scene.instantiate()
				bullet.position = global_position + shoot_dir * 3.5
				bullet.linear_velocity = shoot_dir * module_grapeshot_speed + velocity
				bullet.owner_id = int(str(name))
				bullets_node.add_child(bullet, true)
				
	elif module_type == "impulse":
		cooldown = boot.server_config.get("module_impulse_cooldown", 5.0) if boot else 5.0
		impulse_time_left = module_impulse_duration
		
	# Устанавливаем кулдаун и тратим заряд
	if slot_idx == 1:
		cooldown_slot1 = cooldown
		sync_slot1_charges -= 1
		if sync_slot1_charges <= 0:
			sync_slot1_type = ""
	elif slot_idx == 2:
		cooldown_slot2 = cooldown
		sync_slot2_charges -= 1
		if sync_slot2_charges <= 0:
			sync_slot2_type = ""

func apply_bonus(bonus_type: String) -> bool:
	if sync_hp <= 0: return false # Мертвые не могут подбирать
	
	if bonus_type == "hp":
		sync_hp = max_hp
		return true
	elif bonus_type == "energy":
		sync_energy = max_energy
		return true
		
	# Логика для модулей (grapeshot, impulse)
	var max_c = 2
	var boot = get_node_or_null("/root/Boot")
	if boot and boot.server_config.size() > 0:
		max_c = boot.server_config.get("module_" + bonus_type + "_charges", 2 if bonus_type == "grapeshot" else 3)
	elif bonus_type == "impulse":
		max_c = 3
	
	var charges_to_add = max_c
	var picked_up = false
	
	# Пытаемся заполнить первый слот
	if sync_slot1_type == bonus_type or sync_slot1_type == "":
		if sync_slot1_type == "":
			sync_slot1_type = bonus_type
		var space = max_c - sync_slot1_charges
		if space > 0:
			var added = min(space, charges_to_add)
			sync_slot1_charges += added
			charges_to_add -= added
			picked_up = true
			
	# Если остались заряды, пытаемся заполнить второй слот
	if charges_to_add > 0 and (sync_slot2_type == bonus_type or sync_slot2_type == ""):
		if sync_slot2_type == "":
			sync_slot2_type = bonus_type
		var space = max_c - sync_slot2_charges
		if space > 0:
			var added = min(space, charges_to_add)
			sync_slot2_charges += added
			charges_to_add -= added
			picked_up = true
			
	return picked_up

func take_damage(amount: float, attacker_id: int = -1) -> void:
	if sync_hp <= 0: return
	sync_hp -= amount
	if sync_hp <= 0:
		dead_timer = respawn_time
		sync_deaths += 1
		if attacker_id != -1 and str(attacker_id) != str(name):
			var players_node = get_parent()
			if players_node:
				var attacker = players_node.get_node_or_null(str(attacker_id))
				if attacker and "sync_kills" in attacker:
					attacker.sync_kills += 1

func process_bot_ai(delta: float) -> void:
	if sync_hp <= 0:
		client_input = {"turn": 0.0, "move": 0.0, "strafe": 0.0, "shoot": false, "auto_sas": false, "ctrl_sas": false, "boost": false, "respawn": true}
		return
		
	var target: CharacterBody3D = null
	var min_dist = 100000.0
	
	for sibling in get_parent().get_children():
		if sibling != self and sibling is CharacterBody3D and "sync_hp" in sibling and sibling.sync_hp > 0:
			var d = global_position.distance_to(sibling.global_position)
			if d < min_dist:
				min_dist = d
				target = sibling
				
	var new_input = {"turn": 0.0, "move": 0.0, "strafe": 0.0, "shoot": false, "auto_sas": false, "ctrl_sas": false, "boost": false, "respawn": false}
	
	if target:
		var target_pos = target.global_position
		var target_vel = target.velocity
		
		# Алгоритм баллистики (аналитический из EdgarBrain)
		var D = target_pos - global_position
		var V_rel = target_vel - velocity
		
		var D2 = Vector2(D.x, D.z)
		var V_rel2 = Vector2(V_rel.x, V_rel.z)
		
		var b = D2.angle() - V_rel2.angle()
		var sina = sin(b) * V_rel2.length() / bullet_base_speed
		
		var aim_angle = D2.angle()
		if abs(sina) <= 1.0:
			aim_angle -= asin(sina)
			
		var aim_dir = Vector3(cos(aim_angle), 0, sin(aim_angle)).normalized()
		var forward = -transform.basis.z
		
		# Вычисляем разницу углов со знаком
		var point = forward.signed_angle_to(aim_dir, Vector3.UP)
		print("Некий поинт = " + str(point))
		var speed = current_angular_velocity
		var dist = abs(point)
		
		# ПД-регулятор из EdgarBrain (turn_to_angle)
		if dist < 0.003 or abs(speed) > PI:
			new_input["ctrl_sas"] = true
		else:
			if point > 0:
				if speed == 0 or abs(point / speed) > abs(speed / angular_acceleration):
					new_input["turn"] = 1.0
				else:
					new_input["ctrl_sas"] = true
			else:
				if speed == 0 or abs(point / speed) > abs(speed / angular_acceleration):
					new_input["turn"] = -1.0
				else:
					new_input["ctrl_sas"] = true
		
		# Стреляем, если смотрим почти точно на цель
		if aim_dir.dot(forward) > 0.999:
			new_input["shoot"] = true
			
	client_input = new_input

@rpc("any_peer", "call_remote", "unreliable")
func ping_request(client_time: int) -> void:
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		rpc_id(sender_id, "ping_response", client_time)

@rpc("authority", "call_remote", "unreliable")
func ping_response(client_time: int) -> void:
	current_ping = Time.get_ticks_msec() - client_time
