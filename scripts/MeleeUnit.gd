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

# Separación: empuja a las unidades del mismo equipo para que no se apilen en
# fila y rodeen al objetivo en vez de quedarse atascadas detrás de un aliado.
@export var separation_radius: float = 1.2
@export var separation_weight: float = 1.5
# Radio de detección para obstáculos del terreno (árboles, colinas, montañas).
# Es más grande porque los meshes de decoración ocupan más espacio que un aliado.
@export var obstacle_separation_radius: float = 2.5
@export var obstacle_avoidance_distance: float = 1.0
@export var obstacle_avoidance_probe_radius: float = 0.28
@export var castle_engage_distance: float = 12.0
@export var obstacle_avoidance_angles: PackedFloat32Array = PackedFloat32Array([0.0, 15.0, -15.0, 30.0, -30.0, 45.0, -45.0])

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

func _ready() -> void:
	if stats == null:
		push_error("%s sin stats asignados" % name)
		set_physics_process(false)
		return

	current_health = stats.max_health
	add_to_group("units")
	attack_timer.wait_time = stats.attack_cooldown

	visual_base_y = visuals.position.y
	weapon_base_pos = weapon_mesh.position

	visuals.rotation.y = deg_to_rad(get_visual_rotation_degrees())

	setup_health_bar()
	apply_base_visuals()
	update_health_bar()
	update_state(UnitState.IDLE)

func _physics_process(delta: float) -> void:
	if is_dead:
		update_visuals(delta)
		return

	# Si la partida ya se decidió, las unidades dejan de moverse y de atacar.
	if Game.game_over:
		velocity = Vector3.ZERO
		update_visuals(delta)
		update_health_bar()
		return

	if multiplayer.is_server():
		update_target()
		update_logic(delta)
		move_and_slide()

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

	var closest_enemy := find_closest_enemy()
	if closest_enemy != null:
		target = closest_enemy
		return

	var enemy_castle := find_enemy_castle()
	if enemy_castle != null and global_position.distance_to(enemy_castle.global_position) <= castle_engage_distance:
		target = enemy_castle
		return

	target = null

func update_logic(delta: float) -> void:
	if target == null:
		update_state(UnitState.CHASE)
		face_movement_direction(advance_direction, delta)
		move_forward(advance_direction)
		return

	var distance_to_target = effective_distance_to(target)

	if distance_to_target <= stats.attack_range:
		velocity = Vector3.ZERO
		face_target(delta)
		update_state(UnitState.ATTACK)
		try_attack()
	else:
		update_state(UnitState.CHASE)
		face_target(delta)
		move_towards_position(target.global_position)


# Distancia hasta el borde del objetivo: descuenta el radio de objetivos
# grandes (ej. castillos) para que el melee pueda atacarlos sin atravesar el coller.
func effective_distance_to(node: Node3D) -> float:
	var dist = global_position.distance_to(node.global_position)
	if node.has_method("get_attack_radius"):
		dist -= node.get_attack_radius()
	return max(0.0, dist)

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
	# Al morir, la barra de vida desaparece.
	if health_bar_root and health_bar_root.visible:
		health_bar_root.visible = false

func move_towards_position(pos: Vector3) -> void:
	_steer_velocity(pos - global_position)

func move_forward(dir: Vector3) -> void:
	_steer_velocity(dir)

# Combina la dirección deseada con una fuerza de separación de aliados, para
# que las unidades se dispersen lateralmente en vez de quedarse en fila.
func _steer_velocity(desired_dir: Vector3) -> void:
	var flat := desired_dir
	flat.y = 0.0

	if flat.length() <= 0.01:
		velocity = Vector3.ZERO
		return

	var desired := _find_clear_direction(flat.normalized())
	var steer := desired + _get_separation() * separation_weight
	steer.y = 0.0

	if steer.length() > 0.001:
		velocity = steer.normalized() * stats.move_speed
	else:
		velocity = desired * stats.move_speed


func _find_clear_direction(desired: Vector3) -> Vector3:
	var fallback := desired
	if not _is_direction_blocked(desired):
		return desired

	var tangent := _get_obstacle_tangent(desired)
	if tangent.length() > 0.001 and not _is_direction_blocked(tangent):
		return tangent.normalized()

	for angle_degrees in obstacle_avoidance_angles:
		var rotated := desired.rotated(Vector3.UP, deg_to_rad(angle_degrees))
		if rotated.length() <= 0.001:
			continue
		if not _is_direction_blocked(rotated):
			return rotated.normalized()

	return fallback


func _get_obstacle_tangent(desired: Vector3) -> Vector3:
	var hit: Dictionary = _probe_obstacle(desired)
	if hit.is_empty():
		return Vector3.ZERO

	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if normal == Vector3.ZERO:
		return Vector3.ZERO

	var flat_normal := Vector3(normal.x, 0.0, normal.z)
	if flat_normal.length() <= 0.001:
		return Vector3.ZERO
	flat_normal = flat_normal.normalized()

	var tangent_a := Vector3.UP.cross(flat_normal).normalized()
	var tangent_b := -tangent_a
	if tangent_a.dot(desired) >= tangent_b.dot(desired):
		return tangent_a
	return tangent_b


func _probe_obstacle(direction: Vector3) -> Dictionary:
	if direction.length() <= 0.001:
		return {}

	var flat := direction.normalized()
	var side := Vector3.UP.cross(flat)
	if side.length() <= 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for lateral in [0.0, obstacle_avoidance_probe_radius, -obstacle_avoidance_probe_radius]:
		var from: Vector3 = global_position + Vector3.UP * 0.3 + side * lateral
		var to: Vector3 = from + flat * obstacle_avoidance_distance
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider: Node = hit.get("collider") as Node
		if collider != null and collider.is_in_group("map_obstacle"):
			return hit

	return {}


func _is_direction_blocked(direction: Vector3) -> bool:
	if direction.length() <= 0.001:
		return false

	var flat := direction.normalized()
	var side := Vector3.UP.cross(flat)
	if side.length() <= 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for lateral in [0.0, obstacle_avoidance_probe_radius, -obstacle_avoidance_probe_radius]:
		var from: Vector3 = global_position + Vector3.UP * 0.3 + side * lateral
		var to: Vector3 = from + flat * obstacle_avoidance_distance
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider: Node = hit.get("collider") as Node
		if collider != null and collider.is_in_group("map_obstacle"):
			return true

	return false

# Vector que apunta lejos de aliados cercanos y de obstáculos del terreno.
# El objetivo actual (target) queda excluido para no bloquear la persecución.
func _get_separation() -> Vector3:
	var push := Vector3.ZERO
	for body in detection_area.get_overlapping_bodies():
		if body == self or body == target:
			continue

		var radius := 0.0
		if body is MeleeUnit and body.team_id == team_id and not body.is_dead:
			# Aliados del mismo equipo: se dispersan para no apilarse.
			radius = separation_radius
		elif body.is_in_group("map_obstacle"):
			# Decoración del mapa (árboles, colinas, montañas): rodear en vez de encallar.
			radius = obstacle_separation_radius
		else:
			continue

		var offset := global_position - body.global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist > 0.001 and dist < radius:
			# Más empuje cuanto más cerca está.
			push += offset.normalized() * (1.0 - dist / radius)
	return push

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
		if effective_distance_to(target) <= stats.attack_range:
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


func find_enemy_castle() -> Node3D:
	var enemy_team := 1 if team_id == 0 else 0
	var castles := get_tree().get_nodes_in_group("castillo_jugador_" + str(enemy_team))
	if castles.is_empty():
		return null

	var castle := castles[0]
	if castle is Node3D and not castle.is_dead:
		return castle

	return null


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
	# El cuerpo va en tono piel; la identidad de equipo se muestra en las decoraciones
	# (cresta romana, alas y falda germanas) que cada facción colorea aparte.
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = get_body_color()
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

func get_body_color() -> Color:
	# Las unidades celtas tienen alas + falda grandes que ya muestran el color
	# del equipo, así que su cuerpo queda en tono piel para no saturar.
	# Las romanas (sin esas decoraciones) usan el color del equipo en el cuerpo
	# para que se distinga a qué bando pertenecen.
	if get_node_or_null("Visuals/Skirt") != null or get_node_or_null("Visuals/Helmet/Wing1") != null:
		return get_head_color()
	return get_team_color()

func get_head_color() -> Color:
	return Color(1.0, 0.8, 0.6)

func get_weapon_color() -> Color:
	return Color(0.8, 0.8, 0.8)

func get_attack_animation_distance() -> float:
	return 0.2

func take_damage(amount: int) -> void:
	if not multiplayer.is_server():
		return
	current_health -= amount
	if current_health <= 0:
		current_health = 0
		is_dead = true
		update_state(UnitState.DEAD)
		velocity = Vector3.ZERO
		remove_from_group("units")
		$CollisionShape3D.set_deferred("disabled", true)
		$DetectionArea/CollisionShape3D.set_deferred("disabled", true)

func get_visual_rotation_degrees() -> float:
	return 90.0
	

@rpc("authority", "call_local", "reliable")
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
