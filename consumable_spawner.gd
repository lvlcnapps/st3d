extends Node3D
class_name ConsumableSpawner

var bonus_hp_scene = preload("res://bonus_hp.tscn")
var bonus_energy_scene = preload("res://bonus_energy.tscn")

var current_bonus: Node3D = null
var spawn_timer: float = 0.0

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
		
	if is_instance_valid(current_bonus):
		return
		
	spawn_timer -= delta
	if spawn_timer <= 0:
		var boot = get_node_or_null("/root/Boot")
		var respawn_time = 10.0
		if boot and boot.server_config.size() > 0:
			respawn_time = boot.server_config.get("bonus_respawn_time", 10.0)
			
		spawn_timer = respawn_time
		spawn_bonus()

func spawn_bonus() -> void:
	var is_hp = randf() > 0.5
	var scene = bonus_hp_scene if is_hp else bonus_energy_scene
	var bonus = scene.instantiate()
	
	bonus.name = "Bonus_" + str(randi())
	bonus.position = global_position
	
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(bonus, true)
		current_bonus = bonus
