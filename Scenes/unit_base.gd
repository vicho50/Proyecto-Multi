extends CharacterBody3D

@export var move_speed: float = 3.5
@export var max_health: int = 100
@export var damage: int = 20
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.0
@export var team_id: int = 0

@onready var detection_area: Area3D = $DetectionArea
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_timer: Timer = $AttackTimer
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var current_health: int
var target: Node3D = null
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	add_to_group("units")
	attack_timer.wait_time = attack_cooldown
	update_team_color()
	print(name, " team_id = ", team_id)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if not is_instance_valid(target):
		target = find_closest_enemy()
	
	if target == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	var distance_to_target = global_position.distance_to(target.global_position)
	
	if distance_to_target <= attack_range:
		velocity = Vector3.ZERO
		move_and_slide()
		try_attack()
	else:
		move_towards_target(delta)

func find_closest_enemy() -> Node3D:
	var closest_enemy: Node3D = null
	var closest_distance := INF
	
	for body in detection_area.get_overlapping_bodies():
		if body == self:
			continue
		if not body.is_in_group("units"):
			continue
		if body.team_id == team_id:
			continue
		if body.is_dead:
			continue
		
		var dist = global_position.distance_to(body.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest_enemy = body
	
	return closest_enemy

func move_towards_target(delta: float) -> void:
	if target == null:
		return
	
	var direction = target.global_position - global_position
	direction.y = 0.0
	
	if direction.length() > 0.1:
		direction = direction.normalized()
		velocity = direction * move_speed
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()

func try_attack() -> void:
	if target == null:
		return
	
	if attack_timer.is_stopped():
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range:
			target.take_damage(damage)
			attack_timer.start()

func update_team_color() -> void:
	var material := StandardMaterial3D.new()
	
	if team_id == 0:
		material.albedo_color = Color(0.2, 0.4, 1.0)
	else:
		material.albedo_color = Color(1.0, 0.2, 0.2)
	
	mesh_instance.material_override = material

func take_damage(amount: int) -> void:
	if is_dead:
		return
	
	current_health -= amount
	
	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	remove_from_group("units")
	queue_free()
