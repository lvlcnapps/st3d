extends Area3D

@export var life_time: float = 3.0

@export var linear_velocity: Vector3 = Vector3.ZERO
@export var owner_id: int = 0
var alive_time: float = 0.0

@onready var mesh = $MeshInstance3D
@onready var collision = $CollisionShape3D
@onready var particles = $CPUParticles3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if alive_time > life_time:
		if multiplayer.is_server():
			queue_free()
		return
		
	alive_time += delta
	
	if not collision.disabled:
		global_position += linear_velocity * delta

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
		
	if body is CharacterBody3D:
		if str(body.name) == str(owner_id):
			return
		if body.has_method("take_damage"):
			body.take_damage(40.0)
			body.velocity += linear_velocity * 0.15 # импульс от пули
			
	do_explode.rpc()

@rpc("call_local", "reliable")
func do_explode() -> void:
	collision.set_deferred("disabled", true)
	mesh.visible = false
	
	if particles:
		particles.emitting = true
		
	if multiplayer.is_server():
		await get_tree().create_timer(particles.lifetime).timeout
		queue_free()
