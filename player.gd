extends CharacterBody3D

@export var max_speed: float = 50.0
@export var acceleration: float = 15.0

@export var max_angular_speed: float = 3.0
@export var angular_acceleration: float = 5.0

@export var bullet_scene: PackedScene = preload("res://bullet.tscn")
@export var recoil_force: float = 5.0
@export var shoot_cooldown: float = 0.25
@export var bullet_base_speed: float = 50.0

var current_angular_velocity: float = 0.0
var current_cooldown: float = 0.0

@export var sync_velocity: Vector3 = Vector3.ZERO
@export var sync_hp: float = 100.0
@export var sync_energy: float = 100.0
@export var sync_nickname: String = ""

var client_input = {"turn": 0.0, "move": 0.0, "shoot": false, "auto_sas": false, "ctrl_sas": false, "boost": false, "respawn": false}

var auto_sas_enabled: bool = false
var dead_timer: float = 0.0
var energy_regen_delay: float = 0.0

var local_dead_timer: float = 5.0
var was_dead: bool = false

@onready var laser_pivot = get_node_or_null("LaserPivot")
@onready var laser_mesh = get_node_or_null("LaserPivot/LaserMesh")
@onready var ship_model = get_node_or_null("ShipModel")
@onready var collision_shape = get_node_or_null("CollisionShape3D")
@onready var nickname_label = get_node_or_null("NicknameLabel")
@onready var dead_label = get_node_or_null("HUD/CenterContainer/DeadLabel")

func _ready() -> void:
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

func _physics_process(delta: float) -> void:
	if str(name) == str(multiplayer.get_unique_id()):
		var turn_input: float = 0.0
		var move_input: float = 0.0
		var shoot = false
		var ctrl_sas = false
		var boost = false
		var respawn = false
		
		if sync_hp > 0:
			if Input.is_key_pressed(KEY_A): turn_input += 1.0
			if Input.is_key_pressed(KEY_D): turn_input -= 1.0
			if Input.is_key_pressed(KEY_W): move_input += 1.0
			if Input.is_key_pressed(KEY_S): move_input -= 1.0
			shoot = Input.is_key_pressed(KEY_SPACE)
			ctrl_sas = Input.is_key_pressed(KEY_CTRL)
			boost = Input.is_key_pressed(KEY_SHIFT)
		else:
			respawn = Input.is_key_pressed(KEY_R)
		
		var input_data = {
			"turn": turn_input, 
			"move": move_input, 
			"shoot": shoot,
			"auto_sas": auto_sas_enabled,
			"ctrl_sas": ctrl_sas,
			"boost": boost,
			"respawn": respawn
		}
		receive_input.rpc_id(1, input_data)
		
	if multiplayer.is_server():
		apply_physics(delta)
		
func _unhandled_input(event: InputEvent) -> void:
	if str(name) == str(multiplayer.get_unique_id()):
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
		else:
			nickname_label.text = sync_nickname
			nickname_label.visible = not is_dead
			if nickname_label.visible:
				var cam = get_viewport().get_camera_3d()
				if cam:
					var dist = global_position.distance_to(cam.global_position)
					# Базовый масштаб + рост от расстояния. Вдали ник будет казаться меньше, чем вблизи, но не исчезнет
					var s = 10.0 + dist * 0.2
					nickname_label.scale = Vector3(s, s, s)
	
	if str(name) == str(multiplayer.get_unique_id()):
		if has_node("HUD/MarginContainer/SpeedLabel"):
			var speed_label: Label = get_node("HUD/MarginContainer/SpeedLabel")
			var sas_text = "AUTO" if auto_sas_enabled else ("ON" if Input.is_key_pressed(KEY_CTRL) else "OFF")
			speed_label.text = "HP: %d\nEnergy: %d\nSpeed: %.1f units/s\nSAS: %s" % [int(sync_hp), int(sync_energy), sync_velocity.length(), sas_text]

		if dead_label:
			if is_dead:
				if not was_dead:
					was_dead = true
					local_dead_timer = 5.0
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

@rpc("any_peer", "call_local", "unreliable")
func receive_input(input_data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	if str(multiplayer.get_remote_sender_id()) != str(name): return
	client_input = input_data

func apply_physics(delta: float) -> void:
	if sync_hp <= 0:
		if collision_shape: collision_shape.disabled = true
		dead_timer -= delta
		
		if dead_timer <= 0 and client_input.get("respawn", false):
			sync_hp = 100.0
			sync_energy = 100.0
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
		sync_energy = min(sync_energy + 30.0 * delta, 100.0)

	var turn_input = client_input.get("turn", 0.0)
	var move_input = client_input.get("move", 0.0)
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
	
	if is_boost and move_input != 0.0 and sync_energy > 0:
		current_accel *= 2.0
		sync_energy = max(0.0, sync_energy - 30.0 * delta)
		energy_regen_delay = 1.0
	
	var forward_dir: Vector3 = -transform.basis.z
	velocity += forward_dir * move_input * current_accel * delta
	
	if current_cooldown > 0:
		current_cooldown -= delta
		
	if is_shooting and current_cooldown <= 0 and sync_energy >= 15.0:
		shoot(forward_dir)
		sync_energy -= 15.0
		energy_regen_delay = 3.0
		current_cooldown = shoot_cooldown
	
	
	var old_velocity = velocity
	move_and_slide()
	
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

func take_damage(amount: float) -> void:
	if sync_hp <= 0: return
	sync_hp -= amount
	if sync_hp <= 0:
		dead_timer = 5.0
