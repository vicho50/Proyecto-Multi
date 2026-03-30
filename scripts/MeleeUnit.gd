extends CharacterBody3D
class_name MeleeUnit

enum UnitState {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

@export var stats: UnitStats
@export var team_id: int = 0
@export var advance_direction: Vector3 = Vector3.RIGHT

# Network synchronization
var network_id: int = -1

@onready var detection_area: Area3D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer

@onready var visuals: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var weapon_mesh: MeshInstance3D = $Visuals/Weapon

@onready var health_bar_root: Node3D = $HealthBarRoot
@onready var health_bar_bg: MeshInstance3D = $HealthBarRoot/HealthBarBg
@onready var health_bar_fill: MeshInstance3D = $HealthBarRoot/HealthBarFill

var current_health: int
var target: Node3D = null
var is_dead := false
var current_state: UnitState = UnitState.IDLE

var visual_base_y: float = 0.0
var bounce_time: float = 0.0
var weapon_base_pos: Vector3 = Vector3.ZERO

var attack_animating := false
var attack_anim_time := 0.0
var attack_anim_duration := 0.18
var weapon_attack_local_dir: Vector3 = Vector3.ZERO

# Network synchronization variables
var _sync_timer := 0.0
var _sync_tick_rate := 0.05  # 20 Hz update rate
var _target_position: Vector3
var _target_rotation: float
var _interpolation_speed := 10.0

func _ready() -> void:
	if stats == null:
		push_error("%s sin stats asignados" % name)
		set_physics_process(false)
		return

	current_health = stats.max_health
	add_to_group("units")
	attack_timer.wait_time = stats.attack_cooldown

	# Register with UnitManager if this is the server and network_id not set
	if multiplayer.is_server() and network_id == -1:
		network_id = UnitManager.register_unit(self)
	elif network_id != -1:
		# Client received a spawn with network_id already set
		UnitManager.register_unit_with_id(self, network_id)

	# Initialize interpolation targets
	_target_position = global_position
	_target_rotation = rotation.y

	visual_base_y = visuals.position.y
	weapon_base_pos = weapon_mesh.position

	visuals.rotation.y = deg_to_rad(get_visual_rotation_degrees())

	setup_health_bar()
	apply_base_visuals()
	update_health_bar()
	update_state(UnitState.IDLE)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Server runs full simulation
	if multiplayer.is_server():
		update_target()
		update_logic(delta)
		update_visuals(delta)
		move_and_slide()
		update_health_bar()

		# Broadcast state to clients at regular intervals
		_sync_timer += delta
		if _sync_timer >= _sync_tick_rate:
			_sync_timer = 0.0
			sync_unit_state.rpc(global_position, rotation.y, current_health, current_state)
	else:
		# Clients interpolate to received state
		global_position = global_position.lerp(_target_position, _interpolation_speed * delta)
		rotation.y = lerp_angle(rotation.y, _target_rotation, _interpolation_speed * delta)
		update_visuals(delta)
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
	if target == null:
		update_state(UnitState.CHASE)
		face_movement_direction(advance_direction, delta)
		move_forward(advance_direction)
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	if distance_to_target <= stats.attack_range:
		velocity = Vector3.ZERO
		face_target(delta)
		update_state(UnitState.ATTACK)
		try_attack()
	else:
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
		weapon_mesh.position = weapon_mesh.position.lerp(weapon_base_pos, 10.0 * delta)

func update_chase_visual(delta: float) -> void:
	bounce_time += delta * 8.0
	var target_y = visual_base_y + abs(sin(bounce_time)) * 0.14
	visuals.position.y = lerp(visuals.position.y, target_y, 12.0 * delta)

	if not attack_animating:
		var weapon_float = weapon_base_pos
		weapon_float.y += abs(sin(bounce_time)) * 0.03
		weapon_mesh.position = weapon_mesh.position.lerp(weapon_float, 10.0 * delta)

func update_attack_visual(delta: float) -> void:
	visuals.position.y = lerp(visuals.position.y, visual_base_y + 0.04, 10.0 * delta)

	var weapon_target_pos = weapon_base_pos

	if attack_animating:
		attack_anim_time += delta
		var half_time = attack_anim_duration * 0.5
		var offset_strength := 0.0

		if attack_anim_time < half_time:
			offset_strength = attack_anim_time / half_time
		elif attack_anim_time < attack_anim_duration:
			offset_strength = 1.0 - ((attack_anim_time - half_time) / half_time)
		else:
			attack_animating = false
			attack_anim_time = 0.0
			offset_strength = 0.0

		weapon_target_pos = weapon_base_pos + weapon_attack_local_dir * get_attack_animation_distance() * offset_strength

	weapon_mesh.position = weapon_mesh.position.lerp(weapon_target_pos, 18.0 * delta)

func update_dead_visual(delta: float) -> void:
	visuals.position.y = lerp(visuals.position.y, visual_base_y - 0.3, 6.0 * delta)

func move_towards_position(pos: Vector3) -> void:
	var direction = pos - global_position
	direction.y = 0.0

	if direction.length() > 0.01:
		velocity = direction.normalized() * stats.move_speed
	else:
		velocity = Vector3.ZERO

func move_forward(dir: Vector3) -> void:
	var flat_dir = dir
	flat_dir.y = 0.0

	if flat_dir.length() <= 0.001:
		velocity = Vector3.ZERO
		return

	velocity = flat_dir.normalized() * stats.move_speed

func face_target(delta: float) -> void:
	if target == null:
		return
	face_direction(target.global_position, delta)

func face_direction(pos: Vector3, delta: float) -> void:
	var direction = pos - global_position
	direction.y = 0.0

	if direction.length() <= 0.001:
		return

	var dir_norm = direction.normalized()
	var target_angle = atan2(dir_norm.x, dir_norm.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

func face_movement_direction(dir: Vector3, delta: float) -> void:
	var flat_dir = dir
	flat_dir.y = 0.0

	if flat_dir.length() <= 0.001:
		return

	var dir_norm = flat_dir.normalized()
	var target_angle = atan2(dir_norm.x, dir_norm.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

func try_attack() -> void:
	if target == null:
		return

	if attack_timer.is_stopped() and is_instance_valid(target):
		if global_position.distance_to(target.global_position) <= stats.attack_range:
			target.take_damage(stats.damage)
			attack_timer.start()
			start_attack_animation()

func start_attack_animation() -> void:
	if target == null:
		return

	var dir = target.global_position - global_position
	dir.y = 0.0

	if dir.length() <= 0.001:
		return

	weapon_attack_local_dir = (visuals.global_basis.inverse() * dir.normalized()).normalized()
	attack_animating = true
	attack_anim_time = 0.0

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

func apply_base_visuals() -> void:
	var team_color := get_team_color()

	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = team_color
	body_mesh.material_override = body_material

	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = get_head_color()
	head_mesh.material_override = head_material

	var weapon_material := StandardMaterial3D.new()
	weapon_material.albedo_color = get_weapon_color()
	weapon_material.metallic = 0.7
	weapon_material.roughness = 0.25
	weapon_mesh.material_override = weapon_material

func get_team_color() -> Color:
	return Color(0.2, 0.4, 1.0) if team_id == 0 else Color(1.0, 0.2, 0.2)

func get_head_color() -> Color:
	return Color(1.0, 0.8, 0.6)

func get_weapon_color() -> Color:
	return Color(0.8, 0.8, 0.8)

func get_visual_rotation_degrees() -> float:
	return 90.0

func get_attack_animation_distance() -> float:
	return 0.22

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

	# Unregister from UnitManager
	if network_id != -1:
		UnitManager.unregister_unit(network_id)

	if has_node("DetectionArea"):
		$DetectionArea.monitoring = false

	await get_tree().create_timer(0.6).timeout
	queue_free()

# Network synchronization RPC
# Server broadcasts unit state to all clients
@rpc("authority", "unreliable_ordered")
func sync_unit_state(pos: Vector3, rot: float, health: int, state: UnitState) -> void:
	if multiplayer.is_server():
		return  # Server doesn't need to receive its own updates

	# Update interpolation targets
	_target_position = pos
	_target_rotation = rot
	current_health = health
	current_state = state
