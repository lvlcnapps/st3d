extends RigidBody3D
class_name Consumable

@export var type: String = "hp" # "hp" or "energy"
@export var rotation_speed: float = 2.0
@export var hover_amplitude: float = 0.5
@export var hover_speed: float = 3.0

var _time_passed: float = 0.0
var _base_y: float = 0.0

@onready var visual_node = $Visual # Узел, в котором лежит меш, чтобы вращать и парить его

func _ready() -> void:
	# Настройки физики (чтобы бонус не падал и не кувыркался)
	gravity_scale = 0.0
	axis_lock_linear_y = true
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	
	# Чтобы парение работало относительно начальной высоты
	_base_y = global_position.y
	
	if has_node("Area3D"):
		var area = get_node("Area3D")
		area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if visual_node:
		# Вращение
		visual_node.rotate_y(rotation_speed * delta)
		
		# Парение
		_time_passed += delta
		var hover_offset = sin(_time_passed * hover_speed) * hover_amplitude
		visual_node.position.y = hover_offset

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
		
	if body is CharacterBody3D and body.has_method("apply_bonus"):
		# Применяем бонус и удаляемся только если подбор успешен
		var picked_up = body.apply_bonus(type)
		if picked_up:
			queue_free()
