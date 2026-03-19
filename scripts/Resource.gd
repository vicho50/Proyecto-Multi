extends CharacterBody3D

enum UnitState {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

@export var stats: UnitStats
@export var team_id: int = 0

# Punto fijo al que avanza la unidad cuando no tiene enemigos
@export var advance_direction: Vector3 = Vector3.RIGHT

@onready var detection_area: Area3D = $DetectionArea
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_timer: Timer = $AttackTimer

@onready var visuals: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var helmet_mesh: MeshInstance3D = $Visuals/Helmet
@onready var crest_mesh: MeshInstance3D = $Visuals/Crest
@onready var sword_mesh: MeshInstance3D = $Visuals/Sword

@onready var health_bar_root: Node3D = $HealthBarRoot
@onready var health_bar_bg: MeshInstance3D = $HealthBarRoot/HealthBarBg
@onready var health_bar_fill: MeshInstance3D = $HealthBarRoot/HealthBarFill

var current_health: int
var target: Node3D = null
var is_dead: bool = false
var current_state: UnitState = UnitState.IDLE

var visual_base_y: float = 0.0
var bounce_time: float = 0.0
var sword_base_pos: Vector3
var sword_attack_offset: Vector3 = Vector3(0.18, 0.0, 0.0)

var attack_animating: bool = false
var attack_anim_time: float = 0.0
var attack_anim_duration: float = 0.18
var sword_attack_local_dir: Vector3 = Vector3.ZERO

func _ready() -> void:
	current_health = stats.max_health
	add_to_group("units")
	attack_timer.wait_time = stats.attack_cooldown

	visual_base_y = visuals.position.y
	sword_base_pos = sword_mesh.position

	# Ajusta esto según cómo esté orientado tu modelo visual
	# Si ya lo arreglaste y te funciona, deja el valor que te sirvió
	visuals.rotation.y = deg_to_rad(90)

	update_team_color()
	setup_health_bar()
	update_health_bar()
	update_state(UnitState.IDLE)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_target()
	update_logic(delta)
	update_visuals(delta)
	move_and_slide()
	update_health_bar()

func update_state(new_state: UnitState) -> void:
	if current_state == new_state:
		return

	current_state = new_state

func update_target() -> void:
	if not is_instance_valid(target):
		target = null
	elif target.is_dead:
		target = null

	if target == null:
		target = find_closest_enemy()

func update_logic(delta: float) -> void:
	# Si no hay enemigo, avanzar al objetivo fijo
	if target == null:
		update_state(UnitState.CHASE)
		face_movement_direction(advance_direction, delta)
		move_forward(advance_direction)
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	# Si está en rango, atacar
	if distance_to_target <= stats.attack_range:
		velocity = Vector3.ZERO
		face_target(delta)
		update_state(UnitState.ATTACK)
		try_attack()
	else:
		# Perseguir enemigo
		update_state(UnitState.CHASE)
		face_target(delta)
		move_towards_position(target.global_position)

func update_visuals(delta: float) -> void:
	match current_state:
		UnitState.IDLE:
			update_idle_visual(delta)
		UnitState.CHASE:
			update_chase_visual(delta)
		UnitState.ATTACK:
			update_attack_visual(delta)
		UnitState.DEAD:
			update_dead_visual(delta)

func update_idle_visual(delta: float) -> void:
	bounce_time += delta * 2.0
	
	var target_y = visual_base_y + sin(bounce_time) * 0.03
	visuals.position.y = lerp(visuals.position.y, target_y, 8.0 * delta)
	
	if not attack_animating:
		sword_mesh.position = sword_mesh.position.lerp(sword_base_pos, 10.0 * delta)
		
func update_chase_visual(delta: float) -> void:
	bounce_time += delta * 8.0
	
	var target_y = visual_base_y + abs(sin(bounce_time)) * 0.14
	visuals.position.y = lerp(visuals.position.y, target_y, 12.0 * delta)
	
	if not attack_animating:
		var sword_float = sword_base_pos
		sword_float.y += abs(sin(bounce_time)) * 0.03
		sword_mesh.position = sword_mesh.position.lerp(sword_float, 10.0 * delta)
func update_attack_visual(delta: float) -> void:
	visuals.position.y = lerp(visuals.position.y, visual_base_y + 0.04, 10.0 * delta)
	
	var sword_target_pos = sword_base_pos
	
	if attack_animating:
		attack_anim_time += delta
		
		var half_time = attack_anim_duration * 0.5
		var offset_strength := 0.0
		
		if attack_anim_time < half_time:
			# ida
			offset_strength = attack_anim_time / half_time
		elif attack_anim_time < attack_anim_duration:
			# vuelta
			offset_strength = 1.0 - ((attack_anim_time - half_time) / half_time)
		else:
			# termina animación
			attack_animating = false
			attack_anim_time = 0.0
			offset_strength = 0.0
		
		sword_target_pos = sword_base_pos + sword_attack_local_dir * 0.22 * offset_strength
	
	sword_mesh.position = sword_mesh.position.lerp(sword_target_pos, 18.0 * delta)
	
func update_dead_visual(delta: float) -> void:
	visuals.position.y = lerp(visuals.position.y, visual_base_y - 0.3, 6.0 * delta)

func move_towards_position(pos: Vector3) -> void:
	var direction = pos - global_position
	direction.y = 0.0

	if direction.length() > 0.01:
		direction = direction.normalized()
		velocity = direction * stats.move_speed
	else:
		velocity = Vector3.ZERO

func face_target(delta: float) -> void:
	if target == null:
		return

	face_direction(target.global_position, delta)

func face_direction(pos: Vector3, delta: float) -> void:
	var direction = pos - global_position
	direction.y = 0.0

	if direction.length() <= 0.001:
		return

	direction = direction.normalized()
	var target_angle = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

func move_forward(dir: Vector3) -> void:
	var flat_dir = dir
	flat_dir.y = 0.0
	
	if flat_dir.length() <= 0.001:
		velocity = Vector3.ZERO
		return
	
	flat_dir = flat_dir.normalized()
	velocity = flat_dir * stats.move_speed

func face_movement_direction(dir: Vector3, delta: float) -> void:
	var flat_dir = dir
	flat_dir.y = 0.0
	
	if flat_dir.length() <= 0.001:
		return
	
	flat_dir = flat_dir.normalized()
	var target_angle = atan2(flat_dir.x, flat_dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

func try_attack() -> void:
	if target == null:
		return
	
	if attack_timer.is_stopped():
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= stats.attack_range:
			target.take_damage(stats.damage)
			attack_timer.start()
			start_attack_animation()

func find_closest_enemy() -> Node3D:
	var closest_enemy: Node3D = null
	var closest_distance := INF

	for body in detection_area.get_overlapping_bodies():
		if body == self:
			continue
		if not body.is_in_group("units"):
			continue
		if not body.has_method("take_damage"):
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

func setup_health_bar() -> void:
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1)
	health_bar_bg.material_override = bg_mat

	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.1, 0.9, 0.1)
	health_bar_fill.material_override = fill_mat

func update_health_bar() -> void:
	var ratio = clamp(float(current_health) / float(stats.max_health), 0.0, 1.0)

	health_bar_fill.scale.x = ratio
	health_bar_fill.position.x = -0.4 * (1.0 - ratio)

	var cam = get_viewport().get_camera_3d()
	if cam != null:
		health_bar_root.look_at(
			health_bar_root.global_position + cam.global_basis.z,
			Vector3.UP
		)

func update_team_color() -> void:
	var team_color: Color

	if team_id == 0:
		team_color = Color(0.2, 0.4, 1.0)
	else:
		team_color = Color(1.0, 0.2, 0.2)

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = team_color

	var crest_material := StandardMaterial3D.new()
	crest_material.albedo_color = team_color

	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(1.0, 0.8, 0.6)

	var helmet_material := StandardMaterial3D.new()
	helmet_material.albedo_color = Color(0.578, 0.481, 0.0, 1.0)
	helmet_material.metallic = 0.5
	helmet_material.roughness = 0.35

	var sword_material := StandardMaterial3D.new()
	sword_material.albedo_color = Color(0.8, 0.8, 0.8)
	sword_material.metallic = 0.7
	sword_material.roughness = 0.25

	body_mesh.material_override = body_material
	crest_mesh.material_override = crest_material
	head_mesh.material_override = head_material
	helmet_mesh.material_override = helmet_material
	sword_mesh.material_override = sword_material

func start_attack_animation() -> void:
	if target == null:
		return
	
	var dir = target.global_position - global_position
	dir.y = 0.0
	
	if dir.length() <= 0.001:
		return
	
	dir = dir.normalized()
	
	# Convertimos la dirección global a local respecto a Visuals
	sword_attack_local_dir = visuals.global_basis.inverse() * dir
	sword_attack_local_dir = sword_attack_local_dir.normalized()
	
	attack_animating = true
	attack_anim_time = 0.0

func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health -= amount
	update_health_bar()

	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	update_state(UnitState.DEAD)
	velocity = Vector3.ZERO
	remove_from_group("units")

	if has_node("DetectionArea"):
		$DetectionArea.monitoring = false

	await get_tree().create_timer(0.6).timeout
	queue_free()
