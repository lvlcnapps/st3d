extends Node3D
class_name ModuleSpawner

var bonus_grapeshot_scene = preload("res://bonus_grapeshot.tscn")
var bonus_impulse_scene = preload("res://bonus_impulse.tscn")

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
		var respawn_time = 15.0 # Для модулей можно сделать кулдаун больше или такой же
		if boot and boot.server_config.size() > 0:
			respawn_time = boot.server_config.get("bonus_respawn_time", 10.0) * 1.5 # 1.5x от кулдауна хп
			
		spawn_timer = respawn_time
		spawn_bonus()

func spawn_bonus() -> void:
	var is_grapeshot = randf() > 0.5
	var scene = bonus_grapeshot_scene if is_grapeshot else bonus_impulse_scene
	var bonus = scene.instantiate()
	
	bonus.name = "Module_" + str(randi())
	bonus.position = global_position
	
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(bonus, true)
		current_bonus = bonus
