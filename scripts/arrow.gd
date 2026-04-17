extends Area3D
class_name Arrow

var speed: float = 12.0
var damage: int = 0
var target: Node3D = null
var team_id: int = -1
var _hit := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if _hit:
		return

	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return

	var direction = target.global_position + Vector3(0, 0.3, 0) - global_position
	if direction.length() < 0.25:
		_apply_hit()
		return

	var dir_norm = direction.normalized()
	global_position += dir_norm * speed * delta
	look_at(global_position + dir_norm, Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if _hit:
		return
	if body == self:
		return
	if not body.is_in_group("units"):
		return
	if body.team_id == team_id:
		return
	_apply_hit()

func _apply_hit() -> void:
	_hit = true
	if is_instance_valid(target) and not target.is_dead:
		target.take_damage(damage)
	queue_free()
